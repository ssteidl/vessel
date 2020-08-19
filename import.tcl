package require debug
package require appc::env
package require appc::native
package require defer
package require fileutil
package require uri
package require TclOO

namespace eval appc::import {
    #appc::import is responsible for unpacking and "importing"
    #appc images into the zfs pool

    debug define import
    debug on import 1 stderr

    namespace eval _ {

	proc create_layer {image_name version image_dir status_channel} {

	    # We don't know the uuid so we glob in the image_dir and
	    # use what should be the only thing there
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
		debug.import "Cloning parent image snapshot: '$parent_image_snapshot' to '$new_dataset'"
		appc::zfs::clone_snapshot $parent_image_snapshot $new_dataset
	    }

	    if {![appc::zfs::snapshot_exists ${new_dataset}@a]} {
		
		appc::zfs::create_snapshot ${new_dataset} a
	    }
	    
	    #Now clone the new dataset into a version dataset.  This means
	    #that the 'new_dataset' will always be the same as its parent
	    #dataset.  We have to do this because we can't have a dataset
	    #without a parent.  So for example, the appcdevel image (named
	    #devel) can't have a dataset called <appc_pool>/jails/devel/0
	    #without first having <appc_pool>/jails/devel
	    set versioned_new_dataset [appc::env::get_dataset_from_image_name $image_name $version]
	    if {![appc::zfs::dataset_exists $versioned_new_dataset]} {
		appc::zfs::clone_snapshot ${new_dataset}@a $versioned_new_dataset
	    }

	    if {![appc::zfs::snapshot_exists ${versioned_new_dataset}@a]} {
		appc::zfs::create_snapshot $versioned_new_dataset a
	    }
	    
	    #Untar layer on top of parent file system
	    set mountpoint [appc::zfs::get_mountpoint $versioned_new_dataset]
	    exec tar -C $mountpoint -xvf [file join $image_dir ${uuid}-layer.tgz] >&@ $status_channel
	    flush $status_channel

	    #TODO: delete files from whitelist
	    if {[appc::zfs::snapshot_exists ${versioned_new_dataset}@b]} {
		#If the b snapshot already exists then we need to delete it and
		#make a new one.
		appc::zfs::destroy ${versioned_new_dataset}@b
	    }
	    appc::zfs::create_snapshot $versioned_new_dataset b
	}
    }

    proc import {image tag image_dir status_channel} {
	debug.import "import{}: ${image},${tag}"

k	set extracted_path [file join $image_dir "${image}:${tag}"]

	#Extract files into extracted_path overriding files that already exist.
	exec unzip -o -d $extracted_path [file join $image_dir "${image}:${tag}.zip"] >&@ $status_channel
	_::create_layer $image $tag $extracted_path $status_channel
    }
}

package provide appc::import 1.0.0
