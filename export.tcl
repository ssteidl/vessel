namespace eval appc::export {

    namespace eval _ {
        proc create_layer {dataset guid status_channel} {

            puts stderr "create_layer $dataset"
            puts stderr "guid: $guid"

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

        proc create_image {image_dir image_name image_tag \
                               image_cmd image_cwd parent_image status_channel} {

            #TODO: Let's not do this.  Let's just execute the
            #command provide on the command line or if one is not
            #provided use '/bin/sh /etc/rc'
            set command [subst {
#! /bin/sh

cd $image_cwd
$image_cmd
            }]

            #Write the command file
            set command_file_path [file join $image_dir command.sh]
            set command_file [open $command_file_path w+ 0755]
            puts $command_file $command
            close $command_file

            #Write the parent image file
            set parent_image_file_path [file join $image_dir parent_image.txt]
            set parent_image_file [open $parent_image_file_path w+ 0644]
            puts $parent_image_file $parent_image
            close $parent_image_file

            set workdir [appc::env::get_workdir]
            puts "workdir: $workdir"
            set zip_path [file join $workdir ${image_name}:${image_tag}]
            puts stderr "zip_path: $zip_path"

            #Ensure we cd back to the initial directory. Should probably just
            # use tcllib defer
            trace add variable workdir unset [list apply {{old_pwd _1 _2 _3} {
                cd $old_pwd
            } } [pwd]]
            cd $workdir
            set relative_image_dir [file join . [fileutil::stripPwd $image_dir]]
            puts stderr "image_dir: $relative_image_dir"
            exec zip -v -r -m ${image_name}:${image_tag} $relative_image_dir >&@ $status_channel
        }
    }
    
    proc export_layer {image tag} {
	#TODO: Export tagged dataset to a file.

	#I'm currently trying to decide how to create the layer image.
	#I need to find how to get the parent image and current
	#working directory.  Perhaps we just skip this for now until
	#we can get a database going which can hold those fields. eh,
	#we are going to need the parent image though.

	
    }
}
