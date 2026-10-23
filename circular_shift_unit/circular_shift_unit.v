// Parameterized Circular Shift Unit (barrel rotator)
// dir = 0 : rotate left  (bits leaving the MSB re-enter at the LSB)
// dir = 1 : rotate right (bits leaving the LSB re-enter at the MSB)
// shamt   : rotate amount, 0..2**SHAMT_W-1 (rotates by shamt mod WIDTH)
// WIDTH   : data width, >= 2
module circular_shift_unit #(
    parameter WIDTH   = 16,
    parameter SHAMT_W = $clog2(WIDTH)
) (
    input  wire [WIDTH-1:0]   data_in,
    input  wire [SHAMT_W-1:0] shamt,
    input  wire               dir,
    output wire [WIDTH-1:0]   data_out
);

    // chain[k*WIDTH +: WIDTH] is the input to stage k
    wire [WIDTH*(SHAMT_W+1)-1:0] chain;
    assign chain[WIDTH-1:0] = data_in;

    genvar k;
    generate
        for (k = 0; k < SHAMT_W; k = k + 1) begin : stage
            localparam N = 1 << k;  // stage k rotates by 2**k

            wire [WIDTH-1:0] in = chain[k*WIDTH +: WIDTH];
            wire [WIDTH-1:0] out;

            assign out = shamt[k] ? (dir ? {in[N-1:0],       in[WIDTH-1:N]}
                                         : {in[WIDTH-N-1:0], in[WIDTH-1:WIDTH-N]}) : in;

            assign chain[(k+1)*WIDTH +: WIDTH] = out;
        end
    endgenerate

    assign data_out = chain[SHAMT_W*WIDTH +: WIDTH];

endmodule
