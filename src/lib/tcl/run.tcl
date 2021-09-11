# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require debug
package require dicttool
package require fileutil
package require uuid

package require vessel::bsd
package require vessel::env
package require vessel::deploy
package require vessel::jail
package require vessel::zfs

namespace eval vessel::run {

    debug define run
    debug on run 1 stderr
    
    namespace eval _ {

        proc handle_dataset_argument {dataset_arg} {

            debug.run "dataset_arg: $dataset_arg"
            set arg_list [split $dataset_arg ":"]
            if {[llength $arg_list] != 2} {
                return -code error -errorcode {DATASET ARGS} "dataset requires a value in the format <source>:<dest>"
            }

            set dataset [lindex $arg_list 0]
            set jail_mntpoint [lindex $arg_list 1]

            if {![vessel::zfs::dataset_exists $dataset]} {
                vessel::zfs::create_dataset $dataset
            }

            if {[catch {vessel::zfs::set_mountpoint_attr $dataset $jail_mntpoint} error_msg]} {
                debug.run "Failed to set mountpoint attribute on $dataset.  Ignoring: $error_msg"
            }
            vessel::zfs::set_jailed_attr $dataset

            return $dataset
        }
        
        proc handle_volume_argument {mountpoint volume_arg} {

            set arg_list [split $volume_arg ":"]
            if {[llength $arg_list] != 2} {
                return -code error -errorcode {MOUNT ARGS} "volume requires a value in the format <source>:<dest>"
            }

            set sourcedir [lindex $arg_list 0]
            set destdir [lindex $arg_list 1]
            set jailed_dest_path [fileutil::jail $mountpoint $destdir]
            
            if {[file exists $sourcedir] && [file isdirectory $sourcedir]} {

                vessel::bsd::null_mount $sourcedir $jailed_dest_path
            } else {

                return -code error -errorcode {MOUNT DEST EEXIST} "Source path for volume argument does not exist"
            }

            return $jailed_dest_path
        }

        proc create_run_dict {args_dict} {

            # Merge the commandline (args_dict) and sections from the ini file
            # (if an ini file was given).

            set run_dict $args_dict
            dict set run_dict jail [dict create]
            dict set run_dict limits [list]
            
            set ini_file [dict get $args_dict ini_file]
            
            if {$ini_file eq {}} {
                return $run_dict
            }

            if {![file exists $ini_file]} {
                return -code error -errorcode {VESSEL RUN INI EEXISTS} \
                    "ini file does not exist: $ini_file"
            }
            set ini_params_dict [vessel::deploy::ini::get_deployment_dict ${ini_file}]

            
            #Add volumes and datasets to the run_dict.
            # NOTE: We add them in the same format as they come in from
            # the command line <hostpath:jailpath>.  This is just easier for now
            # we should probably create an actual structure and update the processing
            # code instead of shoehorning in the same format.
            dict for {section section_value_dict} $ini_params_dict {
                if {[string first {dataset:} $section] eq 0} {

                    set dataset_name [dict get $section_value_dict dataset]
                    set dataset_name "${dataset_name}"
                    set dataset_mount [dict get $section_value_dict mount]

                    dict lappend run_dict datasets "${dataset_name}:${dataset_mount}"
                }

                if {[string first {nullfs:} $section] eq 0} {
                    set volume_directory [dict get $section_value_dict directory]
                    set volume_mount [dict get $section_value_dict mount]

                    dict lappend run_dict volumes "${volume_directory}:${volume_mount}"
                }

                if {$section eq {jail}} {
                    dict for {param value} $section_value_dict {
                        dict set run_dict jail $param $value
                    }
                }

                if {[string first {resource:} $section] eq 0} {

                    set resource_tokens [split $section :]
                    if {[llength ${resource_tokens}] != 2} {
                        return -code error "Invalid resource section name: $section"
                    }

                    set limit_name [lindex ${resource_tokens} 1]
                    set rctl_string [dict get $section_value_dict "rctl"]
                    set devctl_action [dict getnull $section_value_dict "devctl-action"]
                    dict lappend run_dict limits [dict create "name" $limit_name "rctl" $rctl_string "devctl-action" $devctl_action]
                }
            }
            
            return $run_dict
        }
    }

    proc resource_limits_cb {user_limits_list jail_name jail_file devd_str} {
        # The callback for the devctl module to call when a devd string
        # is read from the socket.  
        #
        # param user_limits_list: List of dictionaries that potentially contain actions to
        # perform when the jail exceeds a limit
        #
        # param jail_name: The name of the jail being executed by this instance of vessel
        #
        # param rctl_str: The string read from devd socket.  It could be from any subsystem
        # not just rctl.
        set rctl_dict [vessel::bsd::parse_devd_rctl_str $devd_str]

        #If it's not an rctl string then return
        if {$rctl_dict eq {}} {
            return
        }

        set jail [dict get $rctl_dict "jail"]

        debug.run "Jail exceeded resource: $jail"

        if {$jail eq $jail_name} {

            #Iterate through all of the resource definitions provided
            # by the user.
            foreach user_limit_dict $user_limits_list {
                #Get the rctl rule which is resource:action
                set user_rctl_rule [dict get $user_limit_dict "rctl"]
                set user_resource [lindex [split $user_rctl_rule :] 0]
                
                set rctl_resource [dict get $rctl_dict "rule" "resource"]
                debug.run "User resource: $user_resource"
                debug.run "rctl resource: $rctl_resource"
                if {$user_resource eq $rctl_resource} {
                    #The user provided resource matches the resource provided by the devd rctl string
                    set user_action [dict get $user_limit_dict "devctl-action"]
                    debug.run "User action: $user_action"
                    if {$user_action eq "shutdown"} {
                        debug.run "Resource limit exceeded.  shutting down"
                        if {[catch {vessel::jail::shutdown $jail_name $jail_file} msg]} {
                            debug.run "Error shutting down after resource limit exceeded: $msg"
                        }
                    } else {
                        #TODO: Implement exec subprocess
                        debug.run "Resource limit exceeded.  Executing some other action"
                    }
                }
            }
        }
    }

    proc signal_handler {jail_name jail_file signal active_pid_groups} {

        puts stderr "SIG${signal} received.  Removing jail: $jail_name"
        vessel::jail::remove $jail_name $jail_file stderr
    }

    proc run_command {chan_dict args_dict cb_coro} {

        defer::with [list cb_coro] {
            after idle $cb_coro
        }

        set args_dict [_::create_run_dict $args_dict]
        set jail_options_dict [dict get $args_dict jail]
        
        #Initialization yield
        yield

        #TODO: All parameters should be validated before any cloning is done so proper
        # cleanup can be done.  right now we clone and then fail on poorly formatted
        # parameters.

        #TODO: IMAGE should be it's own class
        set image [dict get $args_dict "image"]
        set image_components [split $image :]
        set image_name [lindex $image_components 0]
        set network [dict get $args_dict "network"]
        
        set uuid [uuid::uuid generate]
        set jail_name $uuid
        if {[dict exists $args_dict "name" ]} {
            set jail_name [dict get $args_dict "name"]
        }

        set tag {latest}
        if {[llength $image_components] > 1} {
            set tag [lindex $image_components 1]
        } elseif {[dict exists $args_dict tag]} {
            set tag [dict get $args_dict tag]
        }

        set mountpoints_dict [vessel::zfs::get_mountpoints]

        if {$tag eq {local}} {
            #If tag is the special name "local" then don't clone the dataset.  This can
            #can be useful for development and testing.
            set tag {local}
        }
        set image_dataset [vessel::env::get_dataset_from_image_name $image_name $tag]
        debug.run "RUN COMMAND image dataset: $image_dataset"

        if {![dict exists $mountpoints_dict $image_dataset]} {
            #TODO: retrieve and unpack layer
            return -code error -errorcode {VESSEL RUN NYI} \
                "Automatically pulling images is NYI"
        }

        set b_snapshot_exists [vessel::zfs::snapshot_exists "${image_dataset}@b"]
        debug.run "RUN COMMAND b snapshot exists: $b_snapshot_exists"
        if {$b_snapshot_exists && $tag ne {local}} {

            set container_dataset [vessel::env::get_dataset_from_image_name $image_name ${tag}/${jail_name}]

            if {![dict exists $mountpoints_dict $container_dataset]} {
                debug.run "Cloning b snapshot: ${image_dataset}@b $container_dataset"
                vessel::zfs::clone_snapshot "${image_dataset}@b" $container_dataset
            }
        } else {

            #Support manually created or pulled datasets
            set container_dataset "${image_dataset}"
        }
        
        set mountpoint [vessel::zfs::get_mountpoint $container_dataset]

        #nullfs volume mounts
        set jailed_mount_paths [list]
        foreach volume [dict get $args_dict volumes] {
            lappend jailed_mount_paths [_::handle_volume_argument $mountpoint $volume]
        }

        set volume_datasets [list]
        foreach volume_dataset_arg [dict get $args_dict datasets] {
            set dataset [_::handle_dataset_argument $volume_dataset_arg]
            lappend volume_datasets $dataset
        }

        #NOTE: We need a better way to handle resolv conf.  Ideally a dns server
        vessel::env::copy_resolv_conf $mountpoint
        
        set command [dict get $args_dict "command"]

        set coro_name [info coroutine]
        set limits [dict get $args_dict "limits"]
        set tmp_jail_conf {}
        set error [catch {
            set jail_start_params [yieldto vessel::jail::run_jail $jail_name $mountpoint $volume_datasets $chan_dict \
                $network $limits $jail_options_dict $coro_name {*}$command]
            
            debug.run "jail_start_params: $jail_start_params"
            set tmp_jail_conf [lindex $jail_start_params 0]
            set ctrl_pipe [lindex $jail_start_params 2]
        } error_msg info_dict]
        if {$error} {
            return -code error -errorcode {VESSEL JAIL EXEC} "Error running jail: $error_msg"
        }
        
        #NOTE: I'm leaving this bit of code in for now.  vessel proper doesn't
        #actually use the control pipe.
        chan configure $ctrl_pipe -blocking 0 -buffering none 
        chan event $ctrl_pipe readable [list apply {{cpipe} {
            set val [chan read $cpipe]
            debug.run "ctrl_pipe: $val"
            if {[eof $cpipe]} {
                close $cpipe
            }
        }} $ctrl_pipe]

        debug.run "Setting devctl callback"
        if {$limits ne {}} {
            vessel::devctl_set_callback [list vessel::run::resource_limits_cb $limits $jail_name $tmp_jail_conf]
        }

        #Signal handler to intelligently shutdown jails from received signals.
        vessel::exec_set_signal_handler [list vessel::run::signal_handler $jail_name $tmp_jail_conf]

        #Wait for the exit callback 
        set exit_params [yieldto return -level 0 {}]
        debug.run "exit params: $exit_params"

        #TODO: Now that we can use the jail file we need to:
        # 1. Move jail cleanup to the jail file commands

        debug.run "Container exited. Cleaning up..."

        # TODO: Do a check to see if cleanup is needed.  If so run this command and
        #ideally do all of the cleanup in the jail.conf.
        debug.run "Removing jail: $jail_name, $tmp_jail_conf"
        if {[catch {vessel::jail::shutdown $jail_name $tmp_jail_conf} error_msg]} {
            puts stderr "Unable to remove jail: $error_msg"
        }

        file delete $tmp_jail_conf

        debug.run "Unmounting nullfs volumes"
        foreach volume_mount $jailed_mount_paths {
            set error [catch {vessel::bsd::umount $volume_mount} error_msg]
            if {$error} {
                puts stderr "Error unmounting $volume_mount: $error_msg"
            }
        }

        debug.run "Unjailing jailed datasets"
        foreach volume_dataset $volume_datasets {
            catch {exec zfs set jailed=off $volume_dataset >&@ stderr}
            catch {exec zfs umount $volume_dataset >&@ stderr}
        }
        
        if {[dict get $args_dict "remove"]} {
            debug.run "Destroying container dataset: $container_dataset"
            vessel::zfs::destroy $container_dataset
        }

        debug.run "Finished running container: $jail_name"
    }
}

package provide vessel::run 1.0.0
