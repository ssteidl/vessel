# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-
package require uuid
package require fileutil

namespace eval appc::build {

    namespace eval _ {

        variable cmdline_options [dict create]
        variable from_called false
        variable current_dataset {}
        variable cwd {/}
        variable mountpoint {}
        variable name {}
        variable guid {}

        proc build_jail_command {args} {

            variable name joe
            variable mountpoint
            
            #TODO: Allow run jail command parameters to be overridden
            array set jail_parameters [list \
                                           "ip4" "inherit" \
                                           "host.hostname" $name]

            #TODO: Allow user to set shell parameter via appc file
            set shell {/bin/sh}

            set jail_cmd [list jail -c path=$mountpoint]
            foreach {param value} [array get jail_parameters] {

                lappend jail_cmd "${param}=${value}"
            }

            set args [string map { \\\{ \{ \{ \" \\\} \} \} \"} $args]
            set jailed_cmd [list $shell -c $args]
            set command_parameter "command=$jailed_cmd"
            set jail_cmd [lappend jail_cmd {*}$command_parameter]
            return [list {*}$jail_cmd]
        }

        proc fetch_image {name version} {

            if {$name ne "FreeBSD" } {

                return -code error -errorcode {BUILD IMAGE FETCH} \
                    "Only FreeBSD images are currently allowed"
            }

            
            #TODO: Support a registry.  For now only support
            #freebsd base.txz

            #TODO: What should we do for a download directory? For now
            #I'll just use tmp

            #TODO: For now we require the image to be the same as the
            #host architecture
            set arch [appc::bsd::host_architecture]

            #TODO: Test needs to be the mountpoint of the new dataset
            set url "https://ftp.freebsd.org/pub/FreeBSD/releases/$arch/$version/base.txz"
            exec fetch -o - $url | tar -C test -xvf - >&@ stderr
        }
    }
    
    proc build_command {args_dict}  {

        variable _::cmdline_options
        set cmdline_options $args_dict
        
        set appc_file [dict get $cmdline_options {file}]

        source $appc_file

        #Create container definition file
        #zip up jail and definition file.
    }
}

proc FROM {image} {
    variable appc::build::_::current_dataset
    variable appc::build::_::cmdline_options
    variable appc::build::_::mountpoint
    variable appc::build::_::from_called
    variable appc::build::_::name
    variable appc::build::_::guid
    
    puts stderr "FROM: $image"

    #TODO: Where do I get the pool from?
    set pool "zroot"

    #TODO: change to use ${pool}/appc by default
    set appc_parent_dataset "${pool}/jails"
    
    #Image is in the form <image name>:<version>
    #So image name is the dataset and version is the snapshot name

    set image_tuple [split $image ":"]
    if {[llength $image_tuple] ne 2} {

        return -code error -errorcode {BUILD IMAGE FORMAT} "Image must be in the format <name:version>"
    }

    set image_name [lindex $image_tuple 0]
    set image_version [lindex $image_tuple 1]
    set snapshot_name "${image_name}@${image_version}"
    set snapshot_path "${appc_parent_dataset}/${snapshot_name}"

    set snapshot_exists [appc::zfs::snapshot_exists $snapshot_path]
    puts stderr "${snapshot_path}:${snapshot_exists}"

    if {!$snapshot_exists} {

        appc::build::_::fetch_image $image_name $image_version
    }

    # Clone base jail and name new dataset with guid
    set name [dict get $cmdline_options {name}]
    set guid [uuid::uuid generate]

    if {$name eq {}} {

        set name $guid
    }
    
    set new_dataset "${appc_parent_dataset}/${name}"
    appc::zfs::clone_snapshot $snapshot_path $new_dataset

    # Set current_dataset using guid.
    set current_dataset $new_dataset

    set mountpoint [appc::zfs::get_mountpoint $new_dataset]
    
    # copy resolve.conf
    set resolv_file {/etc/resolv.conf}
    file copy $resolv_file [fileutil::jail $mountpoint $resolv_file]

    set from_called true
    return
}

proc CWD {path} {
    variable appc::build::_::cwd
    variable appc::build::_::from_called

    if {!$from_called} {

        return -code error -errorcode {BUILD CWD} \
            "CWD called before FROM.  FROM must be the first command called."
    }
    
    #Verify cwd exists in the dataset
    #set cwd variable
    puts stderr "CWD: $path"

    set cwd $path
}

proc COPY {source dest} {
    variable appc::build::_::cwd
    variable appc::build::_::mountpoint
    variable appc::build::_::from_called

    if {!$from_called} {

        return -code error -errorcode {BUILD COPY} \
            "COPY called before FROM.  FROM must be the first command called."
    }
    
    #dest is relative to cwd in the jail
    #source is on the host system and is relative to current pwd
    puts stderr "COPY: $source -> $dest"

    set absolute_path [fileutil::jail $mountpoint [file join $cwd $dest]]

    file copy $source $absolute_path
}

proc EXPOSE {port} {

    #This will need to integrate with pf.
    puts stderr "EXPOSE $port"
}

proc RUN {args} {
    variable appc::build::_::mountpoint
    variable appc::build::_::name
    variable appc::build::_::from_called
    
    if {!$from_called} {

        return -code error -errorcode {BUILD CWD} \
            "RUN called before FROM.  FROM must be the first command called."
    }

    if {[llength $args] == 0} {

        return -code error -errorcode {BUILD RUN ARGS} \
            "RUN invoked without arguments" 
    }

    set cmd [appc::build::_::build_jail_command {*}$args]

    #jail and run command
    puts stderr "RUN: $cmd"
    
    #TODO: I'm not sure of the best way to run the jail.  I could
    #just exec jail.  But there may be some down sides with signal
    #handling. The alternative is fork exec.  I think to start I'll
    # try to just exec jail by creating a temporary jail file.
    # Either way, the process is done, I need to kill the jail because
    # it could still be running if the command started any background
    # processes.
    try {
        exec {*}$cmd >&@ stdout
    } trap {CHILDSTATUS} {results options} {

        puts stderr "Run failed: $results"
        return -code error -errorcode {BUILD RUN}
    }

    puts "after"
    return
}

proc CMD {command} {

    #create the init script to run with CMD.
}