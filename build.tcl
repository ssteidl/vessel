# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-
package require uuid
package require fileutil
source definition_file.tcl
source environment.tcl
source jail.tcl

namespace eval appc::build {

    namespace eval _ {

        variable cmdline_options [dict create]
        variable from_called false
        variable current_dataset {}
        variable cwd {/}
        variable mountpoint {}
        variable name {}
        variable guid {}
        variable definition_file [definition_file create container_def]
        variable cmd {}

        proc fetch_image {image_dataset name version} {

            if {$name ne "FreeBSD" } {

                return -code error -errorcode {BUILD IMAGE FETCH} \
                    "Only FreeBSD images are currently allowed"
            }

            set mountpoint [appc::zfs::get_mountpoint $image_dataset]
            
            #TODO: Support a registry.  For now only support
            #freebsd base.txz

            #TODO: What should we do for a download directory? For now
            #I'll just use tmp

            #TODO: For now we require the image to be the same as the
            #host architecture
            set arch [appc::bsd::host_architecture]

            #TODO: Test needs to be the mountpoint of the new dataset
            set url "https://ftp.freebsd.org/pub/FreeBSD/releases/$arch/$version/base.txz"
            exec curl -L --output - $url | tar -C $mountpoint -xvf - >&@ stderr
        }

        proc create_layer {dataset guid} {

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

            set files [list {*}[dict get $diff_dict {M}] {*}[dict get $diff_dict {+}]]
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
            exec tar -cavf ${guid}-layer.tgz -n -T {files.txt} >&@ stderr

            #TODO: Use a trace to return to the old directory. Or better
            # yet, don't change directory
            cd $old_dir
            return $build_dir
        }

        proc create_image {image_dir image_name image_tag} {
            variable cmd
            variable cwd
            set command [subst {
#! /bin/sh

cd $cwd
$cmd
            }]

            set command_file [open [file join $image_dir command.sh] w+ 755]
            puts $command_file $command
            close $command_file

            set workdir [appc::env::get_workdir]
            puts "workdir: $workdir"
            set zip_path [file join $workdir ${image_name}:${image_tag}]
            puts stderr "zip_path: $zip_path"
            exec zip -v -m -r $zip_path $image_dir
        }
    }
    
    proc build_command {args_dict}  {

        variable _::cmdline_options
        variable _::current_dataset
        variable _::guid
        set cmdline_options $args_dict
        puts stderr $cmdline_options
        set appc_file [dict get $cmdline_options {file}]

        source $appc_file

        #create a snapshot that can be cloned by the run command
        # and also used as the right hand side of zfs diff
        appc::zfs::create_snapshot $current_dataset b

        set name $_::guid
        if {[dict exists $cmdline_options name]} {
            set name [dict get $cmdline_options name]
        }
        set build_dir [_::create_layer $current_dataset $guid]
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
        if {[dict exists $cmdline_options tag]} {
            set tag [dict get $cmdline_options tag]
        }

        _::create_image $build_dir $name $tag
    }
}

proc FROM {image} {
    variable appc::build::_::current_dataset
    variable appc::build::_::cmdline_options
    variable appc::build::_::mountpoint
    variable appc::build::_::from_called
    variable appc::build::_::name
    variable appc::build::_::guid

    global env
    
    puts stderr "FROM: $image"

    set pool "zroot"
    if {[info exists env(APPC_POOL)]} {
        set pool $env(APPC_POOL)
    }

    #TODO: change to use ${pool}/appc by default
    set appc_parent_dataset "${pool}/jails"
    
    #Image is in the form <image name>:<version>
    #So image name is the dataset and version is the snapshot name

    set image_tuple [split $image ":"]
    if {[llength $image_tuple] ne 2} {

        return -code error -errorcode {BUILD IMAGE FORMAT} "Image must be in the format <name:version>"
    }

    set image_name [lindex $image_tuple 0]
    set image_version [lindex $image_tuple 1]
    set snapshot_name "${image_name}/${image_version}@${image_version}"
    set snapshot_path "${appc_parent_dataset}/${snapshot_name}"

    puts "[appc::zfs::get_snapshots]"
    set snapshot_exists [appc::zfs::snapshot_exists $snapshot_path]
    puts stderr "${snapshot_path}:${snapshot_exists}"

    if {!$snapshot_exists} {

        #TODO: We need to update the way images are handled.  The dataset should
        # be /appc/<image_name>/<image_version>
        # and the snapshot should be /appc/<image_name>/<image_version>@<guid>
        # perhaps the snapshot should be a repeat of the image version.  Not sure.

        set image_dataset "${appc_parent_dataset}/${image_name}/${image_version}"
        appc::zfs::create_dataset $image_dataset
        appc::build::_::fetch_image $image_dataset $image_name $image_version
        appc::zfs::create_snapshot $image_dataset $image_version
    }

    # Clone base jail and name new dataset with guid
    set name [dict get $cmdline_options {name}]
    set guid [uuid::uuid generate]

    if {$name eq {}} {

        set name $guid
    }
    
    set new_dataset "${appc_parent_dataset}/${name}"
    appc::zfs::clone_snapshot $snapshot_path $new_dataset

    #Snapshot with version a is used for zfs diff
    appc::zfs::create_snapshot $new_dataset a
    
    set current_dataset $new_dataset

    set mountpoint [appc::zfs::get_mountpoint $new_dataset]

    #resolv_conf is needed here because RUN commands may need to
    #access the internet.  Running a container should always update
    #resolv conf.  In the future, maybe we just ignore it instead
    #of leaving it in the image.
    appc::env::copy_resolv_conf $mountpoint

    set from_called true
    return
}

proc CWD {path} {
    variable appc::build::_::cwd
    variable appc::build::_::from_called

    if {!$from_called} {

        return -code error -errorcode {BUILD CWD} \
            "CWD called before FROM.  FROM must be the first command called."
    }
    
    #Verify cwd exists in the dataset
    #set cwd variable
    puts stderr "CWD: $path"

    set cwd $path
}

proc COPY {source dest} {
    variable appc::build::_::cwd
    variable appc::build::_::mountpoint
    variable appc::build::_::from_called

    if {!$from_called} {

        return -code error -errorcode {BUILD COPY} \
            "COPY called before FROM.  FROM must be the first command called."
    }
    
    #dest is relative to cwd in the jail
    #source is on the host system and is relative to current pwd
    puts stderr "COPY: $source -> $dest"

    set absolute_path [fileutil::jail $mountpoint [file join $cwd $dest]]

    file copy $source $absolute_path
}

proc EXPOSE {port} {

    #This will need to integrate with pf.
    puts stderr "EXPOSE $port"
}

proc RUN {args} {
    variable appc::build::_::mountpoint
    variable appc::build::_::name
    variable appc::build::_::from_called

    if {!$from_called} {

        return -code error -errorcode {BUILD CWD} \
            "RUN called before FROM.  FROM must be the first command called."
    }

    if {[llength $args] == 0} {

        return -code error -errorcode {BUILD RUN ARGS} \
            "RUN invoked without arguments" 
    }
    
    try {
        puts stderr "RUN mountpoint: $mountpoint"
        appc::jail::run_jail "${name}-buildcmd" $mountpoint {*}$args
    } trap {CHILDSTATUS} {results options} {

        puts stderr "Run failed: $results"
        return -code error -errorcode {BUILD RUN}
    }

    puts "after"
    return
}

proc CMD {args} {

    variable cmd

    if {$cmd ne {}} {
        return -code error -errorcode {BUILD CMD EEXISTS} "Only one CMD is allowed"
    }

    set cmd $command
}

package provide appc::build 1.0.0
