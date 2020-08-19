# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-
package require uuid
package require fileutil
package require appc::definition_file
package require appc::env
package require appc::jail
package require appc::zfs

namespace eval appc::build {

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

        proc transfer_build_context_from_interp {build_context build_interp} {

            dict set build_context current_dataset \
                [$build_interp eval {set current_dataset}]

            dict set build_context guid [$build_interp eval {set guid}]

            dict set build_context cmd [$build_interp eval {set cmd}]

            dict set build_context cwd [$build_interp eval {set cwd}]

            dict set build_context parent_image [$build_interp eval {set parent_image}]

            return $build_context
        }

        proc execute_appc_file {build_context appc_file status_channel} {

            #Sourcing the appc file calls the functions like RUN
            # and copy at a global level.  We definitely need to do
            # that in a jail.
            set interp_name {build_interp}

            #Create the interp and setup the necessary global options
            interp create $interp_name
            defer::with [list interp_name] {
                interp delete $interp_name
            }
            interp share {} $status_channel $interp_name
            $interp_name eval {
                package require AppcFileCommands
            }
            $interp_name eval [list set ::status_channel $status_channel]
            $interp_name eval [list set ::cmdline_options [dict get $build_context cmdline_options]]
            $interp_name eval {source [dict get $::cmdline_options file]}
            set build_context [transfer_build_context_from_interp $build_context $interp_name]

            return [transfer_build_context_from_interp $build_context $interp_name]
        }
    }
    
    proc build_command {args_dict status_channel}  {

        #build_context maintains the state for this build.  All
        #of the global variables set by sourcing the appc file
        #are copied into this dict.
        set build_context [dict create \
                               cmdline_options $args_dict \
                               from_called false \
                               parent_image {} \
                               current_dataset {} \
                               cwd {/} \
                               mountpoint {} \
                               name {} \
                               guid {} \
                               cmd {} \
                               status_channel $status_channel]
        
        set appc_file [dict get $build_context cmdline_options {file}]

        set build_context [_::execute_appc_file $build_context $appc_file $status_channel]
        
        #current_dataset is set by the FROM command
        set current_dataset [dict get $build_context current_dataset]
        if {[appc::zfs::snapshot_exists ${current_dataset}@b]} {
            appc::zfs::destroy ${current_dataset}@b
        }
        
        #create a snapshot that can be cloned by the run command
        # and also used as the right hand side of zfs diff
        appc::zfs::create_snapshot $current_dataset b

        set guid [dict get $build_context guid]
        set name $guid
        if {[dict exists $build_context cmdline_options name]} {
            set name [dict get $build_context cmdline_options name]
        }

        set build_dir [_::create_layer $current_dataset $guid $status_channel]

        #Create container definition file
        #zip up jail and definition file.
        #TODO: _::create_image
        #NOTE: My current thoughts for the difference between a layer
        # and an image is that a layer is just the filesystem artifacts
        # where-as an image is the fs artifacts as well as the meta data
        # files.  Example:
        #
        # layer: <guid>-layer.tgz
        # image: name:tag.zip
        #        - <guid>-layer.tgz
        #        - <whiteouts.txt>
        #        - <command.sh>
        #        - <files.txt>

        set tag {latest}
        if {[dict exists $build_context cmdline_options tag]} {
            set tag [dict get $build_context cmdline_options tag]
        }

        set cmd [dict get $build_context cmd]
        set cwd [dict get $build_context cwd]
        set parent_image [dict get $build_context parent_image]
        _::create_image $build_dir $name $tag \
            $cmd $cwd $parent_image $status_channel
    }
}

package provide appc::build 1.0.0
