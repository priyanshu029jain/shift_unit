# Static timing analysis of the synthesized shift units with OpenSTA.
#
# Run synthesis.tcl first: this script analyzes the netlists it writes to
# <module>/synth/<module>_<WIDTH>bit_netlist.v.
#
# Usage (from any folder):
#   sta -no_splash -exit STA.tcl                                 all modules
#   MODULE=barrel_shifter sta -no_splash -exit STA.tcl           one module
#   MODULE=all WIDTH=32 PERIOD=5 sta -no_splash -exit STA.tcl    other width / period
#
# OpenSTA does not pass command-line arguments to the script, so options are
# environment variables:
#   MODULE      module name or "all"                 (default: all)
#   WIDTH       which netlist width to analyze       (default: 16)
#   PERIOD      clock period for the constraint, ns  (default: 10)
#   SKY130_LIB  liberty file (default: ../../pdks/sky130/sky130.lib relative to this script)
#
# The designs are purely combinational, so they are timed against a virtual
# clock: every input is launched and every output captured at a clock edge with
# zero external delay. The worst setup slack then gives the longest
# input-to-output delay as PERIOD - slack, and the worst hold slack gives the
# shortest one.
#
# Outputs, per module, in <module>/sta/:
#   <module>_<WIDTH>bit_timing.rpt   setup/hold paths, transition checks, WNS/TNS
#   <module>_<WIDTH>bit_power.rpt    power estimate
#
# Note: OpenSTA runs a script one command at a time, keeps going after errors
# and ignores "exit". Everything therefore lives in procs, and main stops with
# "return" on bad input.

set modules {logical_shift_unit circular_shift_unit arithmetic_shift_unit barrel_shifter}

# Same input drive and output load that OpenLane uses by default for sky130_fd_sc_hd
set lib_name     sky130_fd_sc_hd__tt_025C_1v80
set driving_cell sky130_fd_sc_hd__inv_2
set output_load  0.033442   ;# pF

proc env_or {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}

# Folder holding this script. OpenSTA leaves [info script] empty, but the
# "source <file>" call that is running the script is still on the frame stack.
proc script_dir {} {
    if {[info script] ne ""} { return [file dirname [file normalize [info script]]] }
    for {set i 1} {$i <= [info frame]} {incr i} {
        set cmd [dict get [info frame $i] cmd]
        if {[lindex $cmd 0] eq "source" && [file isfile [lindex $cmd end]]} {
            return [file dirname [file normalize [lindex $cmd end]]]
        }
    }
    return [pwd]
}

proc usage {msg} {
    puts "Error: $msg"
    puts "Usage: \[MODULE=<module|all>\] \[WIDTH=<n>\] \[PERIOD=<ns>\] sta -no_splash -exit STA.tcl"
    puts "Modules: [join $::modules {, }]"
}

proc append_header {rpt title} {
    set fh [open $rpt a]
    puts $fh "\n==================== $title [string repeat = [expr {44 - [string length $title]}]]"
    close $fh
}

# Analysis conditions, written at the top of each report
proc write_conditions {fh period} {
    global lib_name driving_cell output_load
    puts $fh "Library:      $lib_name"
    puts $fh "Constraint:   virtual clock vclk, period $period ns, input/output delay 0"
    puts $fh "Input drive:  $driving_cell"
    puts $fh "Output load:  $output_load pF"
}

# Analyze one module and return its summary row
proc analyze {root m width period} {
    global lib_name driving_cell output_load

    set out_dir [file join $root $m sta]
    set rpt     [file join $out_dir "${m}_${width}bit_timing.rpt"]
    set pwr     [file join $out_dir "${m}_${width}bit_power.rpt"]
    file mkdir $out_dir

    read_verilog [file join $root $m synth "${m}_${width}bit_netlist.v"]
    link_design $m

    create_clock -name vclk -period $period
    set_input_delay  0 -clock vclk [all_inputs]
    set_output_delay 0 -clock vclk [all_outputs]
    set_driving_cell -lib_cell $driving_cell -pin Y [all_inputs]
    set_load $output_load [all_outputs]

    # ---- Timing report
    set fh [open $rpt w]
    puts $fh "Static timing analysis: $m, WIDTH = $width"
    write_conditions $fh $period
    close $fh

    append_header $rpt "Longest path (setup)"
    report_checks -path_delay max -format full_clock_expanded -fields {slew cap input_pin} -digits 3 >> $rpt
    append_header $rpt "Shortest path (hold)"
    report_checks -path_delay min -format full_clock_expanded -fields {slew cap input_pin} -digits 3 >> $rpt
    append_header $rpt "Design rule checks"
    report_check_types -max_transition -verbose -digits 3 >> $rpt
    append_header $rpt "Slack"
    report_wns -digits 3 >> $rpt
    report_tns -digits 3 >> $rpt

    # ---- Power report
    set fh [open $pwr w]
    puts $fh "Power estimate: $m, WIDTH = $width"
    write_conditions $fh $period
    puts $fh "Activity:     OpenSTA default switching activity on the inputs (no simulation data)"
    puts $fh "Units:        W"
    close $fh

    append_header $pwr "Power by group"
    report_power -digits 3 >> $pwr

    # ---- Summary numbers
    set setup_slack [worst_slack -max]
    set hold_slack  [worst_slack -min]
    set max_delay   [expr {$period - $setup_slack}]
    set fmax        [expr {1000.0 / $max_delay}]

    sta::redirect_string_begin
    report_checks -path_delay max -format full
    set path_rpt [sta::redirect_string_end]
    regexp {Startpoint:\s+(\S+)} $path_rpt -> startpoint
    regexp {Endpoint:\s+(\S+)}   $path_rpt -> endpoint

    sta::redirect_string_begin
    report_check_types -max_transition -all_violators
    set drv [expr {[string trim [sta::redirect_string_end]] eq "" ? "OK" : "FAIL"}]

    set status [expr {$setup_slack >= 0 && $hold_slack >= 0 ? "MET" : "VIOLATED"}]

    return [list $m $max_delay $fmax $hold_slack $setup_slack $drv $status "$startpoint -> $endpoint"]
}

proc main {} {
    global modules lib_name driving_cell output_load

    set root   [script_dir]
    set target [string trimright [env_or MODULE all] /]
    set width  [env_or WIDTH 16]
    set period [env_or PERIOD 10]
    set lib    [file normalize [env_or SKY130_LIB [file join $root .. .. pdks sky130 sky130.lib]]]

    # ---- Check options
    if {$target eq "all"} {
        set targets $modules
    } elseif {$target in $modules} {
        set targets [list $target]
    } else {
        usage "unknown module '$target'"; return
    }
    if {![string is integer -strict $width] || $width < 2} {
        usage "WIDTH must be a number >= 2 (got '$width')"; return
    }
    if {![string is double -strict $period] || $period <= 0} {
        usage "PERIOD must be a positive number of ns (got '$period')"; return
    }
    if {![file exists $lib]} {
        usage "liberty file not found: $lib (set SKY130_LIB to its path)"; return
    }
    foreach m $targets {
        set nl [file join $root $m synth "${m}_${width}bit_netlist.v"]
        if {![file exists $nl]} {
            usage "netlist not found: $nl\n       Run first: yosys -q -c synthesis.tcl -- $m $width"; return
        }
    }

    # ---- Analyze
    read_liberty $lib
    set summary {}
    foreach m $targets {
        lappend summary [analyze $root $m $width $period]
    }

    # ---- Summary
    puts ""
    puts "OpenSTA timing, $lib_name, WIDTH = $width, PERIOD = $period ns"
    puts "Input drive $driving_cell, output load $output_load pF"
    puts ""
    puts [format "%-22s %9s %10s %9s %9s %10s %9s  %s" \
            "Module" "Max (ns)" "Fmax (MHz)" "Min (ns)" "Slack" "Slew/DRV" "Timing" "Critical path"]
    puts [string repeat - 112]
    set violated 0
    foreach row $summary {
        lassign $row m max_delay fmax min_delay slack drv status path
        puts [format "%-22s %9.3f %10.1f %9.3f %9.3f %10s %9s  %s" \
                $m $max_delay $fmax $min_delay $slack $drv $status $path]
        if {$status ne "MET" || $drv ne "OK"} { incr violated }
    }
    puts ""
    puts "Max = longest input-to-output delay, Min = shortest, Slack = setup slack at PERIOD."
    puts "Full reports: <module>/sta/"
    if {$violated} {
        puts "WARNING: $violated module(s) have timing or design rule violations"
    }
}

main
