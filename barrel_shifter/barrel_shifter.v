// 16-bit Barrel Shifter (logical / arithmetic / rotate)
// mode = 2'b00 : logical    (zeros fill)
// mode = 2'b01 : arithmetic (right shift fills with sign bit, left fills zeros)
// mode = 2'b10 : rotate     (bits leaving one end re-enter at the other)
// mode = 2'b11 : rotate     (mode[1] alone selects rotate)
// dir  = 0 : left, 1 : right
// shamt    : shift amount, 0..15
module barrel_shifter (
    input  wire [15:0] data_in,
    input  wire [3:0]  shamt,
    input  wire        dir,
    input  wire [1:0]  mode,
    output wire [15:0] data_out
);

    wire        rot  = mode[1];
    wire        sign = data_in[15] & mode[0] & ~mode[1];
    wire [15:0] s0, s1, s2, s3;

    // Stage 0: shift by 1
    assign s0 = shamt[0] ? (dir ? {(rot ? data_in[0]   : {1{sign}}), data_in[15:1]}
                                : {data_in[14:0], (rot ? data_in[15]    : 1'b0)})  : data_in;
    // Stage 1: shift by 2
    assign s1 = shamt[1] ? (dir ? {(rot ? s0[1:0]      : {2{sign}}), s0[15:2]}
                                : {s0[13:0],      (rot ? s0[15:14]      : 2'b0)})  : s0;
    // Stage 2: shift by 4
    assign s2 = shamt[2] ? (dir ? {(rot ? s1[3:0]      : {4{sign}}), s1[15:4]}
                                : {s1[11:0],      (rot ? s1[15:12]      : 4'b0)})  : s1;
    // Stage 3: shift by 8
    assign s3 = shamt[3] ? (dir ? {(rot ? s2[7:0]      : {8{sign}}), s2[15:8]}
                                : {s2[7:0],       (rot ? s2[15:8]       : 8'b0)})  : s2;

    assign data_out = s3;

endmodule
