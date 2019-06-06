# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

source environment.tcl

namespace eval appc::jail {

    namespace eval _ {
	proc build_command {name mountpoint args} {

	    #TODO: Allow run jail command parameters to be overridden
	    array set jail_parameters [list \
					   "ip4" "inherit" \
					   "host.hostname" $name]

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
    
    proc run_jail {name mountpoint args} {

	set jail_command [_::build_command $name $mountpoint {*}$args]
	exec {*}$jail_command >&@ stdout
    }
}
