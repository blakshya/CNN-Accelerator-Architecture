`timescale 1ns / 1ps
/*
 * Convolutional Unit Implementation
 * a 2-D mesh of connected PEs
 */

module ConvolutionalUnit #(parameter
        depth = 2,
        D = (1<<depth),
        A = 7,
        PE_CTRL = 1, // under consideration
        W = 16
    )(
        input wire [W*D-1:0] partialSumIn,
        output wire[W*D-1:0] partialSumOut,
        input wire [W*D-1:0] kBuffIn,
        input wire [W*D-1:0] nBuffIn,
        input wire [D*PE_CTRL-1:0] controlSignal,
        input wire CLK
    );

    wire [W-1:0] adderConnections[D-1:0][D:0]; // [rows] [inter column]
    wire [W-1:0] kernelBufferRow [D-1:0];
    wire [W-1:0] neuronBufferColumn [D-1:0];
    wire [PE_CTRL-1:0] columnControlSignal [D-1:0];

    genvar i,j;
    generate
        // converting to convenient 2D
        for (i = 0; i < D; i = i+1) begin
            assign adderConnections[i][0] = partialSumIn[W*(i+1)-1 -:W];
            assign partialSumOut[W*(i+1)-1 -:W] = adderConnections[i][D];
            assign columnControlSignal[i] = controlSignal[PE_CTRL*(i+1)-1 -:PE_CTRL];
            assign kernelBufferRow[i] = kBuffIn[W*(i+1)-1 -:W];
            assign neuronBufferColumn[i] = nBuffIn[W*(i+1)-1 -:W];
        end
        // PE mesh
        for (i = 0; i < D; i = i + 1) begin // rows
            for (j = 0; j < D; j = j + 1) begin // columns
                PE #(.depth(depth),.W(W),.A(A)) processingElement(
                    .adderIn(adderConnections[i][j]),
                    .adderOut(adderConnections[i][j+1]),
                    .controlSignal(columnControlSignal[j]),
                    .kernelIn(kernelBufferRow[i]),
                    .neuronIn(neuronBufferColumn[j]),
                    .CLK(CLK)
                );
            end
        end
    endgenerate

endmodule
