`timescale 1ns/1ps

// Random self-checking test: compares the DUT against behavioral logical,
// arithmetic and rotate shifts on random inputs and reports any mismatch.
module barrel_shifter_random_tb;

    parameter  WIDTH     = 16;
    parameter  NUM_TESTS = 1000;
    localparam SHAMT_W   = $clog2(WIDTH);

    reg  [WIDTH-1:0]   data_in;
    reg  [SHAMT_W-1:0] shamt;
    reg                dir;
    reg  [1:0]         mode;
    wire [WIDTH-1:0]   data_out;

    reg  [WIDTH-1:0]   expected;
    integer            i, j, n, errors;

    barrel_shifter #(.WIDTH(WIDTH)) dut (
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
            // $random is 32 bits, so build wider values 32 bits at a time
            for (j = 0; j < WIDTH; j = j + 32)
                data_in = (data_in << 32) | $random;
            shamt   = $random;
            dir     = $random;
            mode    = $random;
            #5;
            // Kept as separate statements: inside a ?: with an unsigned
            // branch, >>> would be evaluated as an unsigned (logical) shift.
            if (mode[1]) begin
                n = shamt % WIDTH;  // only differs from shamt when WIDTH is not a power of 2
                if (dir) expected = (data_in >> n) | (data_in << (WIDTH - n));
                else     expected = (data_in << n) | (data_in >> (WIDTH - n));
            end else if (mode[0] && dir) begin
                expected = $signed(data_in) >>> shamt;
            end else begin
                expected = dir ? (data_in >> shamt) : (data_in << shamt);
            end
            if (data_out !== expected) begin
                errors = errors + 1;
                $display("MISMATCH: data_in=%h mode=%b dir=%b shamt=%0d got=%h exp=%h",
                         data_in, mode, dir, shamt, data_out, expected);
            end
        end

        if (errors == 0) $display("ALL %0d TESTS PASSED (WIDTH=%0d)", NUM_TESTS, WIDTH);
        else             $display("%0d OF %0d TESTS FAILED (WIDTH=%0d)", errors, NUM_TESTS, WIDTH);
        $finish;
    end

endmodule
