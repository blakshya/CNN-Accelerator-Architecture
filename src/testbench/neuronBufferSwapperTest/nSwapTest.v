`timescale 1ns / 1ps

module nSwapTest();
parameter depth = 2;
parameter D = 1<<depth;
parameter A = 7;
parameter W = 16;

`define NULL 0

reg CLK;
always begin #1;CLK=!CLK; end

wire readBufferSelect;
    assign readBufferSelect = CLK;

reg [W*D-1:0] fromN1 = 1;
reg [W*D-1:0] fromN2 = 2;
wire[W*D-1:0] toN1In;
wire[W*D-1:0] toN2In;

reg [A-1:0] readBuffAddress = 10;
reg [A-1:0] writeBuffAddress = 11;
wire[A-1:0] n1Address;
wire[A-1:0] n2Address;

reg [W-1:0] nReadIO_In = 10+16;
wire [W-1:0] nReadIO_Out;
wire [W-1:0] n1IO_In;
reg [W-1:0] n1IO_Out = 1+16;
wire [W-1:0] n2IO_In;
reg [W-1:0] n2IO_Out = 2+16;

reg [W*D-1:0] fromPoolUnitOut = 8;
wire[W*D-1:0] toConvUnitNBuffIn;
wire[W*D-1:0] toConvUnitPartialSum;

NeuronBufferSwapper #(.depth(depth),.A(A),.W(W)) uut (
    .readBufferSelect(readBufferSelect),
    .fromN1(fromN1),
    .fromN2(fromN2),
    .toN1In(toN1In),
    .toN2In(toN2In),
    .readBuffAddress(readBuffAddress),
    .writeBuffAddress(writeBuffAddress),
    .n1Address(n1Address),
    .n2Address(n2Address),
    .nReadIO_In(nReadIO_In),
    .nReadIO_Out(nReadIO_Out),
    .n1IO_In(n1IO_In),
    .n1IO_Out(n1IO_Out),
    .n2IO_In(n2IO_In),
    .n2IO_Out(n2IO_Out),
    .fromPoolUnitOut(fromPoolUnitOut),
    .toConvUnitNBuffIn(toConvUnitNBuffIn),
    .toConvUnitPartialSum(toConvUnitPartialSum)
);
initial begin
    CLK = 1'b0;
    #2 $finish;
end

endmodule
