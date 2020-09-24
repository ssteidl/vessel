##
## mustache.tcl - an implementation of the mustache templating language in tcl.
## See https://github.com/mustache for further information about mustache.
##
## (C)2015 by Jan Kandziora <jjj@gmx.de>
##
## You may use, copy, distibute, and modify this software under the terms of
## the BSD-2-Clause license. See file COPYING for details.
##


## Require lambda package from tcllib.
## If you don't need mustache to support lambdas, you can leave this out.
package require lambda


namespace eval ::mustache {
	## Helpers.
	set HtmlEscapeMap [dict create "&" "&amp;" "<" "&lt;" ">" "&gt;" "\"" "&quot;" "'" "&#39;"]
	set LambdaPrefix "Λtcl"
	set LambdaUnsafe "λtcl"

	## Build search tree.
	proc searchtree {frame} {
		set thisframe $frame
		while {$thisframe ne {}} {
			lappend tree $thisframe
			set thisframe [lrange $thisframe 0 end-1]
		}
		lappend tree {} {*}[lreverse [lrange $frame 1 end]]
	}

	## Main template compiler.
	proc compile {tail context {toplevel 0} {libraries {}} {frame {}} {lambdalimit {}} {standalone 1} {skippartials 0} {indent {}} {opendelimiter "\{\{"} {closedelimiter "\}\}"} {input {}} {output {}}} {
		set iteratorpassed 0

		## Add indent to first output line.
		append output $indent

		## Loop over content.
		while true {
			## Get open index of next tag.
			set openindex [string first $opendelimiter $tail]

			## If standalone flag is cleared, look for next newline.
			if {!$standalone} {
				## Set standalone flag if a newline precedes the first tag.
				set newlineindex [string first "\n" $tail]
				set standalone [expr {($newlineindex>=0) && ($newlineindex < $openindex)} ]
			}

			## Get pre-tag content.
			if {$openindex>=0} {
				set head [string range $tail 0 $openindex-1]
			} else {
				set head $tail
			}

			## Copy verbatim text up to next tag to input.
			append input $head

			## Split head into lines for indentation.
			set headlist [split $head \n]

			## Break loop when no new tag is found.
			if {$openindex==-1} {
				## Indent pre-tag content.
				if {$headlist eq {}} {
					set head {}
				} elseif {[lindex $headlist end] ne {}} {
					set head [join $headlist "\n$indent"]
				} else {
					set head [join [lrange $headlist 0 end-1] "\n$indent"]\n
				}

				## Return with input and compiled output.
				return [list $head $output $input 0]
			}

			## Indent pre-tag content.
			set head [join $headlist "\n$indent"]

			## Get close index of tag.
			set openlength [expr [string length $opendelimiter]+1]
			set closeindex [string first $closedelimiter $tail $openindex+$openlength]
			set closelength [string length $closedelimiter]

			## Get command by tag type.
			switch -- [string index $tail $openindex+[string length $opendelimiter]] {
				"\{" { incr closelength ; set command substitute ; set escape 0 }
				"!" { set command comment }
				"&" { set command substitute ; set escape 0 }
				"." { set command iterator ; set escape 1 ; set iteratorpassed 1 }
				"#" { set command startSection }
				"^" { set command startInvertedSection }
				"/" { set command endSection }
				">" { set command includePartial }
				"=" { set command setDelimiters }
				default { incr openlength -1 ; set command substitute ; set escape 1 }
			}

			## Add verbatim tag to input, if not endSection.
			if {$command ne {endSection}} {
				append input [string range $tail $openindex [expr $closeindex+$closelength-1]]
			}

			## Get tag parameter.
			set parameter [string trim [string range $tail $openindex+$openlength $closeindex-1]]

			## Get tail.
			set tail [string range $tail $closeindex+$closelength end]

			## Remove standalone flag for some occacions.
			if {$standalone && ($command eq {substitute})} {
				set standalone 0
			}
			if {$standalone && !([regsub {^[[:blank:]]*$} $head {} newhead]||[regsub {\n[[:blank:]]*$} $head "\n" newhead])} {
				set standalone 0
			}
			if {$standalone && !([regsub {^[[:blank:]]*\r?\n} $tail {} newtail]||[regsub {^[[:blank:]]*$} $tail {} newtail])} {
				set standalone 0
			}

			## If still standalone tag:
			if {$standalone} {
				## Set indent to use for partials.
				set partialsindent [regsub {.*?([[:blank:]]*)$} $head {\1}]

				## Remove blanks and newline from head end and tail start for standalone tags.
				set head $newhead
				set tail $newtail
			} else {
				set partialsindent {}
			}

			## Append head to output.
			append output $head

			## Switch by command.
			switch -- $command {
				comment {
				}
				substitute {
					## Split up the parameter into dotted sections.
					set parameter [split $parameter .]

					## Check search tree.
					foreach thisframe [::mustache::searchtree $frame] {
						## Check whether the parameter base is defined in this frame.
						if {[dict exists $context {*}$thisframe [lindex $parameter 0]]} {
							## Yes. Break if the full key doesn't exist.
							if {![dict exists $context {*}$thisframe {*}$parameter]} break

							## Get value.
							set value [dict get $context {*}$thisframe {*}$parameter]

							## Reset tail.
							set newtail {}

							## Check for lambda.
							if {![catch {dict get $value $::mustache::LambdaPrefix} body]} {
								## Lambda. Check for limit.
								if {($lambdalimit ne {}) \
									&& ([lrange $thisframe 0 [llength $lambdalimit]-1] eq $lambdalimit)} {
									## Continue in search tree.
									continue
								}

								## No limit. Get actual value from lambda.
								lassign [::mustache::compile [eval [::lambda {} $body]] $context $toplevel $libraries $frame $lambdalimit $standalone $skippartials $indent] newtail value

								## Check for double.
							} elseif {[string is double -strict $value]} {
									## Treat doubles as numbers.
									set value [expr $value]
							}

							## Substitute in output, escape if neccessary.
							if {$escape} {
								append output [string map $::mustache::HtmlEscapeMap $value] [string map $::mustache::HtmlEscapeMap $newtail]
							} else {
								append output $value $newtail
							}

							## Break.
							break
						}
					}
				}
				iterator {
					## Take whole frame content as value.
					set value [dict get $context {*}$frame]

					## Treat doubles as numbers.
					if {[string is double -strict $value]} {
						set value [expr $value]
					}

					## Substitute in output, escape if neccessary.
					if {$escape} {
						append output [string map $::mustache::HtmlEscapeMap $value]
					} else {
						append output $value
					}
				}
				startSection {
					## Test for iterator section.
					if {$parameter eq {.}} {
						## Iterator section.
						## Get values from current frame.
						set values [dict get $context {*}$frame]

						## Loop over outer list.
						foreach value $values {
							## Replace variant context by a single instance of it.
							set newcontext $context
							dict set newcontext {*}$frame $value

							## Call recursive, get new tail.
							lassign [::mustache::compile $tail $newcontext $toplevel $libraries $frame $lambdalimit $standalone $skippartials $indent $opendelimiter $closedelimiter] newtail sectionoutput
							append output $sectionoutput
						}

						## Update tail to skip the section in this level.
						set tail $newtail
					} else {
						## Normal section.
						## Split up the parameter into dotted sections.
						set parameter [split $parameter .]

						## Start with new frame.
						set found 0
						set newframe [concat $frame $parameter]
						foreach thisframe [::mustache::searchtree [concat $frame [lrange $parameter 0 end-1]]] {
							## Check for existing key.
							if {![catch {dict get $context {*}$thisframe [lindex $parameter end]} values]} {
								## Context ok.
								set found 1

								## Skip silently if the values is boolean false or an empty list.
								if {([string is boolean -strict $values] && !$values) || ($values eq {})} {
									lassign [::mustache::compile $tail $context $toplevel $libraries $newframe $lambdalimit $standalone 1] tail
									## Check for values is boolean true
								} elseif {([string is boolean -strict $values] && $values)} {
									## Replace a stray boolean value by a key/value pair.
									dict set context {*}$thisframe [lindex $parameter end] {true {}}

									## Render section in new frame.
									lassign [::mustache::compile $tail $context $toplevel $libraries $newframe $lambdalimit $standalone $skippartials $indent $opendelimiter $closedelimiter] tail sectionoutput
									append output $sectionoutput

									## Check for lambda.
								} elseif {![catch {dict get $values $::mustache::LambdaPrefix} body]} {
									## Check for lambda unsafe marker or inherited limit.
									if {([string first $::mustache::LambdaUnsafe $values] == 0)
										|| (($lambdalimit ne {})
											&& ([lrange $thisframe 0 [llength $lambdalimit]-1] eq $lambdalimit))} {
										## Revoke found notice, continue in search tree.
										set found 0
										continue
									}

									## No limit. Get section input.
									lassign [::mustache::compile $tail $context $toplevel $libraries $newframe $lambdalimit $standalone $skippartials $indent $opendelimiter $closedelimiter] tail dummy sectioninput

									## Evaluate lambda with section input.
									lassign [::mustache::compile [eval [::lambda arg $body $sectioninput]] $context $toplevel $libraries $frame $lambdalimit $standalone $skippartials $indent $opendelimiter $closedelimiter] newtail value

									## Substitute in output, escape.
									append output $value $newtail

									## Check for simple list vs. list of lists.
									## (section value is a list of key/value pairs)
									## WARNING: keys with whitespace in it are not allowed to
									## make it possible to detect list of lists.
								} elseif {[llength [lindex $values 0]] == 1} {
									## Set default lambda limit and iterator values on current context.
									set newlambdalimit $lambdalimit
									set iteratorvalues $values

									## Simple list. Check for lambda unsafe marker.
									if {[string first $::mustache::LambdaUnsafe $values] == 0} {
										## Found. Set limit.
										set newlambdalimit $newframe

										## Remove lambda unsafe marker and following whitespace from iterator values list.
										regsub "^$::mustache::LambdaUnsafe\[\[:blank:\]\]*?" $values {} iteratorvalues
									}

									## Replace variant context by a single instance of it
									set newcontext $context
									dict set newcontext {*}$newframe $values

									## Call recursive, get new tail.
									lassign [::mustache::compile $tail $newcontext $toplevel $libraries $newframe $newlambdalimit $standalone $skippartials $indent $opendelimiter $closedelimiter] newtail sectionoutput dummy iterator

									## Check if iterator has been passed in the section.
									if {!$iterator} {
										## No. Section output is ok.
										append output $sectionoutput
									} else {
										## Yes. Throw away last result, try again with iterator context.
										foreach value $iteratorvalues {
											## Replace variant context by a single instance of it.
											set newcontext $context
											dict set newcontext {*}$newframe $value

											## Call recursive, get new tail.
											lassign [::mustache::compile $tail $newcontext $toplevel $libraries $newframe $newlambdalimit $standalone $skippartials $indent $opendelimiter $closedelimiter] newtail sectionoutput
											append output $sectionoutput
										}
									}

									## Update tail to skip the section in this level.
									set tail $newtail
								} else {
									## Otherwise loop over list.
									foreach value $values {
										## Replace variant context by a single instance of it.
										set newcontext $context
										dict set newcontext {*}$newframe $value

										## Call recursive, get new tail.
										lassign [::mustache::compile $tail $newcontext $toplevel $libraries $newframe $lambdalimit $standalone $skippartials $indent $opendelimiter $closedelimiter] newtail sectionoutput

										append output $sectionoutput
									}

									## Update tail to skip the section in this level.
									set tail $newtail
								}

								## Break
								break
							}
						}

						## Skip silently over the section when no key was found.
						if {!$found} {
							lassign [::mustache::compile $tail $context $toplevel $libraries $newframe $lambdalimit $standalone 1] tail
						}
					}
				}
				startInvertedSection {
					## Split up the parameter into dotted sections.
					set parameter [split $parameter .]

					## Check for existing key.
					set newframe [concat $frame {*}$parameter]
					if {[dict exists $context {*}$newframe]} {
						## Key exists.
						set values [dict get $context {*}$newframe]

						## Skip silently if the values is *not* false
						## or an empty list or solely the lambda unsafe marker.
						if {([string is boolean -strict $values] && !$values)
							|| ($values eq {})
							|| ($values eq $::mustache::LambdaUnsafe)} {
							## Key is false or empty list. Render once.
							## Call recursive, get new tail.
							lassign [::mustache::compile $tail $context $toplevel $libraries $newframe $lambdalimit $standalone $skippartials $indent $opendelimiter $closedelimiter] tail sectionoutput
							append output $sectionoutput

							## Valid list. Check for lambda unsafe marker.
						} else {
							## Key is a valid list. Skip silently over the section.
							lassign [::mustache::compile $tail $context $toplevel $libraries $newframe $lambdalimit $standalone 1] tail
						}
					} else {
						## Key doesn't exist. Render once.
						## Call recursive, get new tail.
						lassign [::mustache::compile $tail $context $toplevel $libraries $newframe $lambdalimit $standalone $skippartials $indent $opendelimiter $closedelimiter] tail sectionoutput
						append output $sectionoutput
					}
				}
				endSection {
					## Test for iterator section.
					if {$parameter eq {.}} {
						## Iterator section closed.
						## Break recursion.
						return [list $tail $output $input $iteratorpassed]
					} else {
						## Normal section closed.
						## Split up the parameter into dotted sections.
						set parameter [split $parameter .]

						## Break recursion if parameter matches innermost frame.
						if {$parameter eq [lrange $frame end-[expr [llength $parameter]-1] end]} {
							return [list $tail $output $input $iteratorpassed]
						}
					}
				}
				includePartial {
					## Skip partials when compiling is done only for skipping over a section.
					if {!$skippartials} {
						## Check for local variable.
						upvar #$toplevel $parameter partial
						if {[info exists partial]} {
							## Compile a partial from a variable.
							lassign [::mustache::compile $partial $context $toplevel $libraries $frame $lambdalimit $standalone 0 $partialsindent] newtail sectionoutput
							append output $sectionoutput $newtail
						} else {
							## Compile a partial from library.
							foreach lib $libraries {
								upvar #$toplevel $lib library
								if {[dict exists $library $parameter]} {
									lassign [::mustache::compile [dict get $library $parameter] $context $toplevel $libraries $frame $lambdalimit $standalone 0 $partialsindent] newtail sectionoutput
									append output $sectionoutput $newtail

									## Break.
									break
								}
							}
						}
					}
				}
				setDelimiters {
					## Set tag delimiters.
					set opendelimiter [lindex [split [string range $parameter 0 end-1] { }] 0]
					set closedelimiter [lindex [split [string range $parameter 0 end-1] { }] 1]
				}
			}
		}
	}


	## Main proc.
	proc mustache {template context args} {
		## Check libraries.
		set libraries {}
		foreach lib $args {
			upvar $lib library
			if {[info exists library]} {
				lappend libraries $lib
			}
		}

		## Compile template.
		lassign [::mustache::compile $template $context [expr [info level]-1] $libraries] tail output
		join [list $output $tail] ""
	}
}


## All ok, actually provide this package.
package provide mustache 1.1.3

