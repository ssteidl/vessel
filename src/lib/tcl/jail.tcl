# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require vessel::native
package require vessel::env
package require logger
package require textutil::expander

namespace eval vessel::jail {

    logger::initNamespace [namespace current] debug
    variable log [logger::servicecmd [string trimleft [namespace current] :]]

    namespace eval _ {
    	
    	#TODO: I have this in multiple places
    	proc dict_get_value {dict key default_value} {

            if {[dict exists $dict $key]} {
                return [dict get $dict $key]
            }

            return $default_value
        }

    	#TODO: This function takes all the parameters from the named network
    	#after they have been queried.  Querying the network database happens higher
    	#up the call stack
        proc validate_network_parameters {network_params} {

            set network_params_dict [dict create]
            set network_type [dict_get_value ${network_params} "type" "inherit"]
            set jib_name [dict_get_value ${network_params} "jib_name" ""]
            set interface [dict_get_value ${network_params} "interface" "em0"]
            
            if {$network_type eq "inherit"} {
            	
                #dict set network_params_dict "ip4" "inherit"
                dict set network_params_dict "type" "inherit"
                
                if {$jib_name ne {}} {
                	
                	return -code error -errorcode {JAIL CONF JIB_NAME} \
                		"Jib name is not used in an inherit network"
                }
                
            } elseif {$network_type eq "jib"} {
            	
                dict set network_params_dict "type" "jib"
                
                if {${jib_name} ne {}} {
                	
                	dict set network_params_dict "jib_name" ${jib_name}
                	
                } else {
                	
                	return -code error -errorcode {JAIL CONF JIB_NAME} \
                		"Jib interface name is required when connecting to a jib network"
                }
                
                dict set network_params_dict "interface" $interface
                
            } else {
            
            	return -code error -errorcode {JAIL CONF NETWRK_TYPE} \
            		"Unknown network type ${network_type}"
            }

            return $network_params_dict
        }
        
        namespace eval macros {
        
        	proc network {network_params_dict} {
        	
        		set network_type [dict get ${network_params_dict} "type"] 
        		
        		set network_string {}
        		if {${network_type} eq "inherit" } {
                         
					 append network_string "ip4=inherit;\n\t"
				} elseif {${network_type} eq "jib"} {
			
					set jib_name [dict get ${network_params_dict} "jib_name"]
					set interface [dict get ${network_params_dict} "interface"]
					
			 		append network_string "vnet;\n\t"
			 		append network_string [subst {exec.prestart+="/usr/share/examples/jails/jib addm -b vessel ${jib_name} $interface";\n\t}]
			 		append network_string [subst {exec.poststop+="/usr/share/examples/jails/jib destroy ${jib_name}";\n\t}]
			 		append network_string [subst {vnet.interface="e0b_${jib_name}";\n\t}]
			 	} else {
			 		return -code error -errorcode {JAIL CONF NETWRK MACRO} \
			 			"Unknown network type in macro"
			 	}
			 	
			 	return ${network_string}
        	}
        }

        #Build the jail command which can be exec'd
        proc build_jail_conf {name mountpoint volume_datasets network limits \
                        	  cpuset jail_options args} {

            set network_params_dict [validate_network_parameters $network]

            #Add single quotes around any multi-word parts of the command
            set quoted_cmd [join [lmap word $args {expr {[llength $word] > 1 ?  "\'[join $word]\'" : $word }}]]

            textutil::expander jail_file_expander
            try {
                
                # Execute the expansion in the scope of this proc instead of global
                jail_file_expander evalcmd [list uplevel "#[info level]"]

                set jail_conf [jail_file_expander expand {
[set name] {
	path="[set mountpoint]";
	allow.mount;
	allow.mount.devfs;
	mount.devfs;
	allow.mount.zfs;
	enforce_statfs=1;
	[macros::network $network_params_dict]
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

}
                    
                }]
            } finally {
                rename jail_file_expander {}
            }
            
            puts stderr ${jail_conf}
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
