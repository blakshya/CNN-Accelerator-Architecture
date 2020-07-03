`timescale 1ns / 1ps
// fixed point addition
module NBitAdder #(parameter
        N = 16
    )(
        input [N-1:0] ip1,
        input [N-1:0] ip2,
        output [N-1:0] op
    );
    localparam N_BIT_MIN = {1'b1,{(N-1){1'b0}}};
    localparam N_BIT_MAX = {1'b0,{(N-1){1'b1}}};

    wire [N-1:0] addResult;
    wire carry;
    wire overflow;

    assign {carry,addResult} = ip1+ip2;
    assign overflow = (ip1[N-1] & ip2[N-1] & ~addResult[N-1])  
                        | (~ip1[N-1] & ~ip2[N-1] & addResult[N-1] );

    assign op = overflow ? (ip1[N-1] ? N_BIT_MIN : N_BIT_MAX) : addResult;

endmodule
