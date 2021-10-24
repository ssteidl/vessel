# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require logger


namespace eval vessel::shane {
    logger::initNamespace [namespace current] debug
    variable log [logger::servicecmd [string trimleft [namespace current] :]]

    proc joe {} {
        variable log
        ${log}::debug "hello my friend"
    }
}

logger::setlevel debug
vessel::shane::joe