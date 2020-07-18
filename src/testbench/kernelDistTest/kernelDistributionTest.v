`timescale 1ns / 1ps


module kernelDistributionTest();
parameter depth = 3;
parameter D = 1<<depth;
parameter W = D;

`define NULL 0

reg CLK;
always begin #1;CLK=!CLK; end

integer     c_file,c,write_data,w;


reg [W-1:0] inputs [D-1:0];
wire [W-1:0] outputs[D-1:0];
wire [W*D-1:0] ip, op;
reg [2*depth-1:0] control;

wire [depth-1:0] trc, bank;
    assign {trc,bank} = control;

genvar j;
generate
    for (j = 0; j < D; j = j+1) begin
        assign ip[W*(j+1)-1 -:W] = inputs[j];
        assign outputs[j] =  op[W*(j+1)-1 -:W];
    end
endgenerate

KernelBufferDistributor #(.depth(depth),.W(W)) uut (
    .ip(ip),
    .op(op),
    .controlSignal(control)
);

integer i;
initial begin
    c_file=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/kernelDistTest/kernelDistributionTest_instructions.txt","r");
    if (c_file ==`NULL) begin
        $display("c_file handle was NULL");
        $finish;
    end
    write_data=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/kernelDistTest/kernelDistributionTest_result.txt","w");
    control <= 0;
    CLK = 1'b0;
    for (i = 0; i < D; i = i+1) begin
        inputs[i] <= i;
    end
end

always @(posedge CLK) begin
    if (!$feof(c_file) )begin
        c=$fscanf(c_file,"%b\n:",control);
        // if (! ioWrite) begin
        //     $fdisplay(write_data,"%b",{op});
        // end
    end else begin 
       $fclose(write_data);
        $finish;
    end
end

endmodule