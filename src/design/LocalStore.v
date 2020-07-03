`timescale 1ns / 1ps
/*
 * For Storage within each PE block
 * controlled by LocalStoreController
 */

module LocalStore #(parameter
        A = 7,
        W = 16
    )(
        input [W-1:0] dataInput,
        input [A-1:0] address,
        output [W-1:0] dataOutput,
        input write,
        input CLK
    );

    SRAM #(.A(A),.W(W)) memory(
        .address(address),
        .dataInput(dataInput),
        .dataOutput(dataOutput),
        .write(write),
        .CLK(CLK)
    );

endmodule
