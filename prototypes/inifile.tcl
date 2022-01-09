#! /usr/bin/env tclsh8.6
# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require inifile

set handle [ini::open [file join . prototype.ini]]

puts [ini::sections $handle]

puts [ini::keys $handle vessel-supervisor]

set d [ini::get $handle resource:maxmemoryuse]

dict for {k v} $d {
    puts "$k => $v"
}
