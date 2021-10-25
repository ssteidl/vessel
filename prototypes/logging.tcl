# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require logger

package require Syslog

set glog [logger::init vessel]

namespace eval vessel::shane {
    logger::initNamespace [namespace current] debug
    variable log [logger::servicecmd [string trimleft [namespace current] :]]

    proc joe {} {
        variable log
        ${log}::debug "hello my friend"
    }
}

logger::setlevel debug

proc logtosyslog_debug {txt} {
    syslog -facility local1 -ident [lindex $txt 1] debug [lindex $txt 2]
}

${glog}::logproc debug logtosyslog_debug

vessel::shane::joe
