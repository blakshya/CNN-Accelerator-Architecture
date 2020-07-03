`timescale 1ns / 1ps
/*
 * Module used for storage whenever needed
 *
 */

module SRAM #(parameter
        A = 7, // address [depth]
        W = 16 // Word length
    )(
        input [A-1:0] address, //address of ip/op select line
        input [W-1:0] dataInput,
        output [W-1:0] dataOutput,
        input write,
        input CLK
    );

reg [W-1:0] memory [(1<<A)-1:0];


always @(posedge CLK) begin
    memory[address] <= write?dataInput:memory[address];
end

//assign dataOutput = write?{W{1'bz}}:memory[address];
assign dataOutput = memory[address];

integer i;
initial begin
    for (i=0;1<(1<<A);i=i+1) begin
        memory[i] = i;
    end
end
endmodule
