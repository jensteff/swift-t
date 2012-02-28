
# Based on STP test 238- fibonacci
# Copied here for stability
# Hand-optimized

package require turbine 0.0.1
namespace import turbine::*

if { [ info exists env(TURBINE_TEST_PARAM_1) ] } {
    set N $env(TURBINE_TEST_PARAM_1)
} else {
    set N 4
}

proc fib { stack o n } {
    set parent $stack
    set stack [ adlb::unique stack ]
    container_init $stack string
    container_insert $stack _parent $parent
    container_insert $stack n $n
    container_insert $stack o $o
    set rule_id [ turbine::c::rule_new ]
    turbine::c::rule $rule_id if-0 "$n" "" "tc: if-0 $stack"
}

proc if-0 { stack } {
    set n [ stack_lookup $stack n ]
    set n_value [ get_integer $n ]
    if { $n_value } {
        set parent $stack
        set stack [ adlb::unique stack ]
        container_init $stack string
        container_insert $stack _parent $parent
        set __t0 [ adlb::unique __t0 ]
        integer_init $__t0
        container_insert $stack __t0 $__t0
        set __l0 [ adlb::unique __l0 ]
        integer_init $__l0
        set_integer $__l0 1
        turbine::minus_integer $stack [ list $__t0 ] [ list $n $__l0 ]
        set rule_id [ turbine::c::rule_new ]
        turbine::c::rule $rule_id if-1 "$__t0" "" "tc: if-1 $stack"
    } else {
        set o [ stack_lookup $stack o ]
        set_integer $o 0
    }
}

proc if-1 { stack } {
    set __t0 [ stack_lookup $stack __t0 ]
    set __pscope1 [ stack_lookup $stack _parent ]
    set o [ stack_lookup $__pscope1 o ]
    set __t0_value [ get_integer $__t0 ]
    if { $__t0_value } {
        set n [ stack_lookup $__pscope1 n ]
        # set parent $stack
        # set stack [ adlb::unique stack ]
        # container_init $stack string
        # container_insert $stack _parent $parent
        set __l1 [ adlb::unique __l1 ]
        integer_init $__l1
        set __l2 [ adlb::unique __l2 ]
        integer_init $__l2
        set __l3 [ adlb::unique __l3 ]
        integer_init $__l3
        set_integer $__l3 1
        turbine::minus_integer $stack [ list $__l2 ] [ list $n $__l3 ]
        set rule_id [ turbine::c::rule_new ]
        turbine::c::rule $rule_id fib [ list $__l2 ] [ list $__l1 ] "tp: fib $stack $__l1 $__l2"
        set __l4 [ adlb::unique __l4 ]
        integer_init $__l4
        set __l5 [ adlb::unique __l5 ]
        integer_init $__l5
        set __l6 [ adlb::unique __l6 ]
        integer_init $__l6
        set_integer $__l6 2
        turbine::minus_integer $stack [ list $__l5 ] [ list $n $__l6 ]
        set rule_id [ turbine::c::rule_new ]
        turbine::c::rule $rule_id fib [ list $__l5 ] [ list $__l4 ] "tp: fib $stack $__l4 $__l5"
        turbine::plus_integer $stack [ list $o ] [ list $__l1 $__l4 ]
    } else {
	turbine::set1 no_stack $o
    }
}

proc rules {  } {
    turbine::c::log function:rules
    set stack [ adlb::unique stack ]
    container_init $stack string
    set __l0 [ adlb::unique __l0 ]
    integer_init $__l0
    set __l1 [ adlb::unique __l1 ]
    integer_init $__l1
    global N
    puts "N: $N"
    set_integer $__l1 $N
    set rule_id [ turbine::c::rule_new ]
    turbine::c::rule $rule_id fib [ list $__l1 ] [ list $__l0 ] "tp: fib $stack $__l0 $__l1"
    turbine::trace $stack [ list ] [ list $__l0 ]
}

turbine::defaults
turbine::init $engines $servers
turbine::start rules
turbine::finalize

