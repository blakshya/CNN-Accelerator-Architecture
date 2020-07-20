`timescale 1ns / 1ns

module peIOTest();
parameter depth = 4;
parameter D = 1<<depth;
parameter A = 7;
parameter W = 16;

`define NULL 0

reg CLK;
always begin #1;CLK=!CLK; end

integer c_file,c,write_data,w;

parameter ctrl_W = W +8+3*depth+2*A+2*W;
reg [ctrl_W-1:0] control;
wire [W-1:0] adderIn, adderOut, kernelIn, neuronIn;
wire [7:0] controlSignal;
wire [depth-1:0] initSettings;
wire [2*depth+2*A-1:0] peConfig;
assign {adderIn,controlSignal,initSettings,peConfig,kernelIn,neuronIn} = control;

PE #(.depth(depth),.A(A),.W(W)) uut (
    .adderIn(adderIn),
    .controlSignal(controlSignal),
    .initSettings(initSettings),
    .peConfig(peConfig),
    .kernelIn(kernelIn),
    .neuronIn(neuronIn),
    .adderOut(adderOut),
    .CLK(CLK)
);
initial begin
    c_file=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/peTest/instructions.txt","r");
    if (c_file ==`NULL) begin
        $display("c_file handle was NULL");
        $finish;
    end
    write_data=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/peTest/IOTest_result.txt","w");
    control <= 0;
    CLK = 1'b0;
end

always @(posedge CLK) begin
    if (!$feof(c_file) )begin
        c=$fscanf(c_file,"%b\n:",control);
        if (!controlSignal[0] ) begin
            $fdisplay(write_data,"%b",{adderOut,controlSignal,initSettings,peConfig});
        end
    end else begin 
       $fclose(write_data);
        $finish;
    end
end

endmodule
