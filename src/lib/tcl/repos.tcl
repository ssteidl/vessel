# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require vessel::env
package require vessel::export
package require vessel::import
package require vessel::native

package require defer
package require fileutil
package require uri
package require TclOO

namespace eval vessel::repo {

    logger::initNamespace [namespace current] debug
    variable log [logger::servicecmd [string trimleft [namespace current] :]]

    oo::class create repo {

        variable _full_url
        variable _scheme
        variable _path

        constructor {url} {
            set _full_url ${url}

            #Parse it to ensure it is valid
            set url_dict [vessel::url::parse ${url}]

            set _scheme [dict get $url_dict scheme]

            set _path [dict get $url_dict path]
        }

        method pull_image {image tag downloaddir} {
            return -code error errorcode {INTERFACECALL} \
                "Subclass of repo must implement pull_image"
        }

        method put_image {image_path} {
            return -code error errorcode {INTERFACECALL} \
                "Subclass of repo must implement put_image"
        }

        method reconfigure {} {
            return -code error errorcode {INTERFACECALL} \
                "Subclass of repo must implement reconfigure"
        }

        method delete_image {image tag} {
            return -code error errorcode {INTERFACECALL} \
                "Subclass of repo must implement delete"
        }

        method image_exists {image tag} {
            return -code error errorcode {INTERFACECALL} \
                "Subclass of repo must implement image_exists"
        }

        method get_url {} {

            return ${_full_url}
        }

        method get_scheme {} {

            return $_scheme
        }

        method get_path {} {
            return $_path
        }

        method get_status_channel {} {
            #subclasses can override if they need to change
            return stderr
        }
    }

    oo::class create file_repo {
        superclass repo

        constructor {url} {
            next $url

            if {[my get_scheme] ne {file}} {
                return -code error -errorcode {REPO SCHEME ENOTSUPPORTED} \
                    "Scheme: $scheme is not supported"
            }

            set path [my get_path]
            if {![file exists $path] || ![file isdirectory $path]} {
                return -code error -errorcode {REPO PATH EEXISTS} \
                    "Path either doesn't exist or is not a directory: $path"
            }
        }

        method pull_image {image tag downloaddir} {
            variable ::vessel::repo::log

            set image_path [file join [my get_path] "${image}:${tag}.zip"]
            if {![my image_exists $image $tag]} {
                return -code error -errorcode {REPO PULL ENOIMAGE} \
                    "Image path does not exist: $image_path"
            }

            if {![file exists $downloaddir]} {
                file mkdir $downloaddir
            }

            ${log}::debug "Copying image: ${image_path} -> ${downloaddir}"
            try {
                file copy $image_path $downloaddir
            } trap {POSIX EEXIST} {1 2} {
                ${log}::warn "Image already exists.  Continuing"
            }
        }

        method put_image {image_path} {
            set output_path [my get_path]

            #TODO: Parse out image name from image path
            set repo_url [vessel::env::get_repo_url]

            set image_path_components [file split $image_path]
            set image_zip_name [lrange $image_path_components end end]
            puts "$image_path_components,$image_zip_name"
            set extension [file extension $image_zip_name]
            if {$extension ne ".zip"} {
                return -code error -errorcode {REPO PUT EFORMAT} \
                    "Unexpected image extension: $extension"
            }

            exec curl file://localhost/$image_path -o \
                [file join $output_path $image_zip_name] \
                >&@ [my get_status_channel]
        }

        method image_exists {image tag} {

            set image_path [file join [my get_path] "${image}:${tag}.zip"]
            return [file exists $image_path]
        }

        destructor {
            ${log}::debug "destroying repo"
        }
    }

    oo::class create s3repo {
        superclass repo
        variable _config_file
        variable _s3_cmd

        constructor {url {config_file {}}} {
            next $url
            
            if {$config_file ne {}} {
                set _s3_cmd [list s3cmd -c $config_file]
            } else {
                set _s3_cmd [list s3cmd]
            }

            if {[my get_scheme] ne {s3}} {
                return -code error -errorcode {REPO SCHEME ENOTSUPPORTED} \
                    "Scheme: $scheme is not supported by s3repo"
            }
        }

        method _get_s3_image_url {image tag} {
            #TODO: this is everywhere
            set image_name "${image}:${tag}.zip"
            puts "image_name: $image_name -> $image,$tag"
            set image_url [join [list [my get_url] $image_name] /]
        }

        method pull_image {image tag downloaddir} {
            my variable _s3_cmd
            set image_url [my _get_s3_image_url $image $tag]
            exec {*}${_s3_cmd} get --skip-existing $image_url $downloaddir >&@ stderr
        }

        method put_image {image_path} {
            my variable _s3_cmd
            exec {*}${_s3_cmd} put $image_path [my get_url] >&@stderr
        }

        method reconfigure {} {
            return -code error errorcode {INTERFACECALL} \
                "Subclass of repo must implement reconfigure"
        }

        method delete_image {image tag} {
            return -code error errorcode {INTERFACECALL} \
                "Subclass of repo must implement delete"
        }

        method image_exists {image tag} {
            my variable _s3_cmd
            
            set image_url [my _get_s3_image_url $image $tag]
            set ls_data [exec {*}${_s3_cmd} ls $image_url]
            return [expr [string length $ls_data] > 0]
        }
    }

    proc repo_factory {repo_url} {
        set repo_url_dict [vessel::url::parse $repo_url]

        set scheme [dict get $repo_url_dict scheme]
        set path [dict get $repo_url_dict path]

        set repo {}
        switch -exact  $scheme {

            file {
                return [vessel::repo::file_repo new $repo_url]
            }
            s3 {
                return [vessel::repo::s3repo new $repo_url [vessel::env::s3cmd_config_file]]
            }
            default {
                return -code error -errorcode {PUBLISH SCHEME ENOTSUPPORTED } \
                    "Scheme not supported for publishing: $scheme"
            }
        }

    }

    #Execute a repo command, either push or pull.
    # Args:
    # 
    # cmd: publish|pull
    # 
    # args_dict: image - The image name
    #            tag (optional) - The image tag [default: latest]
    # 
    proc repo_cmd {cmd args_dict} {
        variable log

        ${log}::debug "repo args: $args_dict"
        set image [dict get $args_dict image]

        set tag [dict get $args_dict tag]
        if {$tag eq {}} {
            set tag {latest}
        }

        set repo [vessel::repo::repo_factory [vessel::env::get_repo_url]]
        defer::with [list repo] {
            $repo destroy
        }

        set downloaddir [vessel::env::image_download_dir]
        
        switch -exact $cmd {

            publish {
                #NOTE: We may want to make export directories something separate
                #from download directories.  For now, we'll keep it separate.
                #
                #vessel publish --tag=local kafka
                set image_file [vessel::export::export_image $image $tag $downloaddir]
                if {![$repo image_exists $image $tag]} {
                    $repo put_image $image_file
                }
            }
            pull {
                #Pulls the command.  Basically a GET and an import.
                $repo pull_image $image $tag $downloaddir
                vessel::import::import $image $tag $downloaddir stderr
            }
        }
    }

    # Proxy a pull request to the repo_cmd proc.
    proc pull_repo_image {image tag} {
        set args_dict [dict create image $image tag $tag]
        tailcall repo_cmd pull $args_dict
    }
}

package provide vessel::repo 1.0.0
