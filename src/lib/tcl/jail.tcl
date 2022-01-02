# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require vessel::native
package require vessel::env

package require logger
package require textutil::expander


namespace eval vessel::jail {

    logger::initNamespace [namespace current] debug
    variable log [logger::servicecmd [string trimleft [namespace current] :]]

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
        
        #Build the jail command which can be exec'd
        proc build_jail_conf {name mountpoint volume_datasets network limits \
        					  cpuset jail_options args} {

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
                    [set network_string {}
                     dict for {parameter value} ${network_params_dict} {
                         append network_string "${parameter}=${value};"
                     }
                     set network_string]
                    [set volume_string {}
                     foreach volume $volume_datasets {
                         set jail_string [subst {exec.created+="zfs jail $name $volume";\n}]
                         append volume_string $jail_string
                         set mount_string [subst {exec.start+="zfs mount $volume";\n}]
                         append volume_string $mount_string
                     }
                     set volume_string]
                     [set rctl_string {}
                     foreach limit_dict $limits {
                         set user_rctl_string [dict get $limit_dict "rctl"]
                         append rctl_string [subst {exec.created+="rctl -a jail:$name:$user_rctl_string";\n}]
                     }
                     set rctl_string
                     if {$rctl_string ne {}} {
                         append rctl_string [subst {exec.release="rctl -r jail:$name";}]
                     }]

                     [if {$cpuset ne {}} {
                     	set cpuset_str [subst {exec.created+="cpuset -c -l $cpuset -j $name";}]
                     }]
                     
                    [set jail_options_string {}
                     dict for {option value} $jail_options {
                         set option_string [subst {${option}+=${value};\n}]
                         append jail_options_string $option_string
                     }
                     set jail_options_string]

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

    proc shutdown {jid jail_file {output_chan stderr}} {
        return [exec -ignorestderr jail -f $jail_file -r $jid >&@ $output_chan]
    }

    proc remove {jid jail_file {output_chan stderr}} {

        try {
            exec -ignorestderr jail -f $jail_file -r $jid >&@ $output_chan
        } trap {CHILDSTATUS} {} {
            return -code error -errorcode {JAIL RUN REMOVE} "Error removing jail"
        }

        return
    }
    
    proc run_jail {name mountpoint volume_datasets chan_dict network limits \
    	           cpuset jail_options_dict callback args} {
        variable log

        #Create the conf file
        set jail_conf [_::build_jail_conf $name $mountpoint $volume_datasets \
                      $network $limits $cpuset $jail_options_dict {*}$args]
        set jail_conf_file [file join [vessel::env::jail_confs_dir] "${name}.conf"]
        set jail_conf_file_chan [open  $jail_conf_file w]

        puts $jail_conf_file_chan $jail_conf
        close $jail_conf_file_chan
        
        set debug_args {}
        if {[${log}::currentloglevel] eq "debug"} {
            set debug_args "-v"
        }

        set jail_command [list jail {*}$debug_args -f $jail_conf_file -c $name]
        
        ${log}::debug "JAIL CONF: $jail_conf"

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
