# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

namespace eval appc::env {

    proc get_pool {} {
        global env
        set pool "zpool"
        if {[info exists env(APPC_POOL)]} {

            set pool $env(APPC_POOL)
        }

        return $pool
    }
    
    proc get_dataset_from_image_name {image_name} {

        set pool [get_pool]
        set container_path "${pool}/jails/${image_name}"
    }

    proc copy_resolv_conf {mountpoint} {
        # copy resolve.conf
        set resolv_file {/etc/resolv.conf}
        file copy -force $resolv_file [fileutil::jail $mountpoint $resolv_file]

    }
}
package provide appc::env 1.0.0
