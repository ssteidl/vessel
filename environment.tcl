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
        return [get_from_env APPC_WORKDIR [file join [pwd] .workdir]]
    }
    
    proc get_repo_url {} {

        #Defaults to a directory in the workdir
        return [get_from_env APPC_REPO_URL [uri::join path [get_workdir]/local_repo scheme file]]
    }
    
    proc get_dataset_from_image_name {image_name {tag {}}} {

        set pool [get_pool]
        set container_path "${pool}/jails/${image_name}"
        if {$tag ne {}} {
            set container_path "${container_path}/${tag}"
        }
        return $container_path
    }

    proc copy_resolv_conf {mountpoint} {
        # copy resolve.conf
        set resolv_file {/etc/resolv.conf}
        file copy -force $resolv_file [fileutil::jail $mountpoint $resolv_file]
    }
}
package provide appc::env 1.0.0
