# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require fileutil
package require uuid

package require appc::bsd
package require appc::env
package require appc::zfs

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
        #TODO: Mount the dataset if not mounted
        
        puts $args_dict

        set image [dict get $args_dict "image"]
        set mountpoints_dict [appc::zfs::get_mountpoints]

        set image_dataset [appc::env::get_dataset_from_image_name $image]
        puts stderr "RUN COMMAND image dataset: $image_dataset"
        if {![dict exists $mountpoints_dict $image_dataset]} {
            #TODO: retrieve and unpack layer
        }

        set b_snapshot_exists [appc::zfs::snapshot_exists "${image_dataset}@b"]
        puts stderr "RUN COMMAND b snapshot exists: $b_snapshot_exists"
        if {$b_snapshot_exists} {

            set uuid [uuid::uuid generate]
            set container_dataset [appc::env::get_dataset_from_image_name $uuid]

            puts stderr "Cloning b snapshot: ${image_dataset}@b $container_dataset"
            appc::zfs::clone_snapshot "${image_dataset}@b" $container_dataset
        } else {

            #Support manually created datasets
            set container_dataset $image_dataset
        }
        
        set mountpoint [appc::zfs::get_mountpoint $container_dataset]

        set jailed_mount_path {}
        if {[dict exists $args_dict "volume"]} {

            set jailed_mount_path [_::handle_volume_argument $mountpoint [dict get $args_dict "volume"]]
        }

        appc::env::copy_resolv_conf $mountpoint
        
        set command [dict get $args_dict "command"]
        set hostname "appc-container"
        if {[dict exists $args_dict "name" ]} {
            
            set hostname [dict get $args_dict "name"]
        }

        catch {
            appc::jail::run_jail $hostname $mountpoint {*}$command
        }

        appc::bsd::umount $jailed_mount_path

        if {[dict get $args_dict "remove"]} {
            appc::zfs::destroy $container_dataset
        }
    }
}

package provide appc::run 1.0.0
