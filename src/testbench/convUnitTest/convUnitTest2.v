`timescale 1ns / 1ns

module convUnitTest2 ();
parameter depth = 2;
parameter D = 1<<depth;
parameter Al = 7;
parameter ALocal = Al;
parameter A = Al;
parameter Ab = 11;
parameter ABuffer = Ab;
parameter W = 8;
parameter insW = (2 > depth)? 2: depth,
        insD = (D > W)? D:W,
        insWidth = 4+2+2*insW+insD;

`define NULL 0

reg CLK;
always begin #1;CLK=!CLK; end

// integer c_file,c,write_data,w;

reg [depth-1:0] Tr = 2;      // ins1 = 2'b00, ins2 = 2'b00
reg [depth-1:0] Tc = 2;      // ins1 = 2'b00, ins2 = 2'b01
reg [Al-1:0] kernelStep=4; // ins1 = 2'b00, ins2 = 2'b10
reg [Al-1:0] neuronStep=4;
reg [depth-1:0] convDivIniValue=0;

reg  [W*D-1:0] partialSumIn = 0;
wire [W*D-1:0] partialSumOut;
reg [W*D-1:0] kBuffIn=0;
reg [W*D-1:0] nBuffIn=0;
reg [D*8-1:0] columnControl = 0;
reg [D-1:0] rowControl = 1;
wire [3*depth+2*ALocal-1:0] commonControl={{Tc,Tr,kernelStep},{neuronStep},convDivIniValue};

//=========================================================================
    wire [W-1:0] adderConnections[D-1:0][D:0]; // [rows] [inter column]
    wire [W-1:0] kernelBufferRow [D-1:0];
    wire [depth-1:0] rowControlSignal[D-1:0];
    wire [W-1:0] neuronBufferColumn [D-1:0];
    wire [7:0] columnControlSignal [D-1:0];    

    genvar i,j;
    generate
        // converting to convenient 2D
        for (i = 0; i < D; i = i+1) begin
            assign adderConnections[i][0] = partialSumIn[W*(i+1)-1 -:W];
            assign partialSumOut[W*(i+1)-1 -:W] = adderConnections[i][D];
            assign columnControlSignal[i] = columnControl[8*(i+1)-1 -:8];
            assign kernelBufferRow[i] = kBuffIn[W*(i+1)-1 -:W];
            assign rowControlSignal[i] = rowControl[i];
            assign neuronBufferColumn[i] = nBuffIn[W*(i+1)-1 -:W];
        end
        // PE mesh
        for (i = 0; i < D; i = i + 1) begin // rows
            for (j = 0; j < D; j = j + 1) begin // columns
                PE #(.depth(depth),.W(W),.A(A)) processingElement(
                    .adderIn(adderConnections[i][j]),
                    .adderOut(adderConnections[i][j+1]),
                    .columnControl(columnControlSignal[j]),
                    .rowControl(rowControlSignal[i]),
                    .commonControl(commonControl),
                    .kernelIn(kernelBufferRow[i]),
                    .neuronIn(neuronBufferColumn[j]),
                    .CLK(CLK)
                );
            end
        end
    endgenerate
//=========================================================================

endmodule
