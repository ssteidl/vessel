# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require appc::native
package require appc::env
package require mustache
namespace eval appc::jail {

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
        proc build_jail_conf {name mountpoint network args} {

            set network_params_dict [build_network_parameters $network]
            set network_params_mustache_ctx [list]
            dict for {key value} $network_params_dict {
                lappend network_params_mustache_ctx [dict create parameter $key value $value]
            }

            set jail_cmd "jail -c path=$mountpoint"
            foreach {param value} [array get jail_parameters] {

                set jail_cmd [string cat $jail_cmd " " "${param}=${value}"]
            }

            #Add single quotes around any multi-word parts of the command
            set quoted_cmd [join [lmap word $args {expr {[llength $word] > 1 ?  "\'[join $word]\'" : $word }}]]

            set mustache_ctx [dict create name $name mountpoint $mountpoint network_params $network_params_mustache_ctx command $quoted_cmd]
            

            #TODO: Run mustache in a safe interpreter
            #TODO: Host and hostname should be different.
            #TODO: Allow setting any jail parameter
            #can contain different values then name
            set jail_file_template {
                
                #change the open and close tags so emacs doesn't get confused with braces
                {{=<% %>=}}
                <%name%> {
                    path=<%mountpoint%>;
                    host.hostname=<%name%>;
                    sysvshm=new;
                    allow.mount;
                    allow.mount.devfs;
                    mount.devfs;
                    allow.mount.zfs;
                    enforce_statfs=1;
                    persist=1;
                    <%#network_params%>
                    <%parameter%>=<%value%>;
                    <%/network_params%>
                    exec.start="<%&command%>";
                }
            }
                    
            set jail_conf [::mustache::mustache $jail_file_template $mustache_ctx]

            return $jail_conf
        }
    }

    proc run_jail {name mountpoint chan_dict network callback args} {

        #Create the conf file
        set jail_conf [_::build_jail_conf $name $mountpoint $network {*}$args]
        set jail_conf_file {}
        set jail_conf_file_chan [file tempfile jail_conf_file]

        puts $jail_conf_file_chan $jail_conf
        close $jail_conf_file_chan
        
        set jail_command [list jail -f $jail_conf_file -c $name]
        
        puts stderr "JAIL CONF: $jail_conf"

        appc::exec $chan_dict [list $callback $jail_conf_file] {*}$jail_command
    }
}

package provide appc::jail 1.0.0
