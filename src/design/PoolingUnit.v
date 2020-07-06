`timescale 1ns / 1ps

module PoolingUnit #(parameter
        depth = 3,
        D = (1<<depth),
        W = 16
    )(
        input wire [W*D-1:0] ip,
        input wire [D*5-1:0] control,
        output wire[W*D-1:0] op,
        input wire CLK
    );

    /*
     * Currently Empty
     * Someone pls help
     */

endmodule
