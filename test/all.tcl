package require tcltest
namespace import ::tcltest::*

if {$env(LOGNAME) ne {root}} {
    puts stderr "The test suite needs to be executed as the root user: 'sudo -E tclsh8.6 ./all.tcl'"
    exit 1
}

configure -errfile error.log
runAllTests