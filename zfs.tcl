# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

namespace eval appc::zfs {

    #TODO: ensemble for public api
    proc get_pools {} {

        set pools [exec zpool list -H]
        set lines [split $pools \n]

        set pools_dict [dict create]
        set headers [list name size alloc free ckpoint expandsz frag cap dedup health altroot]
        foreach pool_line $lines {

            set dict_list [list]
            lmap pool $pool_line header $headers {lappend dict_list $header $pool}

            set name [lindex $pool_line 0]
            dict set pools_dict $name $dict_list
        }

        return $pools_dict
    }

    proc get_snapshots {} {

        set snapshots [exec zfs list -H -t snap]
        set lines [split $snapshots {\n}]

        set snapshots_dict [dict create]
        set headers [list name used avail refer mountpoint]
        foreach snapshot_line $lines {

            set dict_list [list]
            lmap snapshot $snapshot_line header $headers {lappend dict_list $header $snapshot}

            set name [lindex $snapshot_line 0]
            dict set snapshots_dict $name $dict_list
        }

        return $snapshots_dict
    }

    proc clone_snapshot {snapshot new_dataset} {

        variable snapshots_dict
        if {![dict exists $snapshots_dict $snapshot]} {

            puts stderr "Attempted to clone a non existent snapshot: $snapshot"

            #TODO: Raise error instead of exit
            exit 1
        }

        exec zfs clone $snapshot $new_dataset >&@ stderr
    }

    proc get_mountpoints {} {

        set mountpoints [exec zfs get -H mountpoint]
        set lines [split $mountpoints \n]
        
        set mp_dict [dict create]
        set headers [list name property value source]
        foreach mp_line $lines {

            set dict_list [list]
            lmap mountpoint [split $mp_line \t] header $headers {lappend dict_list $header $mountpoint}

            set name [lindex $mp_line 0]
            dict set mp_dict $name $dict_list
        }

        return $mp_dict
    }

    proc snapshot_exists {snapshot_path} {
        variable snapshots_dict

        return [dict exists $snapshots_dict $snapshot_path]
    }

    proc get_mountpoint {dataset} {

        variable mountpoints_dict
        set mountpoints_dict [get_mountpoints]
        if {![dict exists $mountpoints_dict $dataset value]} {

            return -code error -errorcode {ZFS MOUNTPOINT EEXIST} \
                "mountpoint does not exist for dataset: $dataset"
        }

        return [dict get $mountpoints_dict $dataset value]
    }

    proc update_mountpoints {} {
        variable mountpoints_dict

        set mountpoints_dict [get_mountpoints]
    }

    proc update_snapshots {} {
        variable snapshots_dict

        set snapshots_dict [get_snapshots]
    }
    
    proc create_dataset {new_dataset_name} {

        exec zfs create -p $new_dataset_name >&@ stderr

        update_mountpoints
        return
    }

    proc create_snapshot {image_dataset image_version} {

        exec zfs snapshot "${image_dataset}@${image_version}"

        update_snapshots
        update_mountpoints

        return
    }

    proc diff {snapshot dataset} {

        #TODO Add support for async diff to make a package in a streaming
        #fashion

        set diff_output [exec -keepnewline zfs diff -H $snapshot $dataset]
        return $diff_output
    }
    
    variable snapshots_dict [get_snapshots]
    variable mountpoints_dict [get_mountpoints]
}
