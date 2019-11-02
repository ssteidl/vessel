proc test {} {

    set test_var jack
    set traced_pwd [pwd]
    trace add variable traced_pwd unset [list apply {{tv name1 name2 op} {
	puts stderr "$name1,$name2,$op,$tv"
    }} $test_var]
}

test
