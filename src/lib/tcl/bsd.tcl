# -*- mode: tcl; indent-tabs-mode: nil; tab-width: 4; -*-

namespace eval vessel::bsd {

    proc host_architecture {} {

        return [exec uname -m]
    }

    proc host_version {} {

        return [exec uname -r]
    }

    proc null_mount {source_dir dest_dir} {

        if {$source_dir eq {}} {

            return -code error -errorcode {BSD MOUNT PARAM} "source_dir parameter is empty for bind mount"
        }

        if {$dest_dir eq {}} {

            return -code error -errorcode {BSD MOUNT PARAM} "dest_dir parameter is empty for bind mount"
        }
        file mkdir $dest_dir

        exec mount -t nullfs $source_dir $dest_dir
    }

    proc umount {path} {

        if {$path ne {} && [file exists $path]} {
            exec umount $path
        }
    }

    proc parse_devd_rctl_str {rctl_str} {
        # Parse the devd string and break it down into a dictionary if it
        # is from the rctl subsystem.  Examples of devd strings are below

        # !system=ACPI subsystem=CMBAT type=\_SB_.PCI0.BAT0 notify=0x80
        # !system=CAM subsystem=periph type=error device=cd0 serial="VB2-01700376" cam_status="0xcc" scsi_status=2 scsi_sense="70 02 3a 00" CDB="00 00 00 00 00 00 " 
        # !system=CAM subsystem=periph type=error device=cd0 serial="VB2-01700376" cam_status="0xcc" scsi_status=2 scsi_sense="70 02 3a 00" CDB="00 00 00 00 00 00 " 
        # !system=RCTL subsystem=rule type=matched rule=jail:f55687e0-8475-4e3e-ada9-1197ee857536:wallclock:devctl=5 pid=1273 ruid=0 jail=f55687e0-8475-4e3e-ada9-1197ee857536

        set rctl_str [string trim $rctl_str]
        set matched [regexp {^!system=RCTL subsystem=rule type=matched rule=(jail:.*:.*:.*) pid=(\d+) ruid=(\d) jail=(.*)$} $rctl_str matched_str rule pid ruid jail]
        set rctl_dict [dict create]
        if {$matched} {

            set matched [regexp {^jail:(.*):(.*):(.*)$} $rule matched_str subjectid resource action]
            if (!$matched) {
                return -code error -errorCode {VESSEL RCTL RULE EINVAL}
            }
            set rule_dict [dict create "subjectid" $subjectid "resource" $resource "action" $action]
            set rctl_dict [dict create "rule" $rule_dict "pid" $pid "ruid" $ruid "jail" $jail]
        }
        
        return $rctl_dict
    }
}

package provide vessel::bsd 1.0.0
