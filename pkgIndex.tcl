package ifneeded appc::bsd 1.0.0 [list source [file join $dir bsd.tcl]]
package ifneeded appc::build 1.0.0 [list source [file join $dir build.tcl]]
package ifneeded appc::env 1.0.0 [list source [file join $dir environment.tcl]]
package ifneeded appc::jail 1.0.0 [list source [file join $dir jail.tcl]]
package ifneeded appc::native 1.0.0 [list load [file join $dir libappctcl.so]]
package ifneeded appc::run 1.0.0 [list source [file join $dir run.tcl]]
package ifneeded appc::zfs 1.0.0 [list source [file join $dir zfs.tcl]]

