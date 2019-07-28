# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require appc::env
package require appc::native

namespace eval appc::publish {

    namespace eval _:: {

        proc publish_s3 {uri_dict} {

            set scheme [dict get $uri_dict scheme]
            # if {$scheme ne s3}
        }
    }
    
    proc publish_command {args_dict} {

        set tag [dict get $args_dict tag]
        if {$tag eq {}} {
            set tag {latest}
        }

        set image_name [dict get $args_dict image]
        
        set workdir [appc::env::get_workdir]
        set repo_url [appc::env::get_repo]
        set repo_url_dict [appc::url::parse $repo_url]

        set scheme [dict get $repo_url_dict scheme]
        set path [dict get $repo_url_dict path]
        switch -exact  $scheme {

            file {
                if {![file isdirectory $path]} {
                    return -code error -errorcode {PUBLISH ENOTDIR} "Path is not a directory: $path"
                }

                file copy [file join $workdir "${image_name}:${tag}.zip"] $path
            }
            s3 {
                return -code error -errorcode {PUBLISH NYI S3} "S3 support is not yet implemented"
            }
            default {
                return -code error -errorcode {PUBLISH SCHEME ENOTSUPPORTED } \
                    "Scheme not supported for publishing: $scheme"
            }
        }
    }
}

package provide appc::publish 1.0.0
