# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require vessel::native
package require vessel::env

package require logger
package require textutil::expander


namespace eval vessel::jail {

    logger::initNamespace [namespace current] debug
    variable log [logger::servicecmd [string trimleft [namespace current] :]]

    variable jail_removed [expr false]

    namespace eval _ {

        proc build_network_parameters {network_param} {

            set network_params_dict [dict create]
            if {$network_param eq "inherit"} {
                return [dict set network_params_dict "ip4" "inherit"]
            } elseif {$network_param ne {}} {
                return [dict set network_params_dict "vnet" "1"]
            }

            return $network_params_dict
        }

        proc jail_verbose_switch {} {
            variable ::vessel::jail::log
            set verbose_param ""
            if {[${log}::currentloglevel] eq "debug"} {
                set verbose_param {-v}
            }

            return ${verbose_param}
        }

        namespace eval macros {

            proc network {network_params_dict} {
                set network_string {}
                dict for {parameter value} ${network_params_dict} {
                    append network_string "${parameter}=${value};"
                }

                return ${network_string}
            }

            #nullfs_mounts is a list of dictionaries {abs_path: <>, abs_jailed_mountpoint}
            proc nullfs_mounts {nullfs_mounts} {
                set nullfs_string {}
                foreach nullfs_mount_d $nullfs_mounts {

                    set abs_path [dict get ${nullfs_mount_d} "abs_path"]
                    set abs_jailed_mountpoint [dict get ${nullfs_mount_d} "abs_jailed_mountpoint"]
                    
                    set mkdir_string [subst {exec.created+="mkdir -p ${abs_jailed_mountpoint}";\n}]
                    append nullfs_string ${mkdir_string}
                    
                    set mount_string [subst {exec.created+="mount -t nullfs ${abs_path} ${abs_jailed_mountpoint}";\n}]
                    append nullfs_string ${mount_string}
                    
                    set umount_string [subst {exec.release+="umount ${abs_jailed_mountpoint}";\n}]
                    append nullfs_string ${umount_string}
                }

                return ${nullfs_string}
            }

            proc datasets {name datasets} {
                set dataset_string {}
                foreach dataset_d $datasets {
                    
                    set create [dict get ${dataset_d} create]
                    set jail_mntpath [dict get ${dataset_d} jail_mntpoint]
                    set dataset [dict get ${dataset_d} dataset]
                    if {$create} {
                        set create_string [subst {exec.prestart+="zfs create -p $dataset";\n\t}]
                        append dataset_string $create_string
                    }

                    set set_mountpoint_attr_string [subst {exec.prestart+="zfs set mountpoint=$jail_mntpath $dataset";\n\t}]
                    append dataset_string ${set_mountpoint_attr_string}

                    set jail_string [subst {exec.created+="zfs jail $name $dataset";\n\t}]
                    append dataset_string $jail_string

                    set jail_attr_string [subst {exec.created+="zfs set jailed=on $dataset";\n\t}]
                    append dataset_string $jail_attr_string

                    set mount_string [subst {exec.start+="zfs mount $dataset";\n\t}]
                    append dataset_string $mount_string

                    set umount_string [subst {exec.stop+="zfs umount $dataset";\n\t}]
                    append dataset_string ${umount_string}

                    set unjail_attr_string [subst {exec.release+="zfs set jailed=off $dataset";\n\t}]
                    append dataset_string ${unjail_attr_string}
                }

                return ${dataset_string}
            }

            proc resource_control {name limits} {
                set rctl_string {}
                foreach limit_dict $limits {
                    set user_rctl_string [dict get $limit_dict "rctl"]
                    append rctl_string [subst {exec.created+="rctl -a jail:$name:$user_rctl_string";\n}]
                }

                if {$rctl_string ne {}} {
                    append rctl_string [subst {exec.release="rctl -r jail:$name";\n}]
                }

                return ${rctl_string}
            }

            proc cpus {name cpuset} {

                set cpuset_str {}
                if {$cpuset ne {}} {
                    set cpuset_str [subst {exec.created+="cpuset -c -l $cpuset -j $name";}]
                }

                return ${cpuset_str}
            }

            #If host.hostname is not available in the jail options, default
            # to the jail name.
            proc hostname {name jail_options} {
                set has_hostname [dict exists $jail_options "host.hostname"]
                if {!$has_hostname} {
                    return "host.hostname=${name};"
                }

                return ""
            }

            proc ssh_port {port} {
            
                set ssh_str {}
                if {$port > 0} {
                    append ssh_str [subst {exec.start+="sed -E -i '' 's/\\\#?\[\[:space:]]+Port \[\[:digit:]]+/Port ${port}/g' /etc/ssh/ssh_config";\n\t}]
                    append ssh_str [subst {exec.start+="sysrc sshd_enable=YES syslogd_enable=YES";\n}]
                    append ssh_str [subst {exec.start+="pw useradd ec2-user -u 1001 || true";\n}]
                    append ssh_str [subst {exec.stop+="/bin/sh /etc/rc.shutdown jail";\n}]
                }

                return ${ssh_str}
            }

            proc options {jail_options} {
                set jail_options_string {}
                dict for {option value} $jail_options {
                    set option_string [subst {${option}+=${value};\n    }]
                    append jail_options_string $option_string
                }

                return ${jail_options_string}
            }

            proc hidden {args} {
                return ""
            }
        }

        #Build the jail command which can be exec'd
        proc build_jail_conf {name \
                              mountpoint \
                              nullfs_mounts \
                              volume_datasets \
                              network limits \
        					  cpuset \
                              ssh_port \
                              jail_options args} {

            set network_params_dict [build_network_parameters $network]
            
            #Add single quotes around any multi-word parts of the command
            set quoted_cmd [join [lmap word $args {expr {[llength $word] > 1 ?  "\'[join $word]\'" : $word }}]]
            
            textutil::expander jail_file_expander
            try {
            jail_file_expander evalcmd [list uplevel "#[info level]"]
            
            set jail_conf [jail_file_expander expand {
[set name] {
    path="[set mountpoint]";
    sysvshm=new;
    allow.mount;
    allow.mount.devfs;
    mount.devfs;
    allow.mount.zfs;
    enforce_statfs=1;
    [macros::network $network_params_dict]
    [macros::datasets $name $volume_datasets]
    [macros::nullfs_mounts ${nullfs_mounts}]
    [macros::cpus $name $cpuset]
    [macros::resource_control $name $limits]
    [macros::hostname $name $jail_options]
    [macros::ssh_port $ssh_port]
    [macros::options $jail_options]
    #Set persist=1 so we can properly run shutdown commands after all processes exit
    persist=1;
    exec.start+="[set quoted_cmd]";
    
}}]
            } finally {
                rename jail_file_expander {}
            }
            return $jail_conf
        }
    }

    proc kill {jid {signal TERM} {output_chan stderr}} {
        # Send signal to all processes in the jail.
        # Allow errors to propagate

        return [exec -ignorestderr jexec $jid kill "-${signal}" -1 >&@ $output_chan]
    }

    proc remove {jid jail_file {output_chan stderr}} {
        
        variable jail_removed

        set v [_::jail_verbose_switch]

        try {
            if {!${jail_removed}} {
                exec -ignorestderr jail {*}${v} -f $jail_file -r $jid >&@ $output_chan
                set jail_removed [expr true]
            }
            
        } trap {CHILDSTATUS} {} {
            return -code error -errorcode {JAIL RUN REMOVE} "Error removing jail"
        }

        return
    }
    
    proc shutdown {jid jail_file {output_chan stderr}} {
        
        return [remove $jid $jail_file $output_chan]
    }

    proc run_jail {name \
                   mountpoint \
                   nullfs_mounts \
                   volume_datasets \
                   chan_dict network limits \
    	           cpuset \
                   ssh_port \
                   jail_options_dict \
                   callback \
                   args} {
        variable log

        #Create the conf file
        set jail_conf [_::build_jail_conf $name $mountpoint ${nullfs_mounts} ${volume_datasets} \
                      $network $limits $cpuset $ssh_port ${jail_options_dict} {*}$args]
        set jail_conf_file [file join [vessel::env::jail_confs_dir] "${name}.conf"]
        set jail_conf_file_chan [open  $jail_conf_file w]

        puts $jail_conf_file_chan $jail_conf
        close $jail_conf_file_chan
        
        set debug_args [_::jail_verbose_switch]

        set jail_command [list jail {*}$debug_args -f $jail_conf_file -c $name]
        
        ${log}::debug "$jail_conf"

        #If callback is empty, that implies blocking mode.  non-empty callback implies
        #async mode.  If async, make sure the callback has the jail conf file to cleanup
        set _callback {}
        if {$callback ne {}} {
            set _callback [list $callback $jail_conf_file]

            #Run the async command in the background.  This way we can return the jail conf file
            #without a race condition.  The higher level can finish setting up with data from
            #the jail being started.
            after idle [list vessel::exec $chan_dict ${_callback} {*}$jail_command]
        } else {
            #Blocking so run it inline
            vessel::exec $chan_dict {} {*}$jail_command
        }
        
        return $jail_conf_file
    }
}

package provide vessel::jail 1.0.0
