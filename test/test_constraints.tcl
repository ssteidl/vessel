package require tcltest
namespace import ::tcltest::*
    
testConstraint root [expr {$env(USER) eq "root"}]
testConstraint aws [expr {[info exists env(VESSEL_TEST_AWS)] && $env(VESSEL_TEST_AWS)}]

package provide vessel::test::testconstraints 1.0.0