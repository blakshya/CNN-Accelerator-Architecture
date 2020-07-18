`timescale 1ns / 1ps

module sramTest ();
parameter A = 11;
parameter W = 16;

`define NULL 0

integer in_file,in,write_data,w;

reg CLK;
always begin #1;CLK=!CLK; end

reg write;
reg [W-1:0] data;
reg [A-1:0] addr;
wire [W-1:0] out;

initial begin
    in_file=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/sramTest/in_fp.txt","r");
    // in_file = `NULL;
     if (in_file ==`NULL) begin
        $display("input file handle was NULL");
        $finish;
    end
    // write_data = `NULL;
    write_data=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/sramTest/sim_result.txt","w");

    addr<=0;
    write<=1'b1;
    #0.1 CLK=1'b1;
end

SRAM #(.A(A),.W(W)) uut(
    .address(addr),
    .dataInput(data),
    .dataOutput(out),
    .write(write),  
    .CLK(CLK)
);

always @(posedge CLK) begin
//always @(negedge CLK) begin
    if (!$feof(in_file) )begin
        write<=1'b1;
        #0.1 in = $fscanf(in_file,"%b\n",data);
    end else begin
        write<=1'b0;
        data <=0;
        $fdisplay(write_data,"%b",out);
    end
    if (addr == {(A){1'b1}}) begin
        $finish;
    end
end

always @(posedge CLK) begin
    addr<= write? addr+1 : addr -1;
end

endmodule
