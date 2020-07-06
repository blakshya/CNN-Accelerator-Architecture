`timescale 1ns / 1ps
/*
 *
 * Works on the philosophy - calculte everything, use only what is needed
 */
/*
 * Parameters
 *
 * Ports
 *  bankSelect - bank to be chosen in group ( < Tr)
 *  Trc - size of groups, (=Tr*Tc)
 */

module KernelBufferDistributor #(parameter
        depth = 2,
        D = (1<<depth),
        W = 16
    )(
        input wire [W*D-1:0] ip,
        output wire [W*D-1:0]op,
        input wire [2*depth-1:0] controlSignal
    );

    wire [depth-1:0] bankSelect, Trc;
    assign {Trc, bankSelect} = controlSignal;

//    wor [3:0] a = 0;
    wire [W-1:0] rowIn [D-1:0];
    wire [W-1:0] rowOutputByTrc[D-1:0][D-1:0];// [row][trc]

    genvar i,group,step;
    generate
        for (i = 0; i < D; i = i+1) begin
            assign rowIn[i] = ip[W*(i+1)-1 -:W];
            assign rowOutputByTrc[i][0] = ip[W*(i+1)-1 -:W];
            assign op[W*(i+1)-1 -:W] = rowOutputByTrc[i][Trc];
        end

        // connecting wires at each level 
        for (i = 0; i<D; i=i+1) begin
            localparam STEP = i+1;
            localparam GROUPS = D/STEP;
            for (group = 0; group < GROUPS; group = group+1) begin
                for (step = 1; step < STEP; step = step+1) begin
                    assign rowOutputByTrc[i][group*STEP+step] = 
                                             rowOutputByTrc[i][group*STEP];
                end
            end
        end

        // populating each level
        for (i = 1; i<D; i=i+1) begin
            localparam GROUP_SIZE = i+1;
            localparam GROUPS = D/GROUP_SIZE;
            for (group = 0; group<GROUPS; group = group+1) begin
                assign rowOutputByTrc[i][group*GROUP_SIZE] = rowIn[group*GROUP_SIZE+bankSelect];
                // add a check for bankSelect<Trc?
                // assign rowOutputByTrc[i][group*GROUP_SIZE] = |(Trc-bankSelect) ?rowIn[group*GROUP_SIZE+bankSelect]:0;
            end
        end
    endgenerate

endmodule