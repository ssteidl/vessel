package require vessel::native


proc bgerror {msg} {
	puts "bgerror: $msg"
}


vessel::devctl_set_callback [list puts -nonewline stderr]

set _forever_ {}
vwait _forever_
