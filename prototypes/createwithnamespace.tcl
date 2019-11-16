package require TclOO
package require defer

oo::class create mytestclass {

    self export createWithNamespace

    constructor {} {
	puts stderr "constructor: [self]"
	puts stderr "[info object namespace [self]]"
    }
    
    destructor {
   
	puts stderr "Destroying [self]"
    }
}

proc testproc {} {
    namespace eval testproc {}
    mytestclass createWithNamespace test testproc
    mytestclass createWithNamespace test2 testproc
    defer::autowith {
	puts "deleting"
	namespace delete testproc
    }
}

testproc
