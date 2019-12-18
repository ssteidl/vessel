package require defer

proc sub_coro {} {
    puts stderr "subcoro init: [info coroutine]"
    set cb [yield]

    puts stderr "sub coro after yield: $cb"
    after idle $cb
}

proc main_coro {arg1} {

    defer::with [list arg1] {
	puts stderr "main coro exiting: $arg1"
    }
    
    puts stderr "coro1 setup"

    coroutine m2 sub_coro
    after idle [info coroutine]
    puts "yield in main_coro"
    yield

    puts stderr "yielding to sub coro"
    yieldto m2 [info coroutine]

    puts stderr "After yieldto"
    after idle [list rename [info coroutine] {}]
    yield
}

proc main {} {

    set coro1 [coroutine m1 main_coro "my arg1"]

    puts stderr "after coro1 setup"
}

main
vwait __forever__
