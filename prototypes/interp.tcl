#Play around with sub interps so we can
#more safely source appc files

proc get_some_data {} {
    set d [dict create key1 val1 key2 val2]

    return $d
}

puts stderr "USAGE: interp.tcl <appc_file>"
if {[llength $argv] != 1} {
    puts stderr "Exactly one argument required <appc_file>."
    exit 1
}

set appc_file [lindex $argv 0]

interp create sub.interp

# Run commands in a sub-interp
sub.interp eval [list set appc_file $appc_file]
sub.interp eval {puts stderr $appc_file}

# Pass data to a sub interp via running an alias
# of master command in slave.
sub.interp alias get_data get_some_data
sub.interp eval {puts stderr "d: [get_data]"}

#Build an image
sub.interp eval {
    package require AppcFileCommands

    set cmdline_options [dict create name testimage]
    source $appc_file
}
