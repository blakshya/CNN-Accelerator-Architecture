`timescale 1ns / 1ps

module acceleratorTest2 ();
parameter depth = 2;
parameter D = 1<<depth;
parameter Al = 7;
parameter ALocal = Al;
parameter Ab = 11;
parameter ABuffer = Ab;
parameter W = 8;
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

// Accelerator #(.depth(depth),.ABuffer(Ab),.ALocal(Al),.W(W)) uut(
//     .instruction(instruction),
//     .dataOut(dataOut),
//     .CLK(CLK)
// );
// ============================================================================


wire [2*depth-1:0] kernelDistControl;
wire [ABuffer-1:0] kernelBuffAddress;
wire [W-1+depth+2 :0] kerbelBuffIO;

wire [ABuffer-1:0] nReadAddress, nWriteAddress;
wire [W-1:0] nReadIO_Out;
wire [W+depth+1 :0] nReadIO_In;

wire [D*8-1:0] convUnitColumnControl;
wire [D-1:0] convUnitRowControl;
wire [3*depth+2*ALocal-1:0] convUnitCommonControl;

wire doPooling,readBufferSelect,nRWrite,nWWrite;
wire [D*4-1:0] poolUnitControl;

MasterController #(.W(W),.depth(depth),.Ab(ABuffer),.Al(ALocal)) controller(
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

wire [ABuffer-1:0] n1Address, n2Address;
wire [W*D-1:0] n1In, n2In;
wire [W*D-1:0] n1Out, n2Out;
wire [W*D-1:0] poolUnitOut;
wire [W*D-1:0] convUnitPartialSumIn;
wire [W*D-1:0] convUnitNBuffIn;

wire [W-1:0] n1IO_Out, n2IO_Out;
wire [W+depth+1 :0] n1IO_In, n2IO_In;

wire n1Write, n2Write;

NeuronBufferSwapper #(.depth(depth),.A(ABuffer),.W(W)) nSwapper(
    .readBufferSelect(readBufferSelect),
    .fromN1(n1Out),
    .fromN2(n2Out),
    .toN1In(n1In),
    .toN2In(n2In),

    .readBuffAddress(nReadAddress),
    .writeBuffAddress(nWriteAddress),
    .n1Address(n1Address),
    .n2Address(n2Address),

    .nRWrite(nRWrite),
    .nWWrite(nWWrite),
    .n1Write(n1Write),
    .n2Write(n2Write),

    .nReadIO_In(nReadIO_In),// here input
    .nReadIO_Out(nReadIO_Out),// here output
    .n1IO_In(n1IO_In),// here out
    .n1IO_Out(n1IO_Out),// here in
    .n2IO_In(n2IO_In),
    .n2IO_Out(n2IO_Out),

    .fromPoolUnitOut(poolUnitOut),
    .toConvUnitNBuffIn(convUnitNBuffIn),
    .toConvUnitPartialSum(convUnitPartialSumIn),
    .doPooling(doPooling)
);

NeuronBuffer #(.depth(depth),.A(ABuffer),.W(W)) neuronBuffer1(
    .ip(n1In),
    .op(n1Out),
    .address(n1Address),
    .write(n1Write),
    .ioInputs(n1IO_In),
    .ioOutputs(n1IO_Out),
    .CLK(CLK)
);

NeuronBuffer #(.depth(depth),.A(ABuffer),.W(W)) neuronBuffer2(
    .ip(n2In),
    .op(n2Out),
    .address(n2Address),
    .write(n2Write),
    .ioInputs(n2IO_In),
    .ioOutputs(n2IO_Out),
    .CLK(CLK)
);

wire [W*D-1:0] kernelInputForConvUnit;
wire [W*D-1:0] kernelBufferOutput;

KernelBufferDistributor #(.depth(depth),.W(W)) kBufDist(
    .ip(kernelBufferOutput),
    .op(kernelInputForConvUnit),
    .controlSignal(kernelDistControl)
);

KernelBuffer #(.depth(depth),.A(ABuffer),.W(W)) kernelBuffer(
    .op(kernelBufferOutput),
    .address(kernelBuffAddress),
    .ioInputs(kerbelBuffIO),
    .CLK(CLK)
);

wire [W*D-1:0] convUnitOut;

ConvolutionalUnit #(.depth(depth),.A(ALocal),.W(W)) convolutionalUnit(
    .partialSumIn(convUnitPartialSumIn),
    .partialSumOut(convUnitOut),
    .kBuffIn(kernelInputForConvUnit),
    .nBuffIn(convUnitNBuffIn),
    .columnControl(convUnitColumnControl),
    .rowControl(convUnitRowControl),
    .commonControl(convUnitCommonControl),
    .CLK(CLK)
);

PoolingUnit #(.depth(depth),.W(W)) poolingUnit(
    .doPooling(doPooling),
    .ip(convUnitOut),
    .op(poolUnitOut),
    .control(poolUnitControl),
    .CLK(CLK)
);

// ========================================================================

 wire [W-1:0] poolOutput[D-1:0];
 wire [W-1:0] poolInput[D-1:0];
 
genvar i;
generate
     for (i = 0; i<D; i = i+1) begin
		assign poolOutput [i] =  poolUnitOut[W*(i+1)-1 -:W];
		assign poolInput [i] = convUnitOut[W*(i+1)-1 -:W];
	end
endgenerate

initial begin
    c_file=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/acceleratorTest/instructions.txt","r");
    if (c_file ==`NULL) begin
        $display("c_file handle was NULL");
        $finish;
    end
    write_data=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/acceleratorTest/test_result.txt","w");
//    instruction <= 0;
    CLK = 1'b0;
end

always @(posedge CLK) begin
    if (!$feof(c_file) )begin
        c=$fscanf(c_file,"%b\n:",instruction);
        if (instruction[insWidth-1 -:4] == 4'b0011 ) begin
            $fdisplay(write_data,"%b",{instruction,dataOut});
        end
    end else begin 
        $fclose(write_data);
        #5 $finish;
    end
end

endmodule
