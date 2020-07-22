`timescale 1ns / 1ps

module poolingALUTest ();
parameter W = 4;

reg CLK;
always begin #1;CLK=!CLK; end

reg [W-1:0] ipCurr = 1, ipUp = 0, ipBel = 2;
reg [3:0] control;
wire [W-1:0] op, max;

PoolingALU #(.W(W)) uut(
    .controlSignal(control),
    .ip(ipCurr),
    .ipFromUp(ipUp),
    .ipFromDown(ipBel),
    .op(op),
    .max(max),
    .CLK(CLK)
);
initial begin
    control = 4'b1000;
    CLK = 1;
//    #20 $finish;
end

always @(negedge CLK) begin
    control = control +1;
    if (control == 4'b0111) begin
        $finish;
    end
end
endmodule