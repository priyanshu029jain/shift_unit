`timescale 1ns/1ps

// Directed test: sweeps every shift amount in both directions on a fixed
// input and prints the results. Intended for viewing in GTKWave.
module logical_shift_unit_directed_tb;

    parameter  WIDTH   = 16;
    localparam SHAMT_W = $clog2(WIDTH);

    // 16'hB3C5 repeated to fill WIDTH bits
    localparam [WIDTH-1:0] PATTERN = {((WIDTH + 15) / 16){16'hB3C5}};

    reg  [WIDTH-1:0]   data_in;
    reg  [SHAMT_W-1:0] shamt;
    reg                dir;
    wire [WIDTH-1:0]   data_out;

    integer            i;

    logical_shift_unit #(.WIDTH(WIDTH)) dut (
        .data_in (data_in),
        .shamt   (shamt),
        .dir     (dir),
        .data_out(data_out)
    );

    initial begin
        $dumpfile("logical_shift_unit_directed_tb.vcd");
        $dumpvars(0, logical_shift_unit_directed_tb);

        data_in = PATTERN;
        for (i = 0; i < (2 << SHAMT_W); i = i + 1) begin
            dir   = (i >> SHAMT_W) & 1;
            shamt = i;
            #5;
            $display("data_in=%b dir=%s shamt=%2d -> data_out=%b",
                     data_in, dir ? "R" : "L", shamt, data_out);
        end

        $finish;
    end

endmodule
