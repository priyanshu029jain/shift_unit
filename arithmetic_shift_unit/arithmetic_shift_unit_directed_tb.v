`timescale 1ns/1ps

// Directed test: sweeps every shift amount in both directions on a negative
// (MSB = 1) and a positive (MSB = 0) input and prints the results.
// Intended for viewing in GTKWave.
module arithmetic_shift_unit_directed_tb;

    parameter  WIDTH   = 16;
    localparam SHAMT_W = $clog2(WIDTH);

    // 16'hB3C5 repeated to fill WIDTH bits, with the MSB forced to 1 or 0
    localparam [WIDTH-1:0] PATTERN = {((WIDTH + 15) / 16){16'hB3C5}};
    localparam [WIDTH-1:0] NEG     = {1'b1, PATTERN[WIDTH-2:0]};
    localparam [WIDTH-1:0] POS     = {1'b0, PATTERN[WIDTH-2:0]};

    reg  [WIDTH-1:0]   data_in;
    reg  [SHAMT_W-1:0] shamt;
    reg                dir;
    wire [WIDTH-1:0]   data_out;

    integer            i;

    arithmetic_shift_unit #(.WIDTH(WIDTH)) dut (
        .data_in (data_in),
        .shamt   (shamt),
        .dir     (dir),
        .data_out(data_out)
    );

    initial begin
        $dumpfile("arithmetic_shift_unit_directed_tb.vcd");
        $dumpvars(0, arithmetic_shift_unit_directed_tb);

        for (i = 0; i < (4 << SHAMT_W); i = i + 1) begin
            data_in = ((i >> (SHAMT_W + 1)) & 1) ? POS : NEG;
            dir     = (i >> SHAMT_W) & 1;
            shamt   = i;
            #5;
            $display("data_in=%b dir=%s shamt=%2d -> data_out=%b",
                     data_in, dir ? "R" : "L", shamt, data_out);
        end

        $finish;
    end

endmodule
