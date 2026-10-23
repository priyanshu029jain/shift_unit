# Shift Unit

Parameterized Verilog shift units. The data width is set by a `WIDTH` parameter, which defaults to 16.

| Module | Folder | Status |
|---|---|---|
| Logical shift unit | [`logical_shift_unit/`](logical_shift_unit/) | Done, with testbenches |
| Circular (rotate) shift unit | [`circular_shift_unit/`](circular_shift_unit/) | Done, with testbenches |
| Arithmetic shift unit | [`arithmetic_shift_unit/`](arithmetic_shift_unit/) | Done, with testbenches |
| Barrel shifter (all three in one) | [`barrel_shifter/`](barrel_shifter/) | Done, with testbenches |

## Repository layout

Each module has its own folder, holding the design, its two testbenches and, where available, a GTKWave screenshot. Every file is named after its folder:

```text
.
├── logical_shift_unit/
│   ├── logical_shift_unit.v               design
│   ├── logical_shift_unit_directed_tb.v   directed testbench
│   ├── logical_shift_unit_random_tb.v     random self-checking testbench
│   ├── logical_shift_unit.png             waveform screenshot
│   ├── synth/                             sky130 netlist and area report
│   ├── sta/                               OpenSTA timing and power reports
│   └── fpga/                              Vivado utilization, timing and power reports
├── circular_shift_unit/
│   ├── circular_shift_unit.v
│   ├── circular_shift_unit_directed_tb.v
│   ├── circular_shift_unit_random_tb.v
│   └── circular_shift_unit.png
├── arithmetic_shift_unit/
│   ├── arithmetic_shift_unit.v
│   ├── arithmetic_shift_unit_directed_tb.v
│   └── arithmetic_shift_unit_random_tb.v
├── barrel_shifter/
│   ├── barrel_shifter.v
│   ├── barrel_shifter_directed_tb.v
│   └── barrel_shifter_random_tb.v
├── simulate.sh                            run a directed testbench and open GTKWave
├── simulate.bat                           same, for Windows PowerShell / cmd
├── random.sh                              run a random testbench and print the pass rate
├── asic.sh                                synthesis + STA, prints area, timing and power
├── synthesis.tcl                          Yosys synthesis to sky130 + equivalence check
├── STA.tcl                                OpenSTA static timing analysis of the netlists
├── fpga.tcl                               Vivado FPGA implementation and reports
├── .gitattributes
├── .gitignore
├── LICENSE
└── README.md
```

## Parameters

Every module takes the same two parameters:

| Parameter | Default | Description |
|---|---|---|
| `WIDTH` | `16` | Data width in bits. Must be at least 2. |
| `SHAMT_W` | `$clog2(WIDTH)` | Width of `shamt`, and the number of shifter stages. Normally left at its default. |

For example, a 32-bit logical shift unit has a 5-bit `shamt`:

```verilog
logical_shift_unit #(.WIDTH(32)) u_shift (
    .data_in (a),
    .shamt   (amount),   // [4:0]
    .dir     (dir),
    .data_out(y)
);
```

`WIDTH` does not have to be a power of 2. If it isn't, `shamt` can hold values of `WIDTH` or more. In that case the logical unit returns 0, the arithmetic unit fills every bit with the sign bit, and rotations wrap around, rotating by `shamt` mod `WIDTH`.

The three single-purpose units have the same ports and the same barrel structure. The only difference is what fills the empty bit positions:

| Unit | Left shift fills with | Right shift fills with |
|---|---|---|
| Logical | `0` | `0` |
| Circular | bits from the MSB end | bits from the LSB end |
| Arithmetic | `0` | the sign bit `data_in[WIDTH-1]` |

The examples in the sections below use the default `WIDTH = 16`, so `shamt` is 4 bits wide.

## Logical shift unit

`logical_shift_unit` shifts a `WIDTH`-bit value left or right. Bits that move out are dropped, and the empty positions are filled with `0`.

### Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `data_in` | input | `WIDTH` | Value to shift |
| `shamt` | input | `SHAMT_W` | Shift amount (0 to 2^`SHAMT_W` − 1) |
| `dir` | input | 1 | `0` = shift left, `1` = shift right |
| `data_out` | output | `WIDTH` | Shifted result |

### Design

The unit is a combinational barrel shifter with `SHAMT_W` stages, built by a `generate` loop. Stage `k` is controlled by `shamt[k]` and either passes its input through or shifts it by 2^k. With the default `WIDTH = 16` there are four stages:

| Stage | Signal | Controlled by | Shift |
|---|---|---|---|
| 0 | `stage[0].out` | `shamt[0]` | 1 |
| 1 | `stage[1].out` | `shamt[1]` | 2 |
| 2 | `stage[2].out` | `shamt[2]` | 4 |
| 3 | `stage[3].out` | `shamt[3]` | 8 |

Any shift amount is a combination of these stages, so every shift goes through the same `SHAMT_W` multiplexer levels. `data_out` is the output of the last stage. Each stage's `in` and `out` wires appear in GTKWave under `dut.stage[k]`.

### Example

With `data_in = 16'hB3C5` (`1011001111000101`):

| `dir` | `shamt` | `data_out` |
|---|---|---|
| 0 (left) | 1 | `0110011110001010` (`16'h678A`) |
| 1 (right) | 12 | `0000000000001011` (`16'h000B`) |

## Circular shift unit

`circular_shift_unit` rotates a `WIDTH`-bit value left or right. No bits are lost: bits that move out of one end come back in at the other end.

### Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `data_in` | input | `WIDTH` | Value to rotate |
| `shamt` | input | `SHAMT_W` | Rotate amount (0 to 2^`SHAMT_W` − 1) |
| `dir` | input | 1 | `0` = rotate left, `1` = rotate right |
| `data_out` | output | `WIDTH` | Rotated result |

### Design

It uses the same stages as the logical unit (stage `k` rotates by 2^k when `shamt[k]` is set). Each stage wraps the bits it moves out around to the other end instead of filling with zeros.

### Example

With `data_in = 16'hB3C5` (`1011001111000101`):

| `dir` | `shamt` | `data_out` |
|---|---|---|
| 0 (left) | 1 | `0110011110001011` (`16'h678B`) |
| 1 (right) | 4 | `0101101100111100` (`16'h5B3C`) |

## Arithmetic shift unit

`arithmetic_shift_unit` shifts a `WIDTH`-bit two's-complement value left or right. A right shift copies the sign bit into the empty positions, so the value keeps its sign and the result equals division by 2ⁿ rounded toward negative infinity. A left shift fills with zeros and is the same as a logical left shift (multiplication by 2ⁿ, without overflow detection).

### Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `data_in` | input | `WIDTH` | Signed value to shift |
| `shamt` | input | `SHAMT_W` | Shift amount (0 to 2^`SHAMT_W` − 1) |
| `dir` | input | 1 | `0` = shift left, `1` = shift right |
| `data_out` | output | `WIDTH` | Shifted result |

### Design

It uses the same stages (stage `k` shifts by 2^k when `shamt[k]` is set). In right shifts, each stage fills the top bits with copies of `data_in[WIDTH-1]`, the original sign bit.

### Example

Right shifts by 4 of a negative and a positive value:

| `data_in` | `dir` | `shamt` | `data_out` |
|---|---|---|---|
| `1011001111000101` (`16'hB3C5`, negative) | 1 (right) | 4 | `1111101100111100` (`16'hFB3C`) |
| `0011001111000101` (`16'h33C5`, positive) | 1 (right) | 4 | `0000001100111100` (`16'h033C`) |

## Barrel shifter

`barrel_shifter` combines the logical, arithmetic and circular units into one module. A 2-bit `mode` input selects the operation, so a datapath needs only one shifter instead of three.

### Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `data_in` | input | `WIDTH` | Value to shift |
| `shamt` | input | `SHAMT_W` | Shift amount (0 to 2^`SHAMT_W` − 1) |
| `dir` | input | 1 | `0` = left, `1` = right |
| `mode` | input | 2 | Operation, see below |
| `data_out` | output | `WIDTH` | Shifted result |

| `mode` | Operation | Left fills with | Right fills with |
|---|---|---|---|
| `2'b00` | Logical | `0` | `0` |
| `2'b01` | Arithmetic | `0` | the sign bit `data_in[WIDTH-1]` |
| `2'b10` | Rotate | bits from the MSB end | bits from the LSB end |
| `2'b11` | Rotate (same as `2'b10`) | bits from the MSB end | bits from the LSB end |

### Design

It uses the same stages (stage `k` shifts by 2^k when `shamt[k]` is set). Each stage chooses its fill bits from `mode`:

- `mode[1] = 1`: the bits shifted out wrap around to the other end (rotate).
- Otherwise, on a right shift, the fill is `data_in[WIDTH-1] & mode[0]`: copies of the sign bit for arithmetic, zeros for logical.
- Otherwise, on a left shift, the fill is zeros.

### Example

With `data_in = 16'hB3C5` (`1011001111000101`) and `shamt = 4`:

| `mode` | `dir` | `data_out` |
|---|---|---|
| Logical | left | `0011110001010000` (`16'h3C50`) |
| Logical | right | `0000101100111100` (`16'h0B3C`) |
| Arithmetic | left | `0011110001010000` (`16'h3C50`) |
| Arithmetic | right | `1111101100111100` (`16'hFB3C`) |
| Rotate | left | `0011110001011011` (`16'h3C5B`) |
| Rotate | right | `0101101100111100` (`16'h5B3C`) |

## Simulation

Requires [Icarus Verilog](https://steveicarus.github.io/iverilog/) and, for waveforms, [GTKWave](https://gtkwave.sourceforge.net/).

### Quick start

`simulate.sh` compiles a module's directed testbench, runs it, and opens the waveform in GTKWave. Run it from the repository root with the module's folder name, and optionally a width:

```sh
./simulate.sh barrel_shifter            # default WIDTH = 16
./simulate.sh logical_shift_unit 8      # 8-bit version
```

To run it as just `simulate` from any folder on Linux, macOS or WSL, link it into a folder on your `PATH`:

```sh
mkdir -p ~/bin && ln -s "$PWD/simulate.sh" ~/bin/simulate   # run from the repo root
simulate barrel_shifter
```

Run it with no arguments to list the available modules. To run the simulation without opening GTKWave, set `NO_WAVE=1`:

```sh
NO_WAVE=1 ./simulate.sh circular_shift_unit
```

On Windows, use `simulate.bat` from PowerShell or Command Prompt. It takes the same arguments. PowerShell only runs scripts from the current folder when they're prefixed with `.\`:

```powershell
.\simulate barrel_shifter
.\simulate logical_shift_unit 8
$env:NO_WAVE = "1"; .\simulate circular_shift_unit   # no GTKWave
```

If `iverilog` comes from [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build), `simulate.bat` runs the suite's `environment.bat` first, because its tools crash without that setup. Git Bash users can run `./simulate.sh` instead.

`random.sh` compiles and runs a module's random self-checking testbench, and prints only the result. It takes the module, an optional width, and an optional number of tests:

```sh
./random.sh barrel_shifter               # 1000/1000 passed (100.00%)
./random.sh logical_shift_unit 32 5000   # WIDTH = 32, 5000 tests
```

It exits with status 0 when every test passes and 1 otherwise, so it can be used in scripts. It can be linked into `~/bin` the same way as `simulate.sh`, as `random`.

The rest of this section shows how to run each step by hand, including the random self-checking testbenches.

Each unit has two testbenches:

| Testbench | Purpose |
|---|---|
| `<module>_directed_tb.v` | Sweeps every value of `shamt` in both directions on a fixed input and prints each result. Use it to read the behavior and to view a clean waveform in GTKWave. |
| `<module>_random_tb.v` | Applies `NUM_TESTS` (default 1000) random inputs and checks each `data_out` against a behavioral model, printing any mismatch and then `ALL 1000 TESTS PASSED (WIDTH=16)` or the failure count. |

The directed testbenches use the input `16'hB3C5`. The arithmetic one also uses the positive value `16'h33C5`, so you can see the sign bit fill with both `1` and `0`. The barrel shifter's directed testbench runs the sweep once for each mode: logical, arithmetic, then rotate.

The random testbenches use these reference models:

| Unit | Left | Right |
|---|---|---|
| Logical | `x << n` | `x >> n` |
| Circular | `(x << n) \| (x >> (16 - n))` | `(x >> n) \| (x << (16 - n))` |
| Arithmetic | `x << n` | `$signed(x) >>> n` |

The barrel shifter's random testbench also randomizes `mode`, including `2'b11`, and checks each result against the model for that mode.

Every testbench writes a `.vcd` file named after itself, which includes each stage's `in` and `out` signals.

Each testbench has a `WIDTH` parameter, default 16, which it passes on to the module under test. The random testbenches also have `NUM_TESTS`, default 1000. At widths other than 16, the directed testbenches repeat the `16'hB3C5` pattern to fill the width. The arithmetic testbench then forces the MSB to 1 for its negative input and to 0 for its positive one. The barrel shifter testbench forces it to 1, so its input is always negative.

To run a testbench, go into the module's folder. In the commands below, replace `<module>` with the folder name: `logical_shift_unit`, `circular_shift_unit`, `arithmetic_shift_unit` or `barrel_shifter`.

```sh
cd <module>
```

Directed test:

```sh
iverilog -o <module>_directed.vvp <module>.v <module>_directed_tb.v
vvp <module>_directed.vvp
gtkwave <module>_directed_tb.vcd
```

Random self-checking test:

```sh
iverilog -o <module>_random.vvp <module>.v <module>_random_tb.v
vvp <module>_random.vvp
```

To test a different width, or to run a different number of random tests, override the testbench parameters with `-P` when compiling. For example, 1000 random tests of a 32-bit barrel shifter:

```sh
cd barrel_shifter
iverilog -P barrel_shifter_random_tb.WIDTH=32 -o barrel_shifter_random.vvp barrel_shifter.v barrel_shifter_random_tb.v
vvp barrel_shifter_random.vvp
```

The same `-P <testbench>.WIDTH=<n>` option works for the directed testbenches, and `-P <testbench>.NUM_TESTS=<n>` sets the number of random tests. All four modules pass their random testbenches at widths 2, 4, 8, 12, 16, 32, 64 and 100.

The `.vvp` and `.vcd` files are written into the module's folder. They are build outputs and are ignored by git.

### Waveforms

Logical shift unit:

![GTKWave output of the logical shift unit testbench](logical_shift_unit/logical_shift_unit.png)

Circular shift unit:

![GTKWave output of the circular shift unit testbench](circular_shift_unit/circular_shift_unit.png)

## ASIC summary

`asic.sh` runs synthesis (`synthesis.tcl`) and then static timing analysis (`STA.tcl`, described below), and prints just the key numbers for each module:

```text
$ ./asic.sh barrel_shifter
ASIC analysis: sky130_fd_sc_hd (tt, 25 C, 1.8 V), WIDTH = 16, clock period = 10 ns

barrel_shifter
  Area         1291.24 um^2  (187 cells)
  Delay        2.359 ns max  (Fmax 423.9 MHz),  0.401 ns min
  Timing       MET  (slack 7.641 ns),  transition OK
  Critical     dir -> data_out[1]
  Power        44.73 uW  (switching 44.73 uW, internal 0.00 uW, leakage 0.0005 uW) at 10 ns
  Equivalence  PASS
```

```sh
./asic.sh all                  # every module
./asic.sh barrel_shifter 32 5  # WIDTH = 32, 5 ns clock period
```

It needs `yosys` and `sta` on the `PATH`, as in WSL or Linux with OSS CAD Suite and OpenSTA installed. It exits with status 1 if any module fails the equivalence check, misses timing, or breaks the max-transition rule. The full netlists and reports are still written to `<module>/synth/` and `<module>/sta/`. Like the other scripts, it can be linked into `~/bin` as `asic`.

## Synthesis

`synthesis.tcl` synthesizes the modules with [Yosys](https://github.com/YosysHQ/yosys) to the SkyWater 130 nm high-density standard-cell library (`sky130_fd_sc_hd`, typical corner: 25 °C, 1.8 V). It then formally proves that each gate-level netlist is equivalent to its RTL.

```sh
yosys -q -c synthesis.tcl                          # all modules, WIDTH = 16
yosys -q -c synthesis.tcl -- barrel_shifter        # one module
yosys -q -c synthesis.tcl -- barrel_shifter 32     # one module, WIDTH = 32
yosys -q -c synthesis.tcl -- all 8                 # all modules, WIDTH = 8
```

Arguments for the script go after `--`. The `-q` flag hides Yosys's detailed log, leaving only the summary and any errors.

### Liberty file

By default the script uses `../../pdks/sky130/sky130.lib`, relative to the script. That is, it expects a `pdks` repository next to the `Architecture` folder:

```text
GitHub/
├── Architecture/Shift_unit/synthesis.tcl
└── pdks/sky130/sky130.lib
```

To use a library somewhere else, set `SKY130_LIB`:

```sh
SKY130_LIB=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib yosys -q -c synthesis.tcl
```

### Flow

For each module the script:

1. Reads the RTL and sets `WIDTH` (`hierarchy -chparam`).
2. Runs generic synthesis and flattens the design (`synth -flatten`).
3. Maps to sky130 cells (`dfflibmap`, `abc -liberty`). The designs are purely combinational, so `dfflibmap` has nothing to map. It is kept so the flow also works for sequential logic.
4. Ties any constant outputs to `sky130_fd_sc_hd__conb_1` cells (`hilomap`), removes unused logic, and checks the netlist for problems (`check -assert`).
5. Writes the netlist and a cell/area report to `<module>/synth/`.
6. Builds a miter of the RTL and the netlist, using cell logic taken from the liberty file's `function` attributes. It then proves with a SAT solver that the two produce the same output for every possible input (`miter -equiv`, `sat -prove-asserts`).

Outputs per module, in `<module>/synth/`:

| File | Contents |
|---|---|
| `<module>_<WIDTH>bit_netlist.v` | Gate-level Verilog netlist of sky130 cells |
| `<module>_<WIDTH>bit_stat.rpt` | Cell counts by type and total area |

The script exits with status 1 if any netlist fails the equivalence check.

When `all` is given, each module is synthesized in its own Yosys process. ABC's mapping depends on internal net numbering, which Yosys doesn't fully reset between designs in one session. Running each module separately means its netlist is identical whether it is synthesized alone or together with the others.

### Results

At the default `WIDTH = 16`:

| Module | Cells | Area (µm²) | Equivalence |
|---|---|---|---|
| `logical_shift_unit` | 134 | 967.18 | Pass |
| `circular_shift_unit` | 128 | 1581.52 | Pass |
| `arithmetic_shift_unit` | 165 | 1126.08 | Pass |
| `barrel_shifter` | 187 | 1291.24 | Pass |

Area is the sum of the cell areas from the liberty file. It does not include routing or placement overhead.

## Static timing analysis

`STA.tcl` runs static timing analysis with [OpenSTA](https://github.com/The-OpenROAD-Project/OpenSTA) on the netlists written by `synthesis.tcl`, so run synthesis first.

```sh
sta -no_splash -exit STA.tcl                                 # all modules, WIDTH = 16
MODULE=barrel_shifter sta -no_splash -exit STA.tcl           # one module
MODULE=all WIDTH=32 PERIOD=5 sta -no_splash -exit STA.tcl    # other width and period
```

OpenSTA doesn't pass command-line arguments to scripts, so the options are environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `MODULE` | `all` | Module to analyze, or `all` |
| `WIDTH` | `16` | Which netlist to analyze. It must already be synthesized at this width. |
| `PERIOD` | `10` | Clock period for the timing constraint, in ns |
| `SKY130_LIB` | `../../pdks/sky130/sky130.lib` | Liberty file, as for `synthesis.tcl` |

### Constraints

The shift units are purely combinational, with no clock and no flip-flops. They are therefore timed against a virtual clock, `vclk`. Every input is launched, and every output captured, on a `vclk` edge with zero external delay. That makes:

- **Max delay** (longest input-to-output path) = `PERIOD` − worst setup slack
- **Min delay** (shortest input-to-output path) = worst hold slack
- **Fmax** = 1 / max delay: the highest clock rate at which the unit could sit between two registers, ignoring register setup time and clock-to-Q delay

The inputs are driven by a `sky130_fd_sc_hd__inv_2` and each output drives 0.033442 pF, the same defaults OpenLane uses for this library. The library is the typical corner only (tt, 25 °C, 1.8 V), and there is no wire parasitics data, because the design isn't placed and routed.

### Output

The script prints a summary table, and writes two reports per module to `<module>/sta/`:

| File | Contents |
|---|---|
| `<module>_<WIDTH>bit_timing.rpt` | Full longest (setup) and shortest (hold) paths, with slew, capacitance and delay at every cell. Also the max-transition design rule check, WNS and TNS. |
| `<module>_<WIDTH>bit_power.rpt` | Internal, switching and leakage power, in W. This is an estimate from OpenSTA's default input switching activity, not from simulation, so treat it as a rough comparison between modules. It scales with the clock rate, so it changes with `PERIOD`. |

Both reports start with the same header listing the library, the constraint, the input drive and the output load.

If a module misses timing at the given `PERIOD`, or breaks the max-transition rule, the summary ends with a warning. OpenSTA always exits with status 0, though, so scripts can't detect a failure from the exit code.

OpenSTA prints `Warning: ... default_operating_condition tt_025C_1v80 not found` when it reads this liberty file. The warning is harmless: the file declares its default operating condition before defining it, and the library is still read correctly.

### Results

At `WIDTH = 16`, `PERIOD = 10` ns:

| Module | Max delay (ns) | Fmax (MHz) | Min delay (ns) | Max transition | Critical path |
|---|---|---|---|---|---|
| `logical_shift_unit` | 2.008 | 497.9 | 0.438 | OK | `shamt[0]` → `data_out[4]` |
| `circular_shift_unit` | 2.192 | 456.2 | 0.484 | OK | `shamt[0]` → `data_out[1]` |
| `arithmetic_shift_unit` | 2.018 | 495.6 | 0.455 | OK | `dir` → `data_out[11]` |
| `barrel_shifter` | 2.359 | 423.9 | 0.401 | OK | `dir` → `data_out[1]` |

All four meet timing at 10 ns with more than 7.6 ns of slack. The critical paths start at `dir` or `shamt`, the control inputs that fan out to every bit. A large share of each path is the input itself charging that fanout: in the barrel shifter, `dir` alone takes 0.50 ns. Another large share is the last gate driving the output load.

## FPGA implementation

`fpga.tcl` implements each module on an AMD FPGA with Vivado, running synthesis, placement and routing. It then writes utilization, timing and power reports. It works from the RTL and does not need the Yosys netlists.

```powershell
vivado -mode batch -nojournal -nolog -notrace -source fpga.tcl                                      # all modules
vivado -mode batch -nojournal -nolog -notrace -source fpga.tcl -tclargs barrel_shifter               # one module
vivado -mode batch -nojournal -nolog -notrace -source fpga.tcl -tclargs all 32 5 xc7z020clg400-1     # width, period, part
```

The arguments after `-tclargs` are all optional, and go in this order:

| Argument | Default | Meaning |
|---|---|---|
| module | `all` | Module to implement, or `all` |
| `WIDTH` | `16` | Data width |
| `PERIOD` | `10` | Clock period constraint, in ns |
| part | `xc7a35tcpg236-1` | Vivado part. The default is the Artix-7 on the Basys 3 board. |

On Windows, if `vivado` isn't on your `PATH`, call it by its full path, for example `C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat`. Vivado creates a `.Xil/` folder in the current directory, which is ignored by git. The run exits with status 1 if any module misses timing.

### How it's measured

The shift units are combinational, so on their own there is no register-to-register path to time. The script therefore wraps each one in a register stage on every input and output, clocked by `clk`:

```text
input registers  ->  shift unit (LUTs + routing)  ->  output registers
```

The worst register-to-register path then measures the shift unit itself, fully placed and routed, and Fmax comes straight from it. The clock also gives the power estimate real switching activity. The wrapper is generated on the fly, and the shift unit is kept as its own hierarchy (`dut`), so its resources can be reported separately from the wrapper's registers.

The design is implemented out of context, with no I/O buffers or pin assignments, because the unit is a block meant to sit inside a larger design. That also means wide versions aren't limited by the package's pin count. `clk` is assumed to come from a global clock buffer, so that clock skew is still estimated. Vivado warns that the top-level ports have no partition pin locations. Those warnings only affect the paths from the ports to the input registers, which are not timed.

### Output

| File (in `<module>/fpga/`) | Contents |
|---|---|
| `<module>_<WIDTH>bit_utilization.rpt` | LUTs, registers, muxes and slices for the whole design, then broken down by hierarchy, with the shift unit as `dut` |
| `<module>_<WIDTH>bit_timing.rpt` | Timing summary (WNS, TNS, WHS, THS) and the 10 worst paths, with logic and routing delay per stage |
| `<module>_<WIDTH>bit_power.rpt` | Vectorless power estimate in mW: device static power, and dynamic power by type and by hierarchy |

### Results

Vivado 2025.2, `xc7a35tcpg236-1` (Artix-7, speed grade −1), `WIDTH = 16`, `PERIOD = 10` ns:

| Module | LUTs | F7/F8 muxes | Path delay (ns) | Logic levels | Fmax (MHz) | Dynamic power (mW) |
|---|---|---|---|---|---|---|
| `logical_shift_unit` | 61 | 16 | 3.567 | 3 | 284.3 | 1.050 |
| `circular_shift_unit` | 56 | 0 | 4.013 | 3 | 246.4 | 1.146 |
| `arithmetic_shift_unit` | 61 | 6 | 4.041 | 3 | 247.6 | 1.085 |
| `barrel_shifter` | 78 | 0 | 5.333 | 4 | 183.4 | 1.330 |

- **Resources:** LUTs and muxes are for the shift unit alone. LUTs are Vivado's "Slice LUTs", which count two small LUTs packed into one LUT6 site once. The wrapper adds 37 flip-flops, or 39 for the barrel shifter, which also has its 2-bit `mode` input.
- **Timing:** path delay is the worst register-to-register delay, including clock-to-Q. About three quarters of it is routing. All four modules meet the 10 ns constraint.
- **Power:** dynamic power is for the whole wrapper, at the default switching activity. Total on-chip power is about 69.5 mW for every module, almost all of it the device's static power.

## License

This project is released under the [MIT License](LICENSE).
