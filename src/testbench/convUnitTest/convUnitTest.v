`timescale 1ns / 1ps
// Merely checking adder connections
module convUnitTest ();
parameter depth = 2;
parameter D = 1<<depth;
parameter Al = 7;
parameter ALocal = Al;
parameter Ab = 11;
parameter ABuffer = Ab;
parameter W = 16;
parameter insW = (2 > depth)? 2: depth,
        insD = (D > W)? D:W,
        insWidth = 4+2+2*insW+insD;

`define NULL 0

reg CLK;
always begin #1;CLK=!CLK; end

// integer c_file,c,write_data,w;

reg [depth-1:0] Tr = 0;      // ins1 = 2'b00, ins2 = 2'b00
reg [depth-1:0] Tc = 0;      // ins1 = 2'b00, ins2 = 2'b01
reg [Al-1:0] kernelStep=0; // ins1 = 2'b00, ins2 = 2'b10
reg [Al-1:0] neuronStep=0;
reg [depth-1:0] convDivIniValue;

reg  [W*D-1:0] partialSumIn = {(D){2'b01}};
wire [W*D-1:0] partialSumOut;
reg [W*D-1:0] kBuffIn;
reg [W*D-1:0] nBuffIn;
reg [D*8-1:0] columnControl ;
reg [D-1:0] rowControl ;
wire [3*depth+2*ALocal-1:0] commonControl={{Tc,Tr,kernelStep},{neuronStep},convDivIniValue};


ConvolutionalUnit #(.depth(depth),.A(ALocal),.W(W)) uut (
    .partialSumIn(partialSumIn),
    .partialSumOut(partialSumOut),
    .kBuffIn(kBuffIn),
    .nBuffIn(nBuffIn),
    .columnControl(columnControl),
    .rowControl(rowControl),
    .commonControl(commonControl),
    .CLK(CLK)
);

endmodule
