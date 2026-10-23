`timescale 1ns/1ps

// Directed test: sweeps every shift amount in both directions on a negative
// (MSB = 1) and a positive (MSB = 0) input and prints the results.
// Intended for viewing in GTKWave.
module arithmetic_shift_unit_directed_tb;

    reg  [15:0] data_in;
    reg  [3:0]  shamt;
    reg         dir;
    wire [15:0] data_out;

    integer     i;

    arithmetic_shift_unit dut (
        .data_in (data_in),
        .shamt   (shamt),
        .dir     (dir),
        .data_out(data_out)
    );

    initial begin
        $dumpfile("arithmetic_shift_unit_directed_tb.vcd");
        $dumpvars(0, arithmetic_shift_unit_directed_tb);

        for (i = 0; i < 64; i = i + 1) begin
            data_in = i[5] ? 16'h33C5 : 16'hB3C5;
            dir     = i[4];
            shamt   = i[3:0];
            #5;
            $display("data_in=%b dir=%s shamt=%2d -> data_out=%b",
                     data_in, dir ? "R" : "L", shamt, data_out);
        end

        $finish;
    end

endmodule
