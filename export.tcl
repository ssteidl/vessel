package require appc::env
package require appc::metadata_db
package require appc::zfs
package require debug
package require uuid

namespace eval appc::export {

    debug define export
    debug on run 1 stderr
    
    namespace eval _ {

	proc create_layer {dataset guid status_channel} {

	    #Create the layer by generating a '@b' snapshot and diff'ing the
	    # changes from the '@a' snapshot.  A layer is a zip archive of
	    # the differences in the snapshots.

	    set bsnapshot "${dataset}@b"
	    if {[appc::zfs::snapshot_exists $bsnapshot]} {
		appc::zfs::destroy $bsnapshot
	    }

	    appc::zfs::create_snapshot $dataset {b}
	    
            set mountpoint [appc::zfs::get_mountpoint $dataset]
            set diff_dict [appc::zfs::diff ${dataset}@a ${dataset}@b]

            set workdir [appc::env::get_workdir]
            set build_dir [file join $workdir $guid]
            
            file mkdir $build_dir
            set old_dir [pwd]
            cd $build_dir
            set whiteout_file [open {whiteouts.txt} {w}]

            if {[dict exists $diff_dict {-}]} {
                foreach deleted_file [dict get $diff_dict {-}] {
                    puts $whiteout_file $deleted_file
                }
            }

            set files [list]
            if {[dict exists $diff_dict {M}]} {
                set files [list {*}[dict get $diff_dict {M}] {*}[dict get $diff_dict {+}]]
            }
            
            set tar_list_file [open {files.txt} {w}]

            #If the first line of the file is a '-C' then tar will chdir to the directory
            # specified in the second line of the file.
            puts $tar_list_file {-C}
            puts $tar_list_file "$mountpoint"

            foreach path $files {
                puts $tar_list_file [fileutil::stripPath "${mountpoint}" $path]
            }
            flush $tar_list_file
            close $tar_list_file
            exec tar -cavf ${guid}-layer.tgz -n -T {files.txt} >&@ $status_channel

            #TODO: Use a trace to return to the old directory. Or better
            # yet, don't change directory
            cd $old_dir
            return $build_dir
        }

        proc create_image {image_name image_tag output_dir status_channel} {

	    #Create the image metadata and zip it with the layer.  An image
	    # is the layer with the metadata zipped together.
	    
	    set output_image_path [file join $output_dir "${image_name}:${image_tag}.zip"]
	    if {[file exists $output_image_path]} {
		#Short circuit if the image already exists.
		return $output_image_path
	    }
	    #Create the image layer.
	    set dataset [appc::env::get_dataset_from_image_name $image_name $image_tag]
	    set guid [uuid::uuid generate]
	    set image_dir [create_layer $dataset $guid $status_channel]

	    set metadata_file [appc::metadata_db::metadata_file_path $image_name $image_tag]
	    file copy $metadata_file $image_dir
            set workdir [appc::env::get_workdir]

            #Ensure we cd back to the initial directory. Should probably just
            # use tcllib::defer
            trace add variable workdir unset [list apply {{old_pwd _1 _2 _3} {
                cd $old_pwd
            } } [pwd]]
	    cd $image_dir
	    
            exec zip -v -r -m $output_image_path . >&@ $status_channel
	    return $output_image_path
        }
    }
    
    proc export_image {image tag output_dir} {

	return [_::create_image $image $tag $output_dir stderr]
    }

    proc export_command {args_dict} {

	#TODO: Audit the code base and move all of this code into an
	# image class
	set image_w_tag [dict get $args_dict image]
	set image_components [split $image_w_tag :]
	set image_name [lindex $image_components 0]
	set image_tag {latest}
	if {[llength $image_components] > 1} {
	    set image_tag [lindex $image_components 1]
	}

	set output_dir [dict get $args_dict dir]
	return [export_image $image_name $image_tag $output_dir]

	#TODO: We should get rid of the export command.  It should just be part of
	#the publish command with a file:// scheme
    }
}

package provide appc::export 1.0.0
