`timescale 1ns/1ps

module arithmetic_shift_unit_tb;

    reg  [15:0] data_in;
    reg  [3:0]  shamt;
    reg         dir;
    wire [15:0] data_out;

    reg  [15:0] expected;
    integer     i, errors;

    arithmetic_shift_unit dut (
        .data_in (data_in),
        .shamt   (shamt),
        .dir     (dir),
        .data_out(data_out)
    );

    initial begin
        $dumpfile("arithmetic_shift_unit_tb.vcd");
        $dumpvars(0, arithmetic_shift_unit_tb);

        errors = 0;

        // A few readable examples: negative (MSB = 1) then positive (MSB = 0)
        for (i = 0; i < 64; i = i + 1) begin
            data_in = i[5] ? 16'h33C5 : 16'hB3C5;
            dir     = i[4];
            shamt   = i[3:0];
            #5;
            $display("data_in=%b dir=%s shamt=%2d -> data_out=%b",
                     data_in, dir ? "R" : "L", shamt, data_out);
        end

        // Randomized self-check against behavioral shift
        for (i = 0; i < 1000; i = i + 1) begin
            data_in = $random;
            shamt   = $random;
            dir     = $random;
            #5;
            // Kept as separate statements: inside a ?: with an unsigned
            // branch, >>> would be evaluated as an unsigned (logical) shift.
            if (dir) expected = $signed(data_in) >>> shamt;
            else     expected = data_in << shamt;
            if (data_out !== expected) begin
                errors = errors + 1;
                $display("MISMATCH: data_in=%h dir=%b shamt=%d got=%h exp=%h",
                         data_in, dir, shamt, data_out, expected);
            end
        end

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TESTS FAILED", errors);
        $finish;
    end

endmodule
