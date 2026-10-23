// Parameterized Arithmetic Shift Unit (barrel shifter)
// dir = 0 : arithmetic shift left  (zeros fill from LSB, same as logical left)
// dir = 1 : arithmetic shift right (sign bit data_in[WIDTH-1] fills from MSB)
// shamt   : shift amount, 0..2**SHAMT_W-1
// WIDTH   : data width, >= 2
module arithmetic_shift_unit #(
    parameter WIDTH   = 16,
    parameter SHAMT_W = $clog2(WIDTH)
) (
    input  wire [WIDTH-1:0]   data_in,
    input  wire [SHAMT_W-1:0] shamt,
    input  wire               dir,
    output wire [WIDTH-1:0]   data_out
);

    wire sign = data_in[WIDTH-1];

    // chain[k*WIDTH +: WIDTH] is the input to stage k
    wire [WIDTH*(SHAMT_W+1)-1:0] chain;
    assign chain[WIDTH-1:0] = data_in;

    genvar k;
    generate
        for (k = 0; k < SHAMT_W; k = k + 1) begin : stage
            localparam N = 1 << k;  // stage k shifts by 2**k

            wire [WIDTH-1:0] in = chain[k*WIDTH +: WIDTH];
            wire [WIDTH-1:0] out;

            assign out = shamt[k] ? (dir ? {{N{sign}}, in[WIDTH-1:N]}
                                         : {in[WIDTH-N-1:0], {N{1'b0}}}) : in;

            assign chain[(k+1)*WIDTH +: WIDTH] = out;
        end
    endgenerate

    assign data_out = chain[SHAMT_W*WIDTH +: WIDTH];

endmodule
