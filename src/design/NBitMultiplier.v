`timescale 1ns / 1ps
// fixed point multiplication
module NBitMultiplier #(parameter
        N = 16
    )(
        input [N-1:0] ip1,
        input [N-1:0] ip2,
        output [N-1:0] op
    );
    localparam FP_LOC = (5); // Location of fixed point from right
    localparam N_BIT_MIN = {1'b1,{(N-1){1'b0}}};
    localparam N_BIT_MAX = {1'b0,{(N-1){1'b1}}};

    wire [N-1:0] multiplyResult;
    wire signed [N-1:0] i1 = ip1;
    wire signed [N-1:0] i2 = ip2;
    wire signed [2*N-1:0] mult = i1*i2;
    assign multiplyResult = mult[N+FP_LOC-1: FP_LOC];

    wire [N-FP_LOC:0] overflowBits = mult[2*N-1:N+FP_LOC-1];
    /*
     * The multiplication is within the range iff 
     * overflow bits is all 0(s) or all 1(s).
     */
    wire isCorrect = |(overflowBits)  ^ &(~overflowBits);

    assign op = isCorrect?multiplyResult:(mult[2*N-1]?N_BIT_MIN:N_BIT_MAX);

endmodule
