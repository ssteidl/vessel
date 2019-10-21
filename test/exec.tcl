package require appc::native
package require pty

set pty_list [pty::open]
puts $pty_list
set master [lindex $pty_list 0]
puts "master $master"
set fd_dict [dict create stdin $master stdout $master stderr $master]
appc::exec $fd_dict {bash}

vwait __forever__
