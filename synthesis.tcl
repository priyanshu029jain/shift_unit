# Synthesize the shift units to the SkyWater sky130_fd_sc_hd standard-cell library.
#
# Usage (from any folder):
#   yosys -q -c synthesis.tcl                          all modules, WIDTH = 16
#   yosys -q -c synthesis.tcl -- barrel_shifter        one module
#   yosys -q -c synthesis.tcl -- barrel_shifter 32     one module, WIDTH = 32
#   yosys -q -c synthesis.tcl -- all 8                 all modules, WIDTH = 8
#
# The liberty file defaults to ../../pdks/sky130/sky130.lib relative to this
# script. Set the SKY130_LIB environment variable to use a different one.
#
# Outputs, per module, in <module>/synth/:
#   <module>_<WIDTH>bit_netlist.v   gate-level netlist
#   <module>_<WIDTH>bit_stat.rpt    cell usage and area report
#
# Each netlist is then formally checked against its RTL (SAT-based
# equivalence over all inputs) and the result shown in the summary.

set root    [file dirname [file normalize [info script]]]
set modules {logical_shift_unit circular_shift_unit arithmetic_shift_unit barrel_shifter}

if {[info exists ::env(SKY130_LIB)]} {
    set lib [file normalize $::env(SKY130_LIB)]
} else {
    set lib [file normalize [file join $root .. .. pdks sky130 sky130.lib]]
}

proc usage {msg} {
    global modules
    puts "Error: $msg"
    puts "Usage: yosys -q -c synthesis.tcl \[-- <module|all> \[WIDTH\]\]"
    puts "Modules: [join $modules {, }]"
    exit 1
}

# ---- Arguments ---------------------------------------------------------------

if {$argc > 2} { usage "too many arguments" }

set target [expr {$argc >= 1 ? [string trimright [lindex $argv 0] /] : "all"}]
set width  [expr {$argc >= 2 ? [lindex $argv 1] : 16}]

if {$target eq "all"} {
    set targets $modules
} elseif {$target in $modules} {
    set targets [list $target]
} else {
    usage "unknown module '$target'"
}

if {![string is integer -strict $width] || $width < 2} {
    usage "WIDTH must be a number >= 2 (got '$width')"
}

if {![file exists $lib]} {
    usage "liberty file not found: $lib (set SKY130_LIB to its path)"
}

# ---- Synthesis ---------------------------------------------------------------

set summary {}

# Yosys keeps some internal numbering across "design -reset", and ABC's result
# depends on it, so a module synthesized after others in the same session can
# come out differently than when synthesized alone. To get the same netlist
# either way, several modules are each run in a fresh Yosys process.
if {[llength $targets] > 1} {
    set yosys_exe [info nameofexecutable]
    if {$yosys_exe eq ""} { set yosys_exe yosys }
    foreach m $targets {
        # A non-zero exit (failed equivalence) still prints the summary row
        catch {exec $yosys_exe -q -c [file join $root synthesis.tcl] -- $m $width 2>@1} out
        if {![regexp -line "^$m\\s+(\\d+)\\s+(\\S+)\\s+(\\S+)" $out -> cells area equiv]} {
            puts $out
            exit 1
        }
        lappend summary [list $m $cells $area $equiv]
    }
    set targets {}
}

foreach m $targets {
    set out_dir  [file join $root $m synth]
    set base     [file join $out_dir "${m}_${width}bit"]
    file mkdir $out_dir

    yosys design -reset

    # Standard cells as black boxes, so later passes know their pins and area
    yosys read_liberty -lib $lib

    yosys read_verilog [file join $root $m $m.v]
    yosys hierarchy -check -top $m -chparam WIDTH $width

    # Generic synthesis, flattened into a single module
    yosys synth -top $m -flatten

    # Map to sky130 cells. The designs are purely combinational, so dfflibmap
    # has nothing to do; it is kept so the flow also works for sequential logic.
    yosys dfflibmap -liberty $lib
    yosys abc -liberty $lib

    # Drive any remaining constants from tie cells, then tidy up
    yosys hilomap -singleton -hicell sky130_fd_sc_hd__conb_1 HI -locell sky130_fd_sc_hd__conb_1 LO
    yosys opt_clean -purge
    yosys check -assert

    yosys tee -q -o "${base}_stat.rpt" stat -liberty $lib
    yosys write_verilog -noattr "${base}_netlist.v"

    # Pull cell count and area out of the report for the summary
    set fh  [open "${base}_stat.rpt"]
    set rpt [read $fh]
    close $fh
    regexp {Number of cells:\s+(\d+)} $rpt -> cells
    regexp {Chip area for module[^:]*:\s+([\d.]+)} $rpt -> area

    # ---- Equivalence check: prove the netlist matches the RTL for all inputs
    # The liberty file is read again without -lib, so each cell gets a logic
    # model built from its "function" attribute.
    yosys design -reset
    yosys read_verilog [file join $root $m $m.v]
    yosys chparam -set WIDTH $width $m
    yosys rename $m gold
    yosys read_liberty -ignore_miss_func -ignore_miss_dir $lib
    yosys read_verilog "${base}_netlist.v"
    yosys rename $m gate
    yosys proc
    yosys miter -equiv -flatten -make_assert gold gate miter
    yosys hierarchy -top miter
    # Without -verify, a failed proof is reported instead of aborting Yosys,
    # so the remaining modules still run. The proof ends with "SUCCESS!" or "FAIL!".
    set sat_log "${base}_equiv.log"
    yosys tee -q -o $sat_log sat -prove-asserts miter
    set fh  [open $sat_log]
    set equiv [expr {[string match "*SUCCESS!*" [read $fh]] ? "PASS" : "FAIL"}]
    close $fh
    file delete $sat_log

    lappend summary [list $m $cells $area $equiv]
}

# ---- Summary -----------------------------------------------------------------

puts ""
puts "sky130_fd_sc_hd synthesis, WIDTH = $width"
puts "Library: $lib"
puts ""
puts [format "%-24s %8s %14s %12s" "Module" "Cells" "Area (um^2)" "Equivalence"]
puts [string repeat - 61]
set failed 0
foreach row $summary {
    lassign $row m cells area equiv
    puts [format "%-24s %8d %14.2f %12s" $m $cells $area $equiv]
    if {$equiv ne "PASS"} { incr failed }
}
puts ""
puts "Netlists and reports: <module>/synth/"

if {$failed} {
    puts "Error: $failed netlist(s) are not equivalent to their RTL"
    exit 1
}
