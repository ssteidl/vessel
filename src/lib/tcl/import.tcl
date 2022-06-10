# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

package require vessel::env
package require vessel::metadata_db
package require vessel::native
package require defer
package require fileutil
package require json
package require logger
package require uri
package require TclOO


namespace eval vessel::import {
    #vessel::import is responsible for unpacking and "importing"
    #vessel images into the zfs pool

    logger::initNamespace [namespace current] debug
    variable log [logger::servicecmd [string trimleft [namespace current] :]]

    namespace eval _ {

        proc create_layer {image tag extracted_path status_channel} {
            variable ::vessel::import::log

            # We don't know the uuid so we glob in the image_dir and
            # use what should be the only thing there
            set layer_file_glob [glob "${extracted_path}/*-layer.tgz"]
            if {[llength $layer_file_glob] != 1} {
                return -code error -errorcode {VESSEL IMPORT LAYER} \
                    "Unexpected number of layer files in image: $layer_file_glob"
            }
            set layer_file [lindex $layer_file_glob 0]

            #Read parent image from metadata file
            set extracted_metadata_file [file join ${extracted_path} "${image}:${tag}.json"]
            set metadata_json [fileutil::cat $extracted_metadata_file]
            set metadata_dict [json::json2dict $metadata_json]

            #NOTE: The metadata file allows a list of parent images.
            #We current only support one layer of parent images.  In
            #the future we can use arbitrarily long chain of parent
            #images.
            ${log}::debug "parsing metadata file"
            set parent_image [lindex [dict get $metadata_dict parent_images] 0]
            set parent_image_components [split $parent_image :]
            set parent_image_name [lindex $parent_image_components 0]
            set parent_image_version [lindex $parent_image_components 1]
            set parent_image_snapshot [vessel::env::get_dataset_from_image_name $parent_image_name $parent_image_version]
            set parent_image_snapshot "${parent_image_snapshot}@${parent_image_version}"

            ${log}::debug "parent image: $parent_image_snapshot"

            #TODO: fetch the parent image if it doesn't exist.  We can
            #move the fetch_image command from the vessel_file_commands
            if {![vessel::zfs::snapshot_exists $parent_image_snapshot]} {
                return -code error -errorcode {NYI} \
                    "Pulling parent image is not yet implemented: '$parent_image_snapshot'"
            }

            #Clone parent filesystem
            set new_dataset [vessel::env::get_dataset_from_image_name $image $tag]
            if {![vessel::zfs::dataset_exists $new_dataset]} {
                ${log}::debug "Cloning parent image snapshot: '$parent_image_snapshot' to '$new_dataset'"
                vessel::zfs::clone_snapshot $parent_image_snapshot $new_dataset
            } else {
                ${log}::debug "New dataset already exists: $new_dataset"
            }

            if {![vessel::zfs::snapshot_exists ${new_dataset}@a]} {
                vessel::zfs::create_snapshot ${new_dataset} a
            }

            #Untar layer on top of parent file system
            set mountpoint [vessel::zfs::get_mountpoint $new_dataset]
            exec tar -C $mountpoint -xvf $layer_file >&@ $status_channel
            flush $status_channel

            #Read whiteout file and delete the listed files.
            # The whiteout file is the list of files from the base image that
            # need to be deleted.  It's called whiteouts because that's how
            # unionfs works as it can't delete files in the lower layers.
            set whiteouts_file_path [file join ${extracted_path} {whiteouts.txt}]
            set whiteout_chan [open $whiteouts_file_path RDONLY]
            while {[gets $whiteout_chan deleteme_path] >= 0} {

                set jailed_path [fileutil::jail $mountpoint $deleteme_path]
                try {
                    ${log}::debug "Deleting file $jailed_path"
                    file delete -force $deleteme_path
                } on error {msg} {
                    ${log}::debug "Failed to delete file $jailed_path: $msg"
                }
            }

            if {[vessel::zfs::snapshot_exists ${new_dataset}@b]} {
                #If the b snapshot already exists then we need to delete it and
                #make a new one.
                vessel::zfs::destroy ${new_dataset}@b
            }
            vessel::zfs::create_snapshot $new_dataset b

            #Very last thing is importing the image metadata.  We import
            #instead of copying the file to safeguard against mismatching versions
            vessel::import::import_image_metadata_dict $metadata_dict
        }
        
        namespace eval base_image {
        
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
   
        }
    }

    proc import_image_metadata {name tag cwd cmd parent_images} {
        #Used when the image already exists (maybe it was built) and
        # we just need to store the metadata.

        vessel::metadata_db::write_metadata_file $name $tag $cwd $cmd $parent_images
    }

    proc import_image_metadata_dict {metadata_dict} {
        set name [dict get $metadata_dict name]
        set tag [dict get $metadata_dict tag]
        set command [dict get $metadata_dict command]
        set cwd [dict get $metadata_dict cwd]
        set parent_images [dict get $metadata_dict parent_images]

        import_image_metadata $name $tag $cwd $command $parent_images
    }

    # Import an image into the vessel environment.
    #
    # params:
    #
    # image_w_tag: The name of the image without tag appended
    # tag: The tag of the image
    # image_dir: The directory where the image file resides
    proc import {image tag image_dir status_channel} {
        variable log

        ${log}::debug "import: ${image},${tag}"

        set extracted_path [file join $image_dir "${image}:${tag}"]

        #Extract files into extracted_path overriding files that already exist.
        exec unzip -o -d $extracted_path [file join $image_dir "${image}:${tag}.zip"] >&@ $status_channel
        _::create_layer $image $tag $extracted_path $status_channel
    }
    
    proc import_base_image {base_image_path pool status_channel} {
        # archive_dir archive extract_dir
    }
}

package provide vessel::import 1.0.0
