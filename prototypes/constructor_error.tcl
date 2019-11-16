package require TclOO

oo::class create aclass {

    self export createWithNamespace
    
    variable _str

    constructor {str} {

	set _str $str
    }

    destructor {

	puts stderr "aclass destructor $_str"
    }
}

oo::class create container {

    self export createWithNamespace
    
    variable _inst1
    variable _inst2

    constructor {} {
	set ns [info object namespace [self]]
	set _inst1 [aclass new "first inst"]
	puts stderr "inst1: $_inst1"
	set _inst2 [aclass new "second inst"]
	puts stderr "inst2: $_inst2"
	#return -code error "Test error"
	
    }

    destructor {
	puts stderr "container destructor, $_inst1"
	#$_inst1 destroy

	#This error gets eaten since there is
	#an error already in progress
	#$_inst2 destroy 
    }
}

namespace eval testns {}
set obj [container createWithNamespace testns::obj testns]
namespace delete testns


