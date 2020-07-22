`timescale 1ns / 1ps
/*
 * IO always from read buffer
 * Ports
 * readBufferSelect
 *      0 - N1 is read
 *      1 - N2 is read
 */

module NeuronBufferSwapper #(parameter
        depth = 2,
        A = 7,
        D = (1<<depth),
        W = 16
    )(
        input wire readBufferSelect,

        input wire [W*D-1:0] fromN1,
        input wire [W*D-1:0] fromN2,
        output wire[W*D-1:0] toN1In,
        output wire[W*D-1:0] toN2In,
        
        input wire [A-1:0] readBuffAddress,
        input wire [A-1:0] writeBuffAddress,
        output wire[A-1:0] n1Address,
        output wire[A-1:0] n2Address,

        input wire [W-1:0] nReadIO_In,
        output wire [W-1:0] nReadIO_Out,
        output wire [W-1:0] n1IO_In,
        input wire [W-1:0] n1IO_Out,
        output wire [W-1:0] n2IO_In,
        input wire [W-1:0] n2IO_Out,

        input wire [W*D-1:0] fromPoolUnitOut,
        output wire[W*D-1:0] toConvUnitNBuffIn,
        output wire[W*D-1:0] toConvUnitPartialSum
    );

     assign {n1Address,n2Address} = readBufferSelect?{writeBuffAddress,readBuffAddress}
                                     :{readBuffAddress,writeBuffAddress};
     assign {nReadIO_Out} = readBufferSelect?n2IO_Out:n1IO_Out;
     assign {toConvUnitNBuffIn,toConvUnitPartialSum} = readBufferSelect?{fromN2,fromN1}:{fromN1,fromN2};

     assign n1IO_In = readBufferSelect?{(W){1'b0}}:nReadIO_In;
     assign n2IO_In = readBufferSelect?nReadIO_In:{(W){1'b0}};
     
     assign toN1In = readBufferSelect?fromPoolUnitOut:0;
     assign toN2In = readBufferSelect?0:fromPoolUnitOut;

endmodule
