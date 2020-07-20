`timescale 1ns / 1ns

module localControllerIOTest ();
parameter depth = 2;
parameter D = 1<<depth;
parameter A = 7;
parameter W = 16;

`define NULL 0

reg CLK;
always begin #1;CLK=!CLK; end

integer     c_file,c,write_data,w;

parameter ctrl_W = 8+3*depth+2*A;
reg [ctrl_W-1:0] control;
wire [7:0] controlSignal;
wire [depth-1:0] initSettings;
wire [2*depth+2*A-1:0] peConfig;
assign {controlSignal,initSettings,peConfig} = control;

wire [A-1:0] kernelAddress, neuronAddress;
wire kernelWrite, neuronWrite;

LocalStoreController #(.depth(depth),.A(A),.W(W)) uut(
    .controlSignal(controlSignal),
    .peConfig(peConfig),
    .initSettings(initSettings),
    .kernelAddress(kernelAddress),
    .neuronAddress(neuronAddress),
    .kernelWrite(kernelWrite),
    .neuronWrite(neuronWrite),
    .CLK(CLK)
);

initial begin
    c_file=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/localControllerTest/instructions.txt","r");
    if (c_file ==`NULL) begin
        $display("c_file handle was NULL");
        $finish;
    end
    write_data=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/localControllerTest/IOTest_result.txt","w");
    control <= 0;
    CLK = 1'b0;
end

always @(posedge CLK) begin
    if (!$feof(c_file) )begin
        c=$fscanf(c_file,"%b\n:",control);
        if (controlSignal[3] ) begin
            // $fdisplay(write_data,"%b",{kernelAddress,neuronAddress,controlSignal,initSettings,peConfig});
            $fdisplay(write_data,"%b",{controlSignal,initSettings,peConfig});
        end
    end else begin 
       $fclose(write_data);
        $finish;
    end
end

endmodule
