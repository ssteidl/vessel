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
            ${log}::debug "image_name: $image_name -> $image,$tag"
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
 
    # Utility functions used for downloading and verifying the FreeBSD base image.
    namespace eval _::base_image {
        
        #TODO: Unpacking belongs in the import module
        
        proc execute_unpack {archive_dir archive extract_dir} {
            # Unpack a tarball with name 'archive' that is located in 'archive_dir'
            # to 'extract_dir'
            
            set old_pwd [pwd]
            try {
                cd $dir
                exec tar -C ${archive_dir} -xvf $archive >&@ $status_channel
            } finally {
                cd ${old_pwd}   
            }
        }
        
        proc get_unpack_base_image_params {image_path mountpoint} {
         
            set image_dir [file dirname $image_path]
            set image_name [file tail $image_path]
            
            switch -glob $image_name {
                
                FreeBSD*.txz {}
                
                default {
                    return -code error -errorcode {IMAGE BASE ILLEGAL} \
                    "FreeBSD base image expected to be named like FreeBSD*.txz"       
                }
            }
            
            if {![file exists $image_dir]} {
                return -code error -errorcode {IMAGE PATH NODIR} \
                "The directory that should contain the FreeBSD base image does not exist"   
            }
            
            return [list $image_dir $image_name $mountpoint]
        }
        
        
        proc parse_manifest {manifest_chan} {
            
            # Reads the MANIFEST from a channel and returns the sha256 of the
            # base.txz file.
            
            # example line: 
            #base.txz	e85b256930a2fbc04b80334106afecba0f11e52e32ffa197a88d7319cf059840	26492	base	"Base system (MANDATORY)"	on
            
            set line {}
            set sha256 {}
            while {[gets ${manifest_chan} line] > 0} {
                set image_file [lindex $line 0]
                if {${image_file} eq "base.txz"} {
                    set sha256 [lindex $line 1]
                    set hash_size [string length $sha256]
                    if {${hash_size} != 64} {
                        return -code error -errorcode {IMAGE BASE MANIFEST EHASH} \
                        "A hash with incorrect length (${hash_size}) found in the MANIFEST for base.txz.  A sha256 hash size (64 chars) was expected."
                    }
                    return $sha256
                }
            }
            
            return -code error -errorcode {IMAGE BASE MANIFEST ECORRUPT} \
            "A hash was not found in the manifest file for base.txz"
        }
        
        proc validate_sha256 {image_path expected_sha256sum} {
        
            # Validate that the base image's sha256 matches the expected sha256 provided by the MANIFEST
            #
            # returns true if the sha256 matches false otherwise
            
            # Example sha256sum output: SHA256 (../FreeBSD:12.3-RELEASE.txz) = e85b256930a2fbc04b80334106afecba0f11e52e32ffa197a88d7319cf059840
            
            variable ::vessel::repo::log
            
            set sha256sum_output [exec sha256sum $image_path]
            set sha256sum [lindex ${sha256sum_output} 0]
            
            ${log}::debug "base image sha256: ${sha256sum}, expected: ${expected_sha256sum}"
            
            if {$sha256sum ne ${expected_sha256sum}} {
                return false
            }
            
            return true
        }
        
        proc check_for_existing_files {manifest_file_path base_image_path} {
            
            # Checks if all of the base image files have been downloaded already.  
            # Returns true if the base.txz image has been downloaded and verified
            # against the hash in the MANIFEST file.
            
            set image_valid false
            
            if {[file exists ${base_image_path}] && \
                [file exists ${manifest_file_path}]} {
                
                set manifest_chan [open ${manifest_file_path} "r"]
                
                try {
                    set expected_sha256 [parse_manifest $manifest_chan]
                } finally {
                    close ${manifest_chan}
                }
                
                set image_valid [validate_sha256 ${base_image_path} ${expected_sha256}]
            }
            
            return $image_valid
        }
        
        proc execute_fetch {base_url destination_dir} {
            variable ::vessel::repo::log
            #check for existing files should just be inlined in this function
            
            set base_image_path [file join ${destination_dir} base.txz]
            set manifest_file_path [file join ${destination_dir} MANIFEST]
            
            set image_exists [check_for_existing_files ${manifest_file_path} ${base_image_path}]
            
            if {! ${image_exists}} {
                ${log}::debug "Image does not exist.  Downloading..."
            } else {
                ${log}::debug "Image exists.  Skipping download"
                return ${base_image_path}
            } 
            
            #Some files need to be downloaded
            set url "${base_url}/{MANIFEST,base.txz}"
            
            # Save the file at URL to destination using curl.
            exec -ignorestderr curl -L -O --create-dirs --output-dir ${destination_dir} $url
            
            #After downloading, check that the images are valid
            set image_exists [check_for_existing_files ${manifest_file_path} ${base_image_path}]
            if {! ${image_exists}} {
                return -code error -errorcode {IMAGE BASE ECORRUPT} \
                "Image was downloaded but is corrupt"
            }
            
            return ${base_image_path}
        }
        
        proc get_fetch_params {arch name version download_dir} {
            # Returns the list of parameters needed to fetch the base tarball.
            
            set url "https://ftp.freebsd.org/pub/FreeBSD/releases/$arch/$version"
            set base_image_destination [file join ${download_dir} "FreeBSD:${version}"]
            return [list $url $base_image_destination]
        }
    }
    
    proc fetch_base_image {name version} {
        
        # Download a base image to the download directory only if the base
        # image does not already exist or it does not match the sha256 in the
        # MANIFEST file.

        if {$name ne "FreeBSD" } {
            return -code error -errorcode {BUILD IMAGE FETCH} \
                "Only FreeBSD images are currently allowed"
        }
        
        #We require the image to be the same as the host architecture
        set arch [vessel::bsd::host_architecture]
        set download_dir [vessel::env::image_download_dir]
        set fetch_params [_::base_image::get_fetch_params $arch $name $version $download_dir]
        set base_image_file [_::base_image::execute_fetch {*}$fetch_params]
        
        return ${base_image_file}
    }
    
    # TODO: Belongs in import module
    proc extract_base_image {image_path image_dataset} {
        # Extract the base image into the mountpoint of image_dataset
        
        set mountpoint [vessel::zfs::get_mountpoint $image_dataset]
        set unpack_params [_::get_unpack_base_image_params ${base_image_path} ${image_dataset} ${mountpoint}]
        execute_unpack {*}$unpack_params
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
                
                #Check if the image is in the download directory before pulling it
                if {[file exists [file join $downloaddir}
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
