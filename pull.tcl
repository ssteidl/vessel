package require debug
package require appc::env
package require appc::native
package require defer
package require fileutil
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
		try {
		    file copy $image_path $downloaddir
		} trap {POSIX EEXIST} {1 2} {
		    debug.repo "Image already exists.  Continuing"
		}

	    }

	    method put_image {image tag} {
		#TODO
	    }

	    destructor {
		puts stderr "destroying repo"
	    }
	}

	proc create_layer {image_name version image_dir} {

	    #TODO: Fix this it's gross.  We don't know the uuid so
	    # we glob in the image_dir and use what should be the only thing there
	    set image_dir [glob "${image_dir}/*"]
	    set uuid [lindex [file split $image_dir] end]

	    #Read parent image from file
	    set parent_image [fileutil::cat [file join $image_dir {parent_image.txt}]]
	    set parent_image [string trim $parent_image]
	    
	    set parent_image_parts [split $parent_image :]
	    set parent_image_name [lindex $parent_image_parts 0]

	    set parent_image_version [lindex $parent_image_parts 1]

	    set parent_image_snapshot [appc::env::get_dataset_from_image_name $parent_image_name $parent_image_version]
	    set parent_image_snapshot "${parent_image_snapshot}@${parent_image_version}"
	    
	    #pull parent filesystem if it doesn't exist
	    if {![appc::zfs::snapshot_exists $parent_image_snapshot]} {
		return -code error -errorcode {NYI} \
		    "Pulling parent image is not yet implemented: '$parent_image_snapshot'"
	    }

	    #Clone parent filesystem
	    set new_dataset [appc::env::get_dataset_from_image_name $image_name]
	    if {![appc::zfs::dataset_exists $new_dataset]} {
		debug.pull "Cloning parent image snapshot: '$parent_image_snapshot' to '$new_dataset'"
		appc::zfs::clone_snapshot $parent_image_snapshot $new_dataset
	    }

	    if {![appc::zfs::snapshot_exists ${new_dataset}@a]} {
	    
	    
		appc::zfs::create_snapshot ${new_dataset} a
	    }
	    
	    #Now clone the new dataset into a version dataset.  This means that the 'new_dataset' will
	    #always be the same as its parent dataset.  We have to do this because we can't have a
	    #dataset without a parent.  So for example, the appcdevel image (named devel) can't
	    #have a dataset called <appc_pool>/jails/devel/0 without first having <appc_pool>/jails/devel
	    set versioned_new_dataset [appc::env::get_dataset_from_image_name $image_name $version]
	    appc::zfs::clone_snapshot ${new_dataset}@a $versioned_new_dataset
	    
	    appc::zfs::create_snapshot $versioned_new_dataset a
	    #Untar layer on top of parent file system
	    set mountpoint [appc::zfs::get_mountpoint $versioned_new_dataset]
	    exec tar -C $mountpoint -xvf [file join $image_dir ${uuid}-layer.tgz] >&@ stderr

	    #TODO: delete files from whitelist
	    
	    appc::zfs::create_snapshot $versioned_new_dataset b
	}
    }
    
    proc pull {image tag repo_url} {
	debug.pull "pull{}: ${image},${tag},${repo_url}"

	set image_repo_path [string cat $repo_url / "${image}:${tag}.zip"]

	set workdir [appc::env::get_workdir]

	set downloaddir [file join $workdir {downloaded_images}]

	set repo_var [_::file_repo create repo $repo_url]
	defer::with [list repo_var] {
	    $repo_var destroy
	}
	repo pull_image $image $tag $downloaddir

	set extracted_path [file join $downloaddir "${image}:${tag}"]

	exec unzip -d $extracted_path [file join $downloaddir "${image}:${tag}.zip"] >&@ stderr
	_::create_layer $image $tag $extracted_path
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
