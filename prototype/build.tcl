# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-
package require uuid
package require fileutil

source zfs.tcl
namespace eval appc::build {


    namespace eval _ {

        variable cmdline_options [dict create]
        variable from_called false
        variable current_dataset {}
        variable cwd {/}
        variable mountpoint
    }
    
}

proc FROM {image} {
    variable current_dataset
    variable cmdline_options
    
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

        return -code error -errorcode {BUILD IMAGE FETCH NYI} \
            "Fetching remote images is not yet implemented"
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

    set jail_path [appc::zfs::get_mountpoint $new_dataset]
    
    # copy resolve.conf
    set resolv_file {/etc/resolv.conf}
    file copy $resolv_file [fileutil::jail $jail_path $resolv_file]

    return
}

proc CWD {path} {
    variable cwd

    #Verify cwd exists in the dataset
    #set cwd variable
    puts stderr "CWD: $path"
}

proc COPY {source dest} {
    #dest is relative to cwd in the jail
    #source is on the host system and is relative to current pwd
    puts stderr "COPY: $source -> $dest"
}

proc EXPOSE {port} {

    #This will need to integrate with pf.
    puts stderr "EXPOSE $port"
}

proc RUN {command} {

    #jail and run command
    puts stderr "RUN: $command"
}

proc CMD {command} {

    #create the init script to run with CMD.
}

proc build_command {args_dict}  {

    variable cmdline_options
    set cmdline_options $args_dict
    
    set appc_file [dict get $cmdline_options {file}]

    source $appc_file

    #Create container definition file
    #zip up jail and definition file.
}

