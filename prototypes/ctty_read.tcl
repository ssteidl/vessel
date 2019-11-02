#! /usr/bin/env tclsh8.6

package require appc::native

#Flag used to exit the event loop when the pty closes
set pty_closed 0

set ptys [pty::open]

set master [lindex $ptys 0]
set slave [lindex $ptys 1]
puts $slave

#Set the size of the new pty to the size of the current
#terminal.  This is a good starting point and as long
#as the size of the terminal (or X window terminal emulator)
#isn't changed, then it should work very well.  When stdin
#and pty are mismatched in size, it is very obvious when using
#man or typing long commands.
pty::copy_winsz stdin $master

#Outside of setting blocking to false, the other configurations
#probably aren't necessary.
fconfigure stdin -blocking false -translation binary -buffering none
fconfigure $master -blocking false -translation binary -buffering none
fconfigure stdout -buffering none -translation binary -buffering none

#Make stdin and stdout raw so that signals are passed though
#to the process on the slave end of the pty
set old_stdin_settings [pty::makeraw stdin]
set old_stdout_settings [pty::makeraw stdout]

#Proxy input from stdin to the pty
fileevent stdin readable {apply {{input_chan output_chan} {
    set data [read $input_chan]
    puts -nonewline $output_chan $data
}} stdin $master}

#Proxy input from the pty to stdout.  Closing when the pty closes.
fileevent $master readable {apply {{input_chan output_chan stdin_restore stdout_restore} {
    set data [read $input_chan]
    if {[eof $input_chan]} {
	global pty_closed
	
	pty::restore stdout $stdout_restore
	pty::restore stdin $stdin_restore
	close $input_chan
	set pty_closed 1
    } else {
	puts -nonewline $output_chan $data
    }
}} $master stdout $old_stdin_settings $old_stdout_settings}

#Start the event loop
vwait pty_closed

puts stderr "Exiting container shell"
