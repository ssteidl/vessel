# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require logger
package require Syslog

#NOTE: There's some copy and paste in this module but I'm not going
# to worry about it now.

namespace eval vessel::syslog {

    variable _ident {}

    namespace eval _ {

        proc log {level text} {
            #Text is actually a list from the logger subsystem.  Example is:
            #
            # prototypes/logging.tcl[91636]: -_logger::service vessel::shane {hello my friend}

            variable ::vessel::syslog::_ident

            set ident {}
            if {${_ident} ne {}} {
                set ident ${_ident}    
            } else {
                set ident [lindex $text 1]
            }

            syslog -facility local1 -ident $ident $level [lindex $text 2] 
        }

        proc log_debug {txt} {
            log debug $txt
        }

        proc log_info {txt} {
            log info $txt
        }

        proc log_notice {txt} {
            log notice $txt
        }

        proc log_warn {txt} {
            log warning $txt
        }

        proc log_error {txt} {
            log error $txt
        }

        proc log_critical {txt} {
            log critical $txt
        }

        proc log_alert {txt} {
            log alert $txt
        }

        proc log_emergency {txt} {
            log emergency $txt
        }
    }

    proc enable {} {
        set log [logger::servicecmd vessel]
        ${log}::logproc debug [namespace current]::_::log_debug
        ${log}::logproc info [namespace current]::_::log_info
        ${log}::logproc notice [namespace current]::_::log_notice
        ${log}::logproc warn [namespace current]::_::log_warn
        ${log}::logproc error [namespace current]::_::log_error
        ${log}::logproc critical [namespace current]::_::log_critical
        ${log}::logproc alert [namespace current]::_::log_alert
        ${log}::logproc emergency [namespace current]::_::log_emergency
    }

    proc set_ident {ident} {
        variable _ident

        set _ident $ident
    }
}

namespace eval vessel::stderrlog {
    namespace eval _ {
        
        proc log {level text} {
            puts stderr $text
        }

        proc log_debug {txt} {
            log debug $txt
        }

        proc log_info {txt} {
            log info $txt
        }

        proc log_notice {txt} {
            log notice $txt
        }

        proc log_warn {txt} {
            log warning $txt
        }

        proc log_error {txt} {
            log error $txt
        }

        proc log_critical {txt} {
            log critical $txt
        }

        proc log_alert {txt} {
            log alert $txt
        }

        proc log_emergency {txt} {
            log emergency $txt
        }
    }

    proc enable {} {
        set log [logger::servicecmd vessel]
        ${log}::logproc debug [namespace current]::_::log_debug
        ${log}::logproc info [namespace current]::_::log_info
        ${log}::logproc notice [namespace current]::_::log_notice
        ${log}::logproc warn [namespace current]::_::log_warn
        ${log}::logproc error [namespace current]::_::log_error
        ${log}::logproc critical [namespace current]::_::log_critical
        ${log}::logproc alert [namespace current]::_::log_alert
        ${log}::logproc emergency [namespace current]::_::log_emergency
    }
}

package provide vessel::syslog 1.0.0