`timescale 1ns / 1ps
/*
 * Module for creating on-chip buffers
 * number of banks = size of convolutional unit
 * 
 */
/*
 * Parameters
 *  depth = log(size of convolutional unit)
 *  A = address length for the SRAM
 *  W = Data width
 *
 * Ports
 *  IO:
 *      ioSelect - if io is enabled
 *      ioWrite - if io write is enabled
 *      ioBankSelect -  bank number selected for io
 *      ioInput - W-bit input
 *      ioOut - W-bit output
 */
module BufferMemory #(parameter 
        depth = 2,
        A = 7, // Address width
        D = (1<<depth), // size of Convolutional Unit
        W = 16
    )(
        input wire [W*D-1:0] ip,
        output wire [W*D-1:0] op,
        input wire [A-1:0] address,
        input wire write,

        input wire ioSelect,
        input wire [depth-1:0] ioBankSelect,
        input wire [W-1:0]  ioInput,
        output wire [W-1:0] ioOut,
        input wire CLK
    );
    wire [W-1:0] inputs  [D-1:0];
    wire [W-1:0] outputs [D-1:0];

    wire [W-1:0] bankInput [D-1:0];
    wire [W-1:0] bankOutput[D-1:0];
    wire [D-1:0] bankWrite;
    
    genvar i,j;
    generate
        // one-hot-encoding for determining which bank is selected
        assign bankWrite = ioSelect && write ? (1<<ioBankSelect):{D{write}};
        assign ioOut = outputs[ioBankSelect];
        for (i = 0; i<D; i=i+1) begin
            assign inputs[i]  = ip[W*(i+1)-1 -:W];
            assign op[W*(i+1)-1 -:W] = outputs[i];
            assign bankInput[i] = ioSelect && write ? ioInput: inputs[i];
            assign outputs[i] = bankOutput[i];
            SRAM #(.W(W),.A(A)) bank (
                .address(address),
                .dataInput(bankInput[i]),
                .dataOutput(bankOutput[i]),
                .write(bankWrite[i]),
                .CLK(CLK)
            );
        end
    endgenerate

endmodule
