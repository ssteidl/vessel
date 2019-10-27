# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

source environment.tcl

namespace eval appc::jail {

    namespace eval _ {
        proc build_command {name mountpoint args} {

            #TODO: Allow run jail command parameters to be overridden
            array set jail_parameters [list \
                                           "ip4" "inherit" \
                                           "host.hostname" $name \
                                           "sysvshm" "new" \
                                           "allow.mount" "1" \
                                           "allow.mount.devfs" "1" \
                                           "mount.devfs" "1"]

            #TODO: Allow user to configure shell parameter
            set shell {/bin/sh}

            set jail_cmd "jail -c path=$mountpoint"
            foreach {param value} [array get jail_parameters] {

                set jail_cmd [string cat $jail_cmd " " "${param}=${value}"]
            }

            #Add single quotes around any multi-word parts of the command
            set quoted_cmd [join [lmap word $args {expr {[llength $word] > 1 ?  "\'[join $word]\'" : $word }}]]
            
            set jailed_cmd "$shell -c \"$quoted_cmd\""
            set command_parameter "command=$jailed_cmd"
            return [string cat $jail_cmd " " $command_parameter]
        }
    }
    
    proc run_jail {name mountpoint pty args} {

        set jail_command [_::build_command $name $mountpoint {*}$args]
        puts stderr "JAIL COMMAND: $jail_command"
        puts stderr "using pty: $pty"

        if {$pty ne {}} {
            #Interactive
            set pty_chan [open $pty RDWR]
            set chan_dict [dict create stdin $pty_chan stdout $pty_chan stderr $pty_chann]
            appc::exec $chan_dict {*}$jail_command
        } else {
            #Non-interactive
            #I think we want to implement this as well instead of
            #using tcl utilities but not 100% sure yet
        }
        # set jail_command_list [list | {*}$jail_command >&@ $pty]
        # puts "jail command list: $jail_command_list"
        # set command_channel [open $jail_command_list w]
        # set "blocking on command channel"
        # close $command_channel
        # set "command channel closed"
    }
}

package provide appc::jail 1.0.0
