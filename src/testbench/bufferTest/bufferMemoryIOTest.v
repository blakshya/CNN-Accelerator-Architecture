`timescale 1ns / 1ns

module bufferMemoryIOTest();
parameter depth = 2;
parameter D = 1<<depth;
parameter A = 7;
parameter W = 16;

`define NULL 0

reg CLK;
always begin #1;CLK=!CLK; end

integer     c_file,c,write_data,w;

reg [A+2+W+depth-1:0] control;
wire [W-1:0] ioIn;
wire ioWrite,ioSelect;
wire [depth-1:0] ioBankSelect;
wire [A-1:0] address;
wire [W*D-1:0] in;
wire [W*D-1:0] op;
wire [W-1:0] ioOut;
assign {address,ioSelect,ioWrite,ioBankSelect,ioIn} = control;

BufferMemory #(.depth(depth),.A(A),.W(W)) uut(
    .ip(in),
    .op(op),
    .address(address),
    .ioSelect(ioSelect),
    .write(ioWrite),
    .ioBankSelect(ioBankSelect),
    .ioInput(ioIn),
    .ioOut(ioOut),
    .CLK(CLK)
);

initial begin
    c_file=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/bufferTest/bufferIOTest_instructions.txt","r");
    if (c_file ==`NULL) begin
        $display("c_file handle was NULL");
        $finish;
    end
    write_data=$fopen("E:/FlexFlow/github-repo/CNN-Accelerator-Architecture/src/testbench/bufferTest/bufferIOTest_result.txt","w");
    control <= 0;
    CLK = 1'b0;
end

always @(posedge CLK) begin
    if (!$feof(c_file) )begin
        c=$fscanf(c_file,"%b\n:",control);
        if (! ioWrite) begin
            $fdisplay(write_data,"%b",{address,ioSelect,ioWrite,ioBankSelect,ioOut});
        end
    end else begin 
       $fclose(write_data);
        $finish;
    end
end

endmodule
