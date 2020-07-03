`timescale 1ns / 1ps
/*
 * Module for Kernel Buffer
 * a wrapper on BufferMemory
 * 
 */
/*
 * Parameters
 *  depth = log(size of convolutional unit)
 *  A = address length for the SRAM
 *  W = Data width
 *
 * 
 */
module KernelBuffer #(parameter
        depth = 2,
        A = 7, // Address width
        D = (1<<depth), // size of Convolutional Unit
        W = 16
    )(
        input wire [W*D-1:0] ip,
        output wire [W*D-1:0] op,
        input wire [A-1:0] address,

        input wire [W-1+depth+2 :0] ioInputs,
        output wire [W-1:0] ioOutputs,
        input wire CLK
    );
    wire ioSelect;
    wire ioWrite;
    wire [depth-1:0] ioBankSelect;
    wire [W-1:0] ioInput;

    assign ioInput = ioInputs[W-1:0];//W
    assign ioBankSelect = ioInputs[W+depth-1 -:depth];
    assign ioWrite = ioInputs[W+depth];
    assign ioSelect = ioInputs[W+depth+1];

    BufferMemory #(.depth(depth),.A(A),.W(W))  buffermemory(
        .ip(ip),
        .op(op),
        .address(address),
        .ioSelect(ioSelect),
        .ioWrite(ioWrite),
        .ioBankSelect(ioBankSelect),
        .ioInput(ioInput),
        .ioOut(ioOutputs),
        .CLK(CLK)
    );
endmodule
