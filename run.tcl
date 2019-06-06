# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

source bsd.tcl
source environment.tcl
source zfs.tcl

namespace eval appc::run {

    namespace eval _ {

    }

    proc run_command {args_dict} {

        #TODO: Handle the 'volume' argument
        
        puts $args_dict

        set image [dict get $args_dict "image"]
        set mountpoints_dict [appc::zfs::get_mountpoints]

        set dataset [appc::env::get_dataset_from_image_name $image]

        if {![dict exists $mountpoints_dict $dataset]} {
            #retrieve and unpack layer
        }

        set mountpoint [appc::zfs::get_mountpoint $dataset]

        set command [dict get $args_dict "command"]
        set hostname "appc-container"
        if {[dict exists $args_dict "name" ]} {
            
            set hostname [dict get $args_dict "name"]
        }
        appc::jail::run_jail $hostname $mountpoint {*}$command
    }
}
