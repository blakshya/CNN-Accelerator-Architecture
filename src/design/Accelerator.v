`timescale 1ns / 1ps // time-unit = 1 ns, precision = 1 ps

module Accelerator #(parameter
        depth = 3,
        D = (1<<depth),
        ABuffer = 11,
        ALocal = 7,
        W = 16,
        insW = (2 > depth)? 2: depth,
        insD = (D > W)? D:W,
        insWidth = 4+2+2*insW+insD
    )(
        // input wire [W-1:0]  dataIn,
        input wire [insWidth-1:0] instruction,
        output wire[W-1:0] dataOut,
        input wire CLK
    );

    wire [2*depth-1:0] kernelDistControl;
    wire [ABuffer-1:0] kernelBuffAddress;
    wire [W-1+depth+2 :0] kerbelBuffIO;

    wire [ABuffer-1:0] nReadAddress, nWriteAddress;
    wire [W-1:0] nReadIO_Out;
    wire [W-1+depth+1 :0] nReadIO_In;

    wire [D*8-1:0] convUnitColumnControl;
    wire [D-1:0] convUnitRowControl;
    wire [3*depth+2*ALocal+1-1:0] convUnitCommonControl;

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
        .doPooling(doPooling)
    );

    wire [ABuffer-1:0] n1Address, n2Address;
    wire [W*D-1:0] n1In, n2In;
    wire [W*D-1:0] n1Out, n2Out;
    wire [W*D-1:0] poolUnitOut;
    wire [W*D-1:0] convUnitPartialSumIn;
    wire [W*D-1:0] convUnitNBuffIn;

    wire [W-1:0] n1IO_Out, n2IO_Out;
    wire [W-1+depth+1 :0] n1IO_In, n2IO_In;

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

endmodule
