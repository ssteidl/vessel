package require textutil::adjust
package require textutil::expander


set mountpoint {/root}
set name {my_jail}
set network_params_dict [dict create "ip4" "inherit"]
set volume_datasets [list "zroot/jails/volumes/redb"]
set quoted_cmd "sh"
textutil::expander jail_file_expander
set jail_conf [jail_file_expander expand {
    [set name] {
	path="[set mountpoint]";
	host.hostname="[set name]";
	sysvshm=new;
	allow.mount;
	allow.mount.devfs;
	mount.devfs;
	allow.mount.zfs;
	enforce_statfs=1;
	[set network_string {}
	 dict for {parameter value} ${network_params_dict} {
	     append network_string "${parameter}=${value};"
	 }
	 set network_string]

	
	[set volume_string {}
	 foreach volume $volume_datasets {
	    set jail_string [subst {exec.created="zfs jail $name $volume";\n}]
	    append volume_string $jail_string
	    set mount_string [subst {exec.start+="zfs mount $volume";}]
	    append volume_string $mount_string
	}
	 set volume_string]
	 exec.start+="[set quoted_cmd]";
     }}]

puts $jail_conf
