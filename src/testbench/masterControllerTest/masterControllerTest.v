`timescale 1ns / 1ns

module masterControllerTest ();
parameter depth = 3;
parameter D = 1<<depth;
parameter Al = 7;
parameter Ab = 11;
parameter W = 16;
parameter insW = (2 > depth)? 2: depth,
        insD = (D > W)? D:W,
        insWidth = 4+2+2*insW+insD;

`define NULL 0

reg CLK;
always begin #1;CLK=!CLK; end

integer c_file,c,write_data,w;

reg [insWidth-1:0] instruction;
wire [W-1:0] dataOut;

wire [3:0] opcode;
wire [1:0] ins1;
wire [insW-1:0] ins2, ins3;
wire [insD-1:0] insLast;
    assign {opcode,ins1,ins2,ins3,insLast } = instruction;

wire [2*depth-1:0] kernelDistControl;
wire [Ab-1:0] kernelBuffAddress;
wire [W-1+depth+2 :0] kerbelBuffIO;

wire [Ab-1:0] nReadAddress, nWriteAddress;
reg [W-1:0] nReadIO_Out ;
wire [W+depth+1 :0] nReadIO_In;

wire [D*8-1:0] convUnitColumnControl;
wire [D-1:0] convUnitRowControl;
wire [3*depth+2*Al-1:0] convUnitCommonControl;

wire doPooling,readBufferSelect,nRWrite,nWWrite;
wire [D*4-1:0] poolUnitControl;

MasterController #(.W(W),.depth(depth),.Ab(Ab),.Al(Al)) uut (
    // Interface
    // .dataIn(dataIn),
    .dataOut(dataOut),
    .instruction(instruction),

    // Kernel Buffer
    .kBuffIn(kerbelBuffIO),
    .kBuffAddress(kernelBuffAddress),
    .kernelDistControl(kernelDistControl),

    // Neuron Buffer
    .readBufferSelect(readBufferSelect),
    .nReadAddress(nReadAddress),
    .nWriteAddress(nWriteAddress),
    .nRWrite(nRWrite),
    .nWWrite(nWWrite),
    .nReadIO_In(nReadIO_In), // here output
    .nReadIO_Out(nReadIO_Out),// here input

    // Conv Unit
    .convUnitColumnControl(convUnitColumnControl),
    .convUnitRowControl(convUnitRowControl),
    .convUnitCommonControl(convUnitCommonControl),
    
    // Pooling Unit
    .poolUnitControl(poolUnitControl),
    .doPooling(doPooling),

    .CLK(CLK)
);

initial begin
    c_file=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/masterControllerTest/instructions.txt","r");
    if (c_file ==`NULL) begin
        $display("c_file handle was NULL");
        $finish;
    end
    write_data=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/masterControllerTest/test_result.txt","w");
    // instruction <= 0;
    CLK = 1'b0;
end

always @(posedge CLK) begin
    if (!$feof(c_file) )begin
        c=$fscanf(c_file,"%b\n:",instruction);
        // if (instruction[insWidth-1 -:4] == 4'b0011 ) begin
        //     $fdisplay(write_data,"%b",{instruction,dataOut});
        // end
    end else begin 
        $fclose(write_data);
        $fclose(c_file);
        #2 $finish;
    end
end

endmodule
