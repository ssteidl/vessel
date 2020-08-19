package require debug
package require appc::env
package require appc::native
package require defer
package require fileutil
package require uri
package require TclOO

namespace eval appc::repo {

    debug define repo
    debug on repo 1 stderr
    
    oo::class create repo {

	variable _full_url
	variable _scheme
	variable _path
	
	constructor {url} {
	    set full_url ${url}
	    
	    #Parse it to ensure it is valid
	    set url_dict [appc::url::parse ${url}]

	    set _scheme [dict get $url_dict scheme]
	   
	    set _path [dict get $url_dict path]
	}
	
	method pull_image {image tag} {
	    return -code error errorcode {INTERFACECALL} \
		"Subclass of repo must implement pull_image"
	}

	method put_image {image tag} {
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
	
	method get_url {} {

	    return $_full_url
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
		    "Path either doesn't exist or is not a directory: $_path"
	    }
	}

	method pull_image {image tag downloaddir} {

	    set image_path [file join [my get_path] "${image}:${tag}.zip"]
	    if {![file exists $image_path]} {
		return -code error -errorcode {REPO PULL ENOIMAGE} \
		    "Image path does not exist: $image_path"
	    }

	    if {![file exists $downloaddir]} {
		file mkdir $downloaddir
	    }

	    debug.repo "Copying image: ${image_path} -> ${downloaddir}"
	    try {
		file copy $image_path $downloaddir
	    } trap {POSIX EEXIST} {1 2} {
		debug.repo "Image already exists.  Continuing"
	    }
	}

	method put_image {image tag} {
	    set path [my get_path]

	    set image_zip_name "${image}:${tag}.zip"
	    set image_path [file join $path $image_zip_name]
	    set workdir [appc::env::get_workdir]
	    set repo_url [appc::env::get_repo_url]

	    set image_path [file join $workdir $image_zip_name]
	    exec curl file://localhost/$image_path -o [file join $path $image_zip_name] \
		>&@ [my get_status_channel]
	}

	destructor {
	    debug.repo "destroying repo"
	}
    }

    proc repo_factory {repo_url} {
	set repo_url_dict [appc::url::parse $repo_url]

	set scheme [dict get $repo_url_dict scheme]
	set path [dict get $repo_url_dict path]

	set repo {}
	switch -exact  $scheme {

	    file {
		
		return [appc::repo::file_repo new $repo_url]
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

package provide appc::repo 1.0.0
