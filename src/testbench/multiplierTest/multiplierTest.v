`timescale 1ns / 1ps

module multiplierTest();
parameter W = 16;

`define NULL 0
reg CLK;
always begin #1;CLK=!CLK; end

// opening files
integer     in1_file,in1,in2_file,in2,write_data,w;
initial begin
    CLK=1'b1;
    // For Windows
    // file with inputs to adder
    in1_file = $fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/multiplierTest/in1_fp.txt","r");
    in2_file = $fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/multiplierTest/in2_fp.txt","r");
    // file to write the results
    write_data = $fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/multiplierTest/sim_result.txt","w");
    if (in1_file ==`NULL) begin
        $display("in1 file handle was NULL");
        $finish;
    end
    if (in2_file ==`NULL) begin
        $display("in2 file handle was NULL");
        $finish;
    end
//   $finish;
end

reg [W-1:0] ip1,ip2;
wire [W-1:0] op;

NBitMultiplier #(.N(W)) uut(
    .ip1(ip1),
    .ip2(ip2),
    .op(op)
);

always @(posedge CLK)begin
    in1 = $fscanf(in1_file,"%b\n",ip1);
    in2 = $fscanf(in2_file,"%b\n",ip2);
end

always @(negedge CLK) begin
    $fdisplay(write_data,"%b ",op); //write as binary
    if (!$feof(in1_file) & !$feof(in2_file) )begin
        $display("%d %d %d\n",ip1,ip2,op);
    end else begin
        $fclose(write_data);
        $finish; 
    end
end

endmodule
