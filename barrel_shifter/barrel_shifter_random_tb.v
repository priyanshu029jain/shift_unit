`timescale 1ns/1ps

// Random self-checking test: compares the DUT against behavioral logical,
// arithmetic and rotate shifts on random inputs and reports any mismatch.
module barrel_shifter_random_tb;

    localparam NUM_TESTS = 1000;

    reg  [15:0] data_in;
    reg  [3:0]  shamt;
    reg         dir;
    reg  [1:0]  mode;
    wire [15:0] data_out;

    reg  [15:0] expected;
    integer     i, errors;

    barrel_shifter dut (
        .data_in (data_in),
        .shamt   (shamt),
        .dir     (dir),
        .mode    (mode),
        .data_out(data_out)
    );

    initial begin
        $dumpfile("barrel_shifter_random_tb.vcd");
        $dumpvars(0, barrel_shifter_random_tb);

        errors = 0;

        for (i = 0; i < NUM_TESTS; i = i + 1) begin
            data_in = $random;
            shamt   = $random;
            dir     = $random;
            mode    = $random;
            #5;
            // Kept as separate statements: inside a ?: with an unsigned
            // branch, >>> would be evaluated as an unsigned (logical) shift.
            if (mode[1]) begin
                if (dir) expected = (data_in >> shamt) | (data_in << (16 - shamt));
                else     expected = (data_in << shamt) | (data_in >> (16 - shamt));
            end else if (mode[0] && dir) begin
                expected = $signed(data_in) >>> shamt;
            end else begin
                expected = dir ? (data_in >> shamt) : (data_in << shamt);
            end
            if (data_out !== expected) begin
                errors = errors + 1;
                $display("MISMATCH: data_in=%h mode=%b dir=%b shamt=%d got=%h exp=%h",
                         data_in, mode, dir, shamt, data_out, expected);
            end
        end

        if (errors == 0) $display("ALL %0d TESTS PASSED", NUM_TESTS);
        else             $display("%0d OF %0d TESTS FAILED", errors, NUM_TESTS);
        $finish;
    end

endmodule
