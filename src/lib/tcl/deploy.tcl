# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require defer
package require inifile
package require logger
package require struct::set

namespace eval vessel::deploy {

    namespace export poll_deploy_dir

    logger::initNamespace [namespace current] debug
    variable log [logger::servicecmd [string trimleft [namespace current] :]]

    namespace eval _ {

        #dictionary of statbuf arrays of deployment files
        variable deploy_files_dict [dict create]

        proc reset {} {
            #Reset the state of the module.  used for testing, not public interface

            variable deploy_files_dict

            set deploy_files_dict [dict create]
        }
    }

    namespace eval ini {

        namespace eval _ {
            proc validate_section_name {name} {
                if {$name eq {vessel-supervisor}} {
                    return
                }

                if {[string first {dataset:} $name] != -1} {
                    return
                }

                if {$name eq {jail}} {
                    return
                }

                if {[string first {resource:} $name] != -1} {
                    return
                }

                return -code error -errorcode {VESSEL INI SECTION UNEXPECTED} \
                    "Unexpected section $name"
            }
        }

        proc get_deployment_dict {ini_file} {
            set fh [ini::open $ini_file]
            defer::with [list fh] {
                ini::close $fh
            }
            set sections [ini::sections $fh]

            set deployment_dict [dict create]
            foreach section $sections {
                dict set deployment_dict $section [ini::get $fh $section]
                _::validate_section_name $section
            }

            return $deployment_dict
        }
    }

    proc poll_deploy_dir {deploy_dir} {

        # Returns a dictionary with 'start', 'stop' and 'modified' keys.
        # Each key has a list of ini files to handle.

        variable log

        set change_dict [dict create "start" [list] "stop" [list] "modified" [list]]

        variable _::deploy_files_dict

        set ini_files [glob -nocomplain [file join $deploy_dir]/*.ini]
        ${log}::debug "Polling ini files: ${ini_files}"

        ${log}::debug "Deploy files dict: [dict keys $deploy_files_dict]"
        foreach f $ini_files {

            set deploy_file [file normalize $f]
            file stat $deploy_file statbuf

            if {$statbuf(type) eq {file}} {

                if {[dict exists $deploy_files_dict $deploy_file]} {

                    set existing_mtime [dict get $deploy_files_dict $deploy_file "mtime"]

                    if {$existing_mtime < $statbuf(mtime)} {
                        dict lappend change_dict "modified" $deploy_file
                    } elseif {$existing_mtime == $statbuf(mtime)} {
                        ${log}::debug "File exists but hasn't changed"
                    } else {
                        ${log}::debug "Existing statbuf is newer then updated modification time... ignoring."
                    }
                } else {

                    dict lappend change_dict "start" $deploy_file
                }


                #save the deploy file to the deploy_files_dict so we can
                # check if anything changed in the next invocation.
                dict set deploy_files_dict $deploy_file [array get statbuf]
            }
        }

        # Figure out which files have been deleted by doing a set difference between
        # ini files and known ini files.
        set known_deploy_files [list]
        struct::set add known_deploy_files [dict keys $deploy_files_dict]
        set deleted_files [struct::set difference $known_deploy_files $ini_files]

        ${log}::debug "Known deploy files: $known_deploy_files"
        ${log}::debug "ini files: $ini_files"
        ${log}::debug "deleted files: $deleted_files"
        
        #Remove the deleted files from the deploy_files_dict
        foreach filename $deleted_files {            
            dict lappend change_dict "stop" $filename
            dict unset deploy_files_dict $filename
        }
        return $change_dict
    }
}

package provide vessel::deploy 1.0.0
