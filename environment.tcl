# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-
package require uri

namespace eval appc::env {

    proc get_from_env {key {_default {}}} {

        global env
        set value $_default
        if {[info exists env($key)]} {

            set value $env($key)
        }

        return $value
    }
    
    proc get_pool {} {

        return [get_from_env APPC_POOL "zpool"]
    }

    proc get_workdir {} {

        return [get_from_env APPC_WORKDIR [uri::join path [pwd]/.workdir scheme file]
    }
    
    proc get_repo {} {

        return [get_workdir]/repo
    }
    
    proc get_dataset_from_image_name {image_name} {

        set pool [get_pool]
        set container_path "${pool}/jails/${image_name}"
        return $container_path
    }

    proc copy_resolv_conf {mountpoint} {
        # copy resolve.conf
        set resolv_file {/etc/resolv.conf}
        file copy -force $resolv_file [fileutil::jail $mountpoint $resolv_file]

    }
}
package provide appc::env 1.0.0
