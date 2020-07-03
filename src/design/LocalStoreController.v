`timescale 1ns / 1ps
/*
 * Local controller within each PE
 *
 */

module LocalStoreController #(parameter 
        depth = 2,
        A = 7,
        CTR_IP = 1, //under consideration
        D = (1<<depth),
        W = 16
    )(
        input wire [CTR_IP-1:0] controlSignal,
        output wire [A-1:0] kernelAddress,
        output wire [A-1:0] neuronAddress,
        output wire kernelWrite,
        output wire neuronWrite,
        input wire CLK
    );

    /*
     * Currently Empty
     * Someone pls help
     */

endmodule
