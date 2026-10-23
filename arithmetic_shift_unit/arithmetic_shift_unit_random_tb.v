`timescale 1ns/1ps

// Random self-checking test: compares the DUT against Verilog's << and >>>
// on random inputs and reports any mismatch.
module arithmetic_shift_unit_random_tb;

    parameter  WIDTH     = 16;
    parameter  NUM_TESTS = 1000;
    localparam SHAMT_W   = $clog2(WIDTH);

    reg  [WIDTH-1:0]   data_in;
    reg  [SHAMT_W-1:0] shamt;
    reg                dir;
    wire [WIDTH-1:0]   data_out;

    reg  [WIDTH-1:0]   expected;
    integer            i, j, errors;

    arithmetic_shift_unit #(.WIDTH(WIDTH)) dut (
        .data_in (data_in),
        .shamt   (shamt),
        .dir     (dir),
        .data_out(data_out)
    );

    initial begin
        $dumpfile("arithmetic_shift_unit_random_tb.vcd");
        $dumpvars(0, arithmetic_shift_unit_random_tb);

        errors = 0;

        for (i = 0; i < NUM_TESTS; i = i + 1) begin
            // $random is 32 bits, so build wider values 32 bits at a time
            for (j = 0; j < WIDTH; j = j + 32)
                data_in = (data_in << 32) | $random;
            shamt   = $random;
            dir     = $random;
            #5;
            // Kept as separate statements: inside a ?: with an unsigned
            // branch, >>> would be evaluated as an unsigned (logical) shift.
            if (dir) expected = $signed(data_in) >>> shamt;
            else     expected = data_in << shamt;
            if (data_out !== expected) begin
                errors = errors + 1;
                $display("MISMATCH: data_in=%h dir=%b shamt=%0d got=%h exp=%h",
                         data_in, dir, shamt, data_out, expected);
            end
        end

        if (errors == 0) $display("ALL %0d TESTS PASSED (WIDTH=%0d)", NUM_TESTS, WIDTH);
        else             $display("%0d OF %0d TESTS FAILED (WIDTH=%0d)", errors, NUM_TESTS, WIDTH);
        $finish;
    end

endmodule
