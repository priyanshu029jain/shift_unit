// 16-bit Circular Shift Unit (barrel rotator)
// dir = 0 : rotate left  (bits leaving the MSB re-enter at the LSB)
// dir = 1 : rotate right (bits leaving the LSB re-enter at the MSB)
// shamt   : rotate amount, 0..15
module circular_shift_unit (
    input  wire [15:0] data_in,
    input  wire [3:0]  shamt,
    input  wire        dir,
    output wire [15:0] data_out
);

    wire [15:0] s0, s1, s2, s3;

    // Stage 0: rotate by 1
    assign s0 = shamt[0] ? (dir ? {data_in[0],   data_in[15:1]} : {data_in[14:0], data_in[15]})    : data_in;
    // Stage 1: rotate by 2
    assign s1 = shamt[1] ? (dir ? {s0[1:0],      s0[15:2]}      : {s0[13:0],      s0[15:14]})      : s0;
    // Stage 2: rotate by 4
    assign s2 = shamt[2] ? (dir ? {s1[3:0],      s1[15:4]}      : {s1[11:0],      s1[15:12]})      : s1;
    // Stage 3: rotate by 8
    assign s3 = shamt[3] ? (dir ? {s2[7:0],      s2[15:8]}      : {s2[7:0],       s2[15:8]})       : s2;

    assign data_out = s3;

endmodule
