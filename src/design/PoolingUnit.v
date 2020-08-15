`timescale 1ns / 1ps

/*
 * Connections of use upper and ulse lower are a little counter intuitive
 * We follow the same convention as used in convolutional unit
 *      i.e. 0 is the top, D-1 is the bottom
 *
 */

module PoolingUnit #(parameter
        depth = 3,
        D = (1<<depth),
        W = 16
    )(
        input wire doPooling,
        input wire [W*D-1:0] ip,
        input wire [D*4-1:0] control,
        output wire[W*D-1:0] op,
        input wire CLK
    );

    wire [W-1:0] inputs [D-1:0], outputs[D-1:0], poolOutputs[D-1:0];
    wire [3:0] aluControl [D-1:0];

    wire [W-1:0] aluIpFromUp[D-1:0];
    wire [W-1:0] aluIpFromBelow[D-1:0];

    genvar i;
    generate
        for (i = 0; i<D; i = i+1) begin
            assign aluControl[i] = control[4*(i+1)-1 -:4];
            assign inputs[i] = ip[W*(i+1)-1 -:W];
            assign op[W*(i+1)-1 -:W] = doPooling?outputs[i]:inputs[i];
            assign aluIpFromBelow[i] = |(D-1-i)?poolOutputs[i+1]:0;
            assign aluIpFromUp[i] = (i)?poolOutputs[i-1]:0;

            PoolingALU #(.W(W)) poolingALU (
                .controlSignal(aluControl[i]),
                .ip(inputs[i]),
                .ipFromUp(aluIpFromUp[i]),
                .ipFromDown(aluIpFromBelow[i]),
                .op(poolOutputs[i]),
                .max(outputs[i]),
                .CLK(CLK)
            );
        end
        
    endgenerate
endmodule
