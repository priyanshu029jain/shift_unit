`timescale 1ns/1ps

// Random self-checking test: compares the DUT against Verilog's << and >>
// on random inputs and reports any mismatch.
module logical_shift_unit_random_tb;

    localparam NUM_TESTS = 1000;

    reg  [15:0] data_in;
    reg  [3:0]  shamt;
    reg         dir;
    wire [15:0] data_out;

    reg  [15:0] expected;
    integer     i, errors;

    logical_shift_unit dut (
        .data_in (data_in),
        .shamt   (shamt),
        .dir     (dir),
        .data_out(data_out)
    );

    initial begin
        $dumpfile("logical_shift_unit_random_tb.vcd");
        $dumpvars(0, logical_shift_unit_random_tb);

        errors = 0;

        for (i = 0; i < NUM_TESTS; i = i + 1) begin
            data_in = $random;
            shamt   = $random;
            dir     = $random;
            #5;
            expected = dir ? (data_in >> shamt) : (data_in << shamt);
            if (data_out !== expected) begin
                errors = errors + 1;
                $display("MISMATCH: data_in=%h dir=%b shamt=%d got=%h exp=%h",
                         data_in, dir, shamt, data_out, expected);
            end
        end

        if (errors == 0) $display("ALL %0d TESTS PASSED", NUM_TESTS);
        else             $display("%0d OF %0d TESTS FAILED", errors, NUM_TESTS);
        $finish;
    end

endmodule
