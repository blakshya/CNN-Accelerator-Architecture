`timescale 1ns / 1ps

module bufferMemoryUsageTest();
parameter depth = 3;
parameter D = 1<<depth;
parameter A = 7;
parameter W = 3;

`define NULL 0

reg CLK;
always begin #1;CLK=!CLK; end

integer     c_file,c,write_data,w;

reg [W*D+A:0] control;
wire ioWrite,ioSelect;
wire [depth-1:0] ioBankSelect;
wire [A-1:0] address;
wire [W*D-1:0] in;
wire [W*D-1:0] op;
assign {address,ioSelect,ioWrite,in} = control;

BufferMemory #(.depth(depth),.A(A),.W(W)) uut(
    .ip(in),
    .op(op),
    .address(address),
    .ioSelect(ioSelect),
    .write(ioWrite),
    .CLK(CLK)
);

initial begin
    c_file=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/bufferTest/bufferUsageTest_instructions.txt","r");
    if (c_file ==`NULL) begin
        $display("c_file handle was NULL");
        $finish;
    end
    write_data=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/bufferTest/bufferUsageTest_result.txt","w");
    control <= 0;
    CLK = 1'b0;
end

always @(posedge CLK) begin
    if (!$feof(c_file) )begin
        c=$fscanf(c_file,"%b\n:",control);
        if (! ioWrite) begin
            $fdisplay(write_data,"%b",{address,ioWrite,op});
        end
    end else begin 
       $fclose(write_data);
        $finish;
    end
end

endmodule
