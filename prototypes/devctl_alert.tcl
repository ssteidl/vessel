package require vessel::native
package require vessel::bsd

proc bgerror {msg} {
	puts "bgerror: $msg"
}


vessel::devctl_set_callback vessel::bsd::parse_devd_rctl_str

set _forever_ {}
vwait _forever_
