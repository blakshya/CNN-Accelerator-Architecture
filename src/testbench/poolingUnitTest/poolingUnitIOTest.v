`timescale 1ns / 1ps

module poolingUnitIOTest ();
parameter depth = 4;
parameter D = 1<<depth;
parameter W = depth+1;

reg CLK;
always begin #1;CLK=!CLK; end

reg doPooling;
reg [W-1:0] inputs [D-1:0];
wire [W-1:0] outputs[D-1:0];
wire [W*D-1:0] ip, op;
wire [D*4-1:0] control;
reg [3:0] ctrl;
    assign control ={D{ctrl}};

PoolingUnit #(.depth(depth),.W(W)) uut (
    .doPooling(doPooling),
    .ip(ip),
    .control(control),
    .op(op),
    .CLK(CLK)
);

genvar j;
generate
    for (j = 0; j<D; j = j+1) begin
        assign ip[W*(j+1)-1 -:W] = inputs[j];
        assign outputs[j] = op[W*(j+1)-1 -:W];
    end
endgenerate

integer i;
initial begin
    for (i = 0; i<D; i=i+1) begin
        inputs[i] = i;
    end
    CLK = 0;
    ctrl = 0;
    doPooling = 0;
    #1 doPooling = 1;
    ctrl = {4'b1000};
end

always @(negedge CLK) begin
    ctrl = ctrl +1;
    if (ctrl == 4'b1111) begin
        #1 $finish;
    end
end

endmodule
