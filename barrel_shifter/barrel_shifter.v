// Parameterized Barrel Shifter (logical / arithmetic / rotate)
// mode = 2'b00 : logical    (zeros fill)
// mode = 2'b01 : arithmetic (right shift fills with sign bit, left fills zeros)
// mode = 2'b10 : rotate     (bits leaving one end re-enter at the other)
// mode = 2'b11 : rotate     (mode[1] alone selects rotate)
// dir  = 0 : left, 1 : right
// shamt    : shift amount, 0..2**SHAMT_W-1 (rotate uses shamt mod WIDTH)
// WIDTH    : data width, >= 2
module barrel_shifter #(
    parameter WIDTH   = 16,
    parameter SHAMT_W = $clog2(WIDTH)
) (
    input  wire [WIDTH-1:0]   data_in,
    input  wire [SHAMT_W-1:0] shamt,
    input  wire               dir,
    input  wire [1:0]         mode,
    output wire [WIDTH-1:0]   data_out
);

    wire rot  = mode[1];
    wire sign = data_in[WIDTH-1] & mode[0] & ~mode[1];

    // chain[k*WIDTH +: WIDTH] is the input to stage k
    wire [WIDTH*(SHAMT_W+1)-1:0] chain;
    assign chain[WIDTH-1:0] = data_in;

    genvar k;
    generate
        for (k = 0; k < SHAMT_W; k = k + 1) begin : stage
            localparam N = 1 << k;  // stage k shifts by 2**k

            wire [WIDTH-1:0] in = chain[k*WIDTH +: WIDTH];
            wire [WIDTH-1:0] out;

            assign out = shamt[k] ? (dir ? {(rot ? in[N-1:0]           : {N{sign}}), in[WIDTH-1:N]}
                                         : {in[WIDTH-N-1:0], (rot ? in[WIDTH-1:WIDTH-N] : {N{1'b0}})}) : in;

            assign chain[(k+1)*WIDTH +: WIDTH] = out;
        end
    endgenerate

    assign data_out = chain[SHAMT_W*WIDTH +: WIDTH];

endmodule
