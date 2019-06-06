# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require fileutil

source bsd.tcl
source environment.tcl
source zfs.tcl

namespace eval appc::run {

    namespace eval _ {

        proc handle_volume_argument {mountpoint volume_argument} {

            set arg_list [split $volume_argument ":"]
            if {[llength $arg_list] != 2} {

                return -code error -errorcode {MOUNT ARGS} "volume requires a value in the format <source>:<dest>"
            }

            set sourcedir [lindex $arg_list 0]
            set destdir [lindex $arg_list 1]
            set jailed_dest_path [fileutil::jail $mountpoint $destdir]
            
            if {[file exists $sourcedir] && [file isdirectory $sourcedir]} {

                appc::bsd::null_mount $sourcedir $jailed_dest_path
            } else {

                return -code error -errorcode {MOUNT DEST EEXIST} "Source path for volume argument does not exist"
            }

            return $jailed_dest_path
        }
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

        set jailed_mount_path {}
        if {[dict exists $args_dict "volume"]} {

            set jailed_mount_path [_::handle_volume_argument $mountpoint [dict get $args_dict "volume"]]
        }
        
        set command [dict get $args_dict "command"]
        set hostname "appc-container"
        if {[dict exists $args_dict "name" ]} {
            
            set hostname [dict get $args_dict "name"]
        }

        catch {
            appc::jail::run_jail $hostname $mountpoint {*}$command
        }

        appc::bsd::umount $jailed_mount_path
    }
}
