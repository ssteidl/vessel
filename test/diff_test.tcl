# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

source [file join .. zfs.tcl]

set diff_lines [appc::zfs::diff zroot/jails/FreeBSD/11.2-RELEASE@11.2-RELEASE zroot/jails/uwsgi-test]

set diff_dict [dict create]
foreach line [split $diff_lines "\n" ] {

    if {$line eq {}} {

        continue
    }
    
    set change_type [lindex $line 0]
    set path [lindex $line 1]
    dict lappend diff_dict $change_type $path
}

file mkdir work
cd work
set whiteout_file [open {whiteouts.txt} {w}]

foreach deleted_file [dict get $diff_dict {-}] {
    puts $whiteout_file $deleted_file
}

set files [list {*}[dict get $diff_dict {M}] {*}[dict get $diff_dict {+}]]
set tar_list_file [open {files.txt} {w}]
foreach path $files {

    puts $tar_list_file $path
}
flush $tar_list_file
close $tar_list_file
exec tar -cvf layer.tar -T {files.txt} >&@ stderr

exec gzip -r work > image.gz
