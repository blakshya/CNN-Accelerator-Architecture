`timescale 1ns / 1ps // time-unit = 1 ns, precision = 1 ps

module Accelerator #(parameter
        depth = 3,
        D = (1<<depth),
        ABuffer = 11,
        ALocal = 7,
        W = 16
    )(
        input wire [W-1:0]  dataIn,
        input wire [1:0] instruction,
        output wire[W-1:0] dataOut,
        input wire CLK
    );

    wire [2*depth-1:0] kernelDistControl;
    wire [ABuffer-1:0] kernelBuffAddress;
    wire [1:0] kerbelBuffIO;

    wire [ABuffer-1:0] nReadAddress, nWriteAddress;
    wire [W-1:0] nReadIO_In, nReadIO_Out;

    wire [1:0] convUnitControl;
    wire [1:0] poolUnitControl;

    MasterController #(.W(W),.depth(depth),.ABuffer(ABuffer)) controller(
        .dataIn(dataIn),
        .dataOut(dataOut),
        .instruction(instruction),

        .kBuffIn(kerbelBuffIO),
        .kBuffAddress(kernelBuffAddress),
        .kernelDistControl(kernelDistControl),

        .nReadAddress(nReadAddress),
        .nWriteAddress(nWriteAddress),

        .nReadIO_In(nReadIO_In), // here output
        .nReadIO_Out(nReadIO_Out),// here input

        .convUnitControl(convUnitControl),
        .poolUnitControl(poolUnitControl)
    );

    wire [ABuffer-1:0] n1Address, n2Address;
    wire [W*D-1:0] n1In, n2In;
    wire [W*D-1:0] n1Out, n2Out;
    wire [W*D-1:0] poolUnitOut;
    wire [W*D-1:0] convUnitPartialSumIn;
    wire [W*D-1:0] convUnitNBuffIn;

    wire [W-1:0] n1IO_In, n1IO_Out, n2IO_In, n2IO_Out;

    NeuronBufferSwapper #(.depth(depth),.A(ABuffer),.W(W)) nSwapper(
        .fromN1(n1Out),
        .fromN2(n2Out),
        .toN1In(n1In),
        .toN2In(n2In),

        .readBuffAddress(nReadAddress),
        .writeBuffAddress(nWriteAddress),
        .n1Address(n1Address),
        .n2Address(n2Address),

        .nReadIO_In(nReadIO_In),// here input
        .nReadIO_Out(nReadIO_Out),// here output
        .n1IO_In(n1IO_In),// here out
        .n1IO_Out(n1IO_Out),// here in
        .n2IO_In(n2IO_In),
        .n2IO_Out(n2IO_Out),

        .fromPoolUnitOut(poolUnitOut),
        .toConvUnitNBuffIn(convUnitNBuffIn),
        .toConvUnitPartialSum(convUnitPartialSumIn)
    );

    NeuronBuffer #(.depth(depth),.A(ABuffer),.W(W)) neuronBuffer1(
        .ip(n1In),
        .op(n1Out),
        .address(n1Address),
        .ioInputs(n1IO_In),
        .ioOutputs(n1IO_Out),
        .CLK(CLK)
    );

    NeuronBuffer #(.depth(depth),.A(ABuffer),.W(W)) neuronBuffer2(
        .ip(n2In),
        .op(n2Out),
        .address(n2Address),
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
        .controlSignal(convUnitControl),
        .CLK(CLK)
    );

    PoolingUnit #(.depth(depth),.W(W)) poolingUnit(
        .ip(convUnitOut),
        .op(poolUnitOut),
        .control(poolUnitControl),
        .CLK(CLK)
    );

endmodule
