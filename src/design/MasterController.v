`timescale 1ns / 1ps

module MasterController #(parameter
        depth = 2,
        D = (1<<depth),
        ABuffer = 11,
        W = 16
    )(
        input wire [W-1:0] dataIn,
        input wire [1:0] instruction,
        output wire [W-1:0]dataOut,

        output wire [W-1:0] kBuffIn,
        output wire [ABuffer-1:0] kBuffAddress,
        output wire [2*depth-1:0] kernelDistControl,

        output wire [ABuffer-1:0] nReadAddress,
        output wire [ABuffer-1:0] nWriteAddress,

        output wire [W-1:0] nReadIO_In,
        output wire [W-1:0] nReadIO_Out,

        output wire [1:0] convUnitControl,
        output wire [1:0] poolUnitControl
    );

    /*
     * Currently Empty
     * Someone pls help
     */
     
endmodule
