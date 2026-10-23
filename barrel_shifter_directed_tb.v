`timescale 1ns/1ps

// Directed test: for each mode (logical, arithmetic, rotate), sweeps every
// shift amount in both directions on a fixed negative input and prints the
// results. Intended for viewing in GTKWave.
module barrel_shifter_directed_tb;

    reg  [15:0] data_in;
    reg  [3:0]  shamt;
    reg         dir;
    reg  [1:0]  mode;
    wire [15:0] data_out;

    integer     m, i;

    barrel_shifter dut (
        .data_in (data_in),
        .shamt   (shamt),
        .dir     (dir),
        .mode    (mode),
        .data_out(data_out)
    );

    initial begin
        $dumpfile("barrel_shifter_directed_tb.vcd");
        $dumpvars(0, barrel_shifter_directed_tb);

        data_in = 16'hB3C5;
        for (m = 0; m < 3; m = m + 1) begin
            for (i = 0; i < 32; i = i + 1) begin
                mode  = m;
                dir   = i[4];
                shamt = i[3:0];
                #5;
                $display("mode=%s data_in=%b dir=%s shamt=%2d -> data_out=%b",
                         mode == 2'b00 ? "LOG" : mode == 2'b01 ? "ARI" : "ROT",
                         data_in, dir ? "R" : "L", shamt, data_out);
            end
        end

        $finish;
    end

endmodule
