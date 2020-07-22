`timescale 1ns / 1ps

module PoolingALU #(parameter
    depth = 2,
    D = 1<<depth,
    W = 16
    )(
        input wire [3:0] controlSignal,
        input  wire [W-1:0] ip,
        input  wire [W-1:0] ipFromUp,
        input  wire [W-1:0] ipFromDown,
        output wire [W-1:0] op,
        output reg  [W-1:0] max,
        input  wire CLK
    );
/* DESCRIPTION OF THE control (ctl)
    * [MSB:LSM] - write, useUpper, useCurrent, useLower
    * write - 1: write to max, 0:dont write to max
    * useUpper     - 1: use input from unit above, 0: replace with zero
    * useCurrent   - 1: use input from buffer    , 0: replace with zero
    * useLower     - 1: use input from unit below, 0: replace with zero
*/
// parameter 
    wire write,useUpper,useCurrent,useLower;
        assign {write,useUpper,useCurrent,useLower} = controlSignal;

    wire [W-1:0] selUpper, selCurrent, selLower;
        assign selUpper     = useUpper  ? ipFromUp:0;
        assign selCurrent   = useCurrent? ip:0;
        assign selLower     = useLower  ? ipFromDown:0;
    
    wire [W-1:0] sub1, sub2, max1, max2;
        assign sub1 = selCurrent - selUpper;
        assign max1 = sub1[W-1]? selUpper:selCurrent;
        assign sub2 = max1 - selLower;
        assign max2 = sub2[W-1]? selLower:max1;

    assign op = max2;

    always @(negedge CLK) begin
        if (write) begin
            max <= op;
        end
    end

endmodule
