`timescale 1ns / 1ps
/*
 * Processing Element implementation
 *
 */

module PE #(parameter 
        depth = 2,
        A = 7,
        CTR_IP = 1, // under consideration
        W = 16
    )(
        input wire [W-1:0] adderIn,
        input wire [CTR_IP-1:0] controlSignal,
        output wire [W-1:0] adderOut,
        input wire [W-1:0] kernelIn,
        input wire [W-1:0] neuronIn,
        input wire CLK
    );

    wire kernelWrite, neuronWrite;
    wire [A-1:0] kernelAddress, neuronAddress;
    wire [W-1:0] kOut, nOut;

    wire [W-1:0] multResult;

    LocalStoreController #(.W(W),.A(A),.depth(depth),.CTR_IP(CTR_IP)) localStoreController(
        .controlSignal(controlSignal),
        .kernelAddress(kernelAddress),
        .kernelWrite(kernelWrite),
        .neuronAddress(neuronAddress),
        .neuronWrite(neuronWrite),
        .CLK(CLK)
    );

    LocalStore #(.W(W),.A(A)) kernelStore(
        .address(kernelAddress),
        .dataInput(kernelIn),
        .dataOutput(kOut),
        .write(kernelWrite),
        .CLK(CLK)
    );

    LocalStore #(.W(W),.A(A)) neuronStore(
        .address(neuronAddress),
        .dataInput(neuronIn),
        .dataOutput(nOut),
        .write(neuronWrite),
        .CLK(CLK)
    );

    NBitAdder #(.N(W)) adder(
        .ip1(adderIn),
        .ip2(multResult),
        .op(addResult)
    );

    NBitMultiplier #(.N(W)) multiplier(
        .ip1(kOut),
        .ip2(nOut),
        .op(multResult)
    );

endmodule
