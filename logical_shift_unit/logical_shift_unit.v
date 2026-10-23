// 16-bit Logical Shift Unit (barrel shifter)
// dir = 0 : logical shift left  (zeros fill from LSB)
// dir = 1 : logical shift right (zeros fill from MSB)
// shamt   : shift amount, 0..15
module logical_shift_unit (
    input  wire [15:0] data_in,
    input  wire [3:0]  shamt,
    input  wire        dir,
    output wire [15:0] data_out
);

    wire [15:0] s0, s1, s2, s3;

    // Stage 0: shift by 1
    assign s0 = shamt[0] ? (dir ? {1'b0,  data_in[15:1]} : {data_in[14:0], 1'b0})  : data_in;
    // Stage 1: shift by 2
    assign s1 = shamt[1] ? (dir ? {2'b0,  s0[15:2]}      : {s0[13:0], 2'b0})       : s0;
    // Stage 2: shift by 4
    assign s2 = shamt[2] ? (dir ? {4'b0,  s1[15:4]}      : {s1[11:0], 4'b0})       : s1;
    // Stage 3: shift by 8
    assign s3 = shamt[3] ? (dir ? {8'b0,  s2[15:8]}      : {s2[7:0],  8'b0})       : s2;

    assign data_out = s3;

endmodule
