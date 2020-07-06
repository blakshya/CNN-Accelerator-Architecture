`timescale 1ns / 1ps

module NeuronBufferSwapper #(parameter
        depth = 2,
        A = 7,
        D = (1<<depth),
        W = 16
    )(
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

    /*
     * Currently Empty
     * Someone pls help
     */

endmodule