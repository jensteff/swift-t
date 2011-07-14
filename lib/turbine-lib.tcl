
# User function
proc turbine_init { } {
    turbine_c_init

    turbine_argv_init
}

proc turbine_argv_init { } {

    global argv
    global turbine_null
    global turbine_argc
    global turbine_argv

    set turbine_null 0
    set turbine_argc 0
    set turbine_argv [ dict create ]
    foreach arg $argv {
        set tokens [ split $arg = ]
        set key [ lindex $tokens 0 ]
        if { [ string index $key 0 ] == "-" } {
            set key [ string range $key 1 end ]
        }
        if { [ string index $key 0 ] == "-" } {
            set key [ string range $key 1 end ]
        }
        set value [ lindex $tokens 1 ]
        set v [ turbine_new ]
        turbine_string $v
        turbine_string_set $v $value
        dict set turbine_argv $key $value
        turbine_debug "argv: $key=<$v>=$value"
        incr turbine_argc
    }
}

# User function
# usage: argv_get <result> <optional:default> <key>
proc turbine_argv_get { args } {

    set result [ lindex $args 0 ]
    set key    [ lindex $args 1 ]
    set base ""
    if { [ llength $args ] == 3 }  {
        set base [ lindex $args 2 ]
    }

    set rule_id [ turbine_new ]
    turbine_rule $rule_id "argv_get-$rule_id" $key $result \
        "tp: turbine_argv_get_body $key $base $result"
}

# usage: argv_get <optional:default> <key> <result>
proc turbine_argv_get_body { args } {

    global turbine_null
    global turbine_argv

    set argc [ llength $args ]
    if { $argc != 2 && $argc != 3 } error

    if { $argc == 2 } {
        set base ""
        set result [ lindex $args 1 ]
    } elseif { $argc == 3 } {
        set base [ lindex $args 1 ]
        set result [ lindex $args 2 ]
    }
    set key [ lindex $args 0 ]

    set t [ turbine_string_get $key ]
    if { [ catch { set v [ dict get $turbine_argv $t ] } ] } {
        turbine_string_set $result ""
        return
    }
    turbine_string_set $result $v
}

# User function
proc turbine_trace { args } {

    set rule_id [ turbine_new ]
    turbine_rule $rule_id "trace-$rule_id" $args { } \
        "tp: turbine_trace_body $args"
}

proc turbine_trace_body { args } {

    puts -nonewline "trace: "
    set n [ llength $args ]
    for { set i 0 } { $i < $n } { incr i } {
        set v [ lindex $args $i ]
        switch [ turbine_typeof $v ] {
            integer {
                set value [ turbine_integer_get $v ]
                puts -nonewline $value
            }
            string {
                set value [ turbine_string_get $v ]
                puts -nonewline $value
            }
        }
        if { $i < $n-1 } { puts -nonewline "," }
    }
    puts ""
}

# User function
proc turbine_range { result start end } {

    set rule_id [ turbine_new ]
    turbine_rule $rule_id "range-$rule_id" "$start $end" $result \
        "tp: turbine_range_body $result $start $end"
}

proc turbine_range_body { result start end } {

    set start_value [ turbine_integer_get $start ]
    set end_value   [ turbine_integer_get $end ]

    set k 0
    for { set i $start } { $i <= $end_value } { incr i } {
        set td [ turbine_new ]
        turbine_integer $td
        turbine_integer_set $td $i
        turbine_insert $result key $k $td
        incr k
    }
}

# User function
proc turbine_enumerate { result container } {

    set rule_id [ turbine_new ]
    turbine_rule $rule_id "enumerate-$rule_id" $container $result \
        "tp: turbine_enumerate_body $result $container"
}

proc turbine_enumerate_body { result container } {

    set s [ turbine_container_get $container ]
    turbine_string_set $result $s
}

# User function
proc turbine_readdata { result filename } {

    set rule_id [ turbine_new ]
    turbine_rule $rule_id "read_data-$rule_id" $filename $result  \
        "tp: turbine_readdata_body $result $filename"
}

proc turbine_readdata_body { result filename } {

    set name_value [ turbine_string_get $filename ]
    if { [ catch { set fd [ open $name_value r ] } e ] } {
        error "Could not open file: '$name_value'"
    }

    set i 0
    while { [ gets $fd line ] >= 0 } {
        set s [ turbine_new ]
        turbine_string $s
        turbine_string_set $s $line
        turbine_insert $result key $i $s
        incr i
    }
}

# User function
proc turbine_loop { stmts container } {
    set rule_id [ turbine_new ]
    turbine_rule $rule_id "loop-$rule_id" $container {} \
        "tp: turbine_loop_body $stmts $container"
}

proc turbine_loop_body { stmts container } {
    set L    [ turbine_container_get $container ]
    set type [ turbine_container_typeof $container ]
    puts "container_got: $L"
    foreach subscript $L {
        set td_key [ turbine_literal $type $subscript ]
        # Call user body with subscript as TD
        $stmts $td_key
    }
}

# Utility function to set up a TD
proc turbine_literal { type value } {

    set result [ turbine_new ]
    turbine_$type $result
    turbine_${type}_set $result $value
    return $result
}

# Copy from TD src to TD dest
# src must be closed
# dest must be a new TD but not created or closed
# NOT TESTED
proc turbine_copy { src dest } {

    set type [ turbine_typeof $src ]
    switch $type {
        integer {
            set t [ turbine_integer_get $src ]
            turbine_integer $dest
            turbine_integer_set $dest $t
        }
        string {
            set t [ turbine_string_get $src ]
            turbine_string $dest
            turbine_string_set $dest $t
        }
    }
}

# User function
# usage: strcat <result> <args>*
proc turbine_strcat { args } {

    set result [ lindex $args 0 ]
    set inputs [ lreplace $args 0 0 ]

    set rule_id [ turbine_new ]
    turbine_rule $rule_id "strcat-$rule_id" $inputs $result \
        "tp: turbine_strcat_body $inputs $result"
}

# usage: strcat_body <args>* <result>
proc turbine_strcat_body { args } {

    set result [ lindex $args end ]
    set inputs [ lreplace $args end end ]

    set output [ list ]
    foreach input $inputs {
        set t [ turbine_string_get $input ]
        lappend output $t
    }
    set total [ join $output "" ]
    turbine_string_set $result $total
}

