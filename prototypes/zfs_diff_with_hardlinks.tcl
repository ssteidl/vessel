package require appc::zfs
if {[llength $argv] < 1} {
    puts stderr "Usage: $argv0 <dataset>"
    exit 1
}

set dataset_mount [lindex $argv 0]
set inode_path_pairs [exec find $dataset_mount -exec stat -f "%i,%N" \{\} \;]

set dataset [string trim $dataset_mount /]
set output_dict [appc::zfs::diff "${dataset}@a" ${dataset}]

set inode_dict [dict create]
foreach {inode_path_pair} [split $inode_path_pairs \n] {

    foreach {inode path}  [split $inode_path_pair ,] {
	dict lappend inode_dict $inode $path
    }
}

set inode_path_pairs [list]

set modified_file_list [list {*}[dict get $output_dict {M}] {*}[dict get $output_dict {+}]]

foreach path $modified_file_list {
    array set stat_buf {}

    file lstat $path stat_buf

    foreach inode_path [dict get $inode_dict $stat_buf(ino)] {
	dict lappend output_dict $stat_buf(ino) $inode_path
    }
}

dict for {key paths} $output_dict {

    if {$key eq {M} || $key eq {+} || $key eq {-} } {
	puts "continuing"
	continue
    }

    foreach path $paths {
	puts $path
    }
}
