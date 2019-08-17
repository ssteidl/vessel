package require debug
package require appc::env
package require appc::native
package require defer
package require uri
package require TclOO
#Pull is responsible for retrieving and unpacking an image
namespace eval appc::pull {

    debug define repo
    debug on pull 1 stderr

    namespace eval _ {
	oo::class create repo {

	    variable full_url
	    variable scheme
	    
	    constructor {url} {
		#Parse it to ensure it is valid
		set url_dict [appc::url::parse ${url}]
		set scheme [dict get $url_dict scheme]
		set full_url ${url}
	    }
	    
	    method pull_image {image tag} {
		return -code error errorcode {INTERFACECALL} \
		    "Subclass of repo must implement pull_image"
	    }

	    method put_image {image tag} {
		return -code error errorcode {INTERFACECALL} \
		    "Subclass of repo must implement put_image"
	    }

	    method get_url {} {

		return $full_url
	    }

	    method get_scheme {} {

		return $scheme
	    }
	}


	oo::class create file_repo {
	    superclass repo

	    variable path

	    #TODO: This should be a classmethod
	    method check_directory {dir_path} {


		return -code ok
	    }

	    constructor {url} {
		next $url

	        set url_parts [appc::url::parse $url]
		set scheme [dict get $url_parts scheme]

		set path [dict get $url_parts path]

		if {$scheme ne {file}} {
		    return -code error -errorcode {REPO SCHEME ENOTSUPPORTED} \
			"Scheme: $scheme is not supported"
		}

		
		if {![file exists $path] || ![file isdirectory $path]} {
		    return -code error -errorcode {REPO PATH EEXISTS} \
			"Path either doesn't exist or is not a directory: $dir_path"
		}
	    }

	    method pull_image {image tag downloaddir} {

		set image_path [file join $path "${image}:${tag}.zip"]
		if {![file exists $image_path]} {
		    return -code error -errorcode {REPO PULL ENOIMAGE} \
			"Image path does not exist: $image_path"
		}

		if {![file exists $downloaddir]} {
		    file mkdir $downloaddir
		}

		debug.repo "Copying image: ${image_path} -> ${downloaddir}"
		file copy $image_path $downloaddir

	    }

	    method put_image {image tag} {
		#TODO
	    }

	    destructor {
		puts stderr "destroying repo"
	    }
	}
    }
    
    proc pull {image tag repo_url} {
	debug.pull "pull{}: ${image},${tag},${repo_url}"

	set image_repo_path [string cat $repo_url / "${image}:${tag}.zip"]

	set workdir [appc::env::get_workdir]

	set downloaddir [file join $workdir {downloaded_images}]

	_::file_repo create repo $repo_url
	defer::defer repo destroy

	repo pull_image $image $tag $downloaddir

	set extracted_path [file join $downloaddir "${image}:${tag}"]

	exec unzip -d $extracted_path [file join $downloaddir "${image}:${tag}.zip"] >&@ stderr
    }

    proc pull_command {args_dict} {

	debug.pull "args: $args_dict"

	#TODO: Put this in an image module, it can do all of the packing
	#parsing name etc
	set image [dict get $args_dict image]
	set tag [dict get $args_dict tag]
	if {$tag eq {}} {
	    set tag {latest}
	}

	set repo [appc::env::get_repo_url]

	pull $image $tag $repo
    }
}

package provide appc::pull 1.0.0
