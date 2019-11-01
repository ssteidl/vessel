#! /usr/bin/env tclsh8.6

package require appc::native

set pty_slave_path [lindex $argv 0]

set pty_chan [open $pty_slave_path RDWR]

set fd_dict [dict create stdin $pty_chan stdout $pty_chan stderr $pty_chan]
set callback [list puts "shane is awesome"]

appc::exec $fd_dict $callback {bash}

vwait __forever__
