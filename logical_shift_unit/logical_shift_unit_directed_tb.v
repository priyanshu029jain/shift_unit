`timescale 1ns/1ps

// Directed test: sweeps every shift amount in both directions on a fixed
// input and prints the results. Intended for viewing in GTKWave.
module logical_shift_unit_directed_tb;

    reg  [15:0] data_in;
    reg  [3:0]  shamt;
    reg         dir;
    wire [15:0] data_out;

    integer     i;

    logical_shift_unit dut (
        .data_in (data_in),
        .shamt   (shamt),
        .dir     (dir),
        .data_out(data_out)
    );

    initial begin
        $dumpfile("logical_shift_unit_directed_tb.vcd");
        $dumpvars(0, logical_shift_unit_directed_tb);

        data_in = 16'hB3C5;
        for (i = 0; i < 32; i = i + 1) begin
            dir   = i[4];
            shamt = i[3:0];
            #5;
            $display("data_in=%b dir=%s shamt=%2d -> data_out=%b",
                     data_in, dir ? "R" : "L", shamt, data_out);
        end

        $finish;
    end

endmodule
