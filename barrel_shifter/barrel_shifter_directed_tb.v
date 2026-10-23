`timescale 1ns/1ps

// Directed test: for each mode (logical, arithmetic, rotate), sweeps every
// shift amount in both directions on a fixed negative input and prints the
// results. Intended for viewing in GTKWave.
module barrel_shifter_directed_tb;

    parameter  WIDTH   = 16;
    localparam SHAMT_W = $clog2(WIDTH);

    // 16'hB3C5 repeated to fill WIDTH bits, with the MSB forced to 1
    localparam [WIDTH-1:0] PATTERN = {((WIDTH + 15) / 16){16'hB3C5}};
    localparam [WIDTH-1:0] NEG     = {1'b1, PATTERN[WIDTH-2:0]};

    reg  [WIDTH-1:0]   data_in;
    reg  [SHAMT_W-1:0] shamt;
    reg                dir;
    reg  [1:0]         mode;
    wire [WIDTH-1:0]   data_out;

    integer            m, i;

    barrel_shifter #(.WIDTH(WIDTH)) dut (
        .data_in (data_in),
        .shamt   (shamt),
        .dir     (dir),
        .mode    (mode),
        .data_out(data_out)
    );

    initial begin
        $dumpfile("barrel_shifter_directed_tb.vcd");
        $dumpvars(0, barrel_shifter_directed_tb);

        data_in = NEG;
        for (m = 0; m < 3; m = m + 1) begin
            for (i = 0; i < (2 << SHAMT_W); i = i + 1) begin
                mode  = m;
                dir   = (i >> SHAMT_W) & 1;
                shamt = i;
                #5;
                $display("mode=%s data_in=%b dir=%s shamt=%2d -> data_out=%b",
                         mode == 2'b00 ? "LOG" : mode == 2'b01 ? "ARI" : "ROT",
                         data_in, dir ? "R" : "L", shamt, data_out);
            end
        end

        $finish;
    end

endmodule
