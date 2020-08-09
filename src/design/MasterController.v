`timescale 1ns / 1ps


module MasterController #(parameter
        depth = 2,
        D = (1<<depth),
        Ab = 11,
        Al = 7,
        W = 16,
        insW = (2 > depth)? 2: depth,
        insD = (D > W)? D:W,
        insWidth = 4+2+2*insW+insD

    )(
        // input wire [W-1:0] dataIn,
        input wire [insWidth-1:0] instruction,
        output wire [W-1:0] dataOut,

        output wire [W-1+depth+2 :0] kBuffIn,
        output wire [Ab-1:0] kBuffAddress,
        output wire [2*depth-1:0] kernelDistControl,

        output wire [Ab-1:0] nReadAddress,
        output wire nRWrite,
        output wire [Ab-1:0] nWriteAddress,
        output wire nWWrite,

        output wire [W-1+depth+1 :0] nReadIO_In,
        input wire [W-1:0] nReadIO_Out,

        output reg [D*8-1:0] convUnitColumnControl,
        output wire [(1)*D-1:0] convUnitRowControl,
        output wire [3*depth+2*Al-1:0] convUnitCommonControl,

        output reg doPooling,
        output wire [D*4-1:0] poolUnitControl,

        input wire CLK
    );

     genvar i;
//-----------------------------------------------------------------------------
// Instruction opcodes
//-----------------------------------------------------------------------------
    localparam LOAD_N_BUFFER    = 4'b0000;
    localparam LOAD_K_BUFFER    = 4'b0001;
    localparam LOAD_CONSTANTS   = 4'b0010;
    localparam READ_N_BUFFER    = 4'b0011;

    localparam LOAD_LOCAL_N         = 4'b1000;
    localparam LOAD_LOCAL_K         = 4'b1001;
    localparam CONVOLVE             = 4'b1010;
    localparam POOL                 = 4'b1011;
    localparam DIVIDE_CONV_UNIT     = 4'b1100;
    localparam RESET_POOLING_REG    = 4'b1110;

    wire [3:0] opcode;
    wire [1:0] ins1;
    wire [insW-1:0] ins2, ins3;
    wire [insD-1:0] insLast;

        assign {opcode,ins1,ins2,ins3,insLast } = instruction;

    localparam INIT = 2'b00;
    localparam HOLD = 2'b01;
    localparam INCR = 2'b10;
    localparam JUMP = 2'b11;

//-----------------------------------------------------------------------------
// CONSTANTS : Common Repetitive stuff
//-----------------------------------------------------------------------------

    reg [depth-1:0] Tr;      // ins1 = 2'b00, ins2 = 2'b00
    reg [depth-1:0] Tc;      // ins1 = 2'b00, ins2 = 2'b01
    reg [Al-1:0] kernelStep; // ins1 = 2'b00, ins2 = 2'b10
    reg [Al-1:0] neuronStep; // ins1 = 2'b00, ins2 = 2'b11
    reg [Al-1:0] P;          // ins1 = 2'b01, ins2 = 2'b00
    reg [Al-1:0] nPooledStep;// ins1 = 2'b01, ins2 = 2'b01

    always @(posedge CLK) begin
        if (opcode == LOAD_CONSTANTS) begin
            case (ins1)
                2'b00: case (ins2[1:0])
                    2'b00: Tr = insLast;
                    2'b01: Tc = insLast;
                    2'b10: kernelStep = insLast;
                    2'b11: neuronStep = insLast;
                endcase
                2'b01: case (ins2[1:0])
                    2'b00: P = insLast;
                    2'b01: nPooledStep = insLast;
                endcase
            endcase
        end
    end

//-----------------------------------------------------------------------------
// Kernel Buffer Distribution
//-----------------------------------------------------------------------------

    wire [depth-1:0] Trc; 
        assign Trc = Tr * Tc;
    reg [depth-1:0] kernelBuffBankSelect;
        assign kernelDistControl = {Trc,kernelBuffBankSelect};

//-----------------------------------------------------------------------------
// Convolutional Unit
//-----------------------------------------------------------------------------

    wire [2*depth+2*Ab-1:0] peConfig;
    wire [8*D-1:0] convUnitControl;
    wire [D*depth-1:0] initSettings;
    //-------------------------------------------------------------------------
    // Processing Element
    //-------------------------------------------------------------------------
    assign peConfig = {{Tc,Tr,kernelStep},{neuronStep}};

    //-------------------------------------------------------------------------
    // Load Local Stores - NEURON
    //-------------------------------------------------------------------------
    wire [8*D-1:0] convUnitLoadNControl;
    generate
        for (i = 0; i<D; i=i+1) begin
            assign convUnitLoadNControl[8*(i+1)-1-:8] 
                        = {{1'b0, HOLD,1'b0},{1'b0,ins3[1:0],1'b1}};
        end
    endgenerate
    //-------------------------------------------------------------------------
    // Load Local Stores - KERNEL
    //-------------------------------------------------------------------------
    wire [D-1:0] loadKWrite;
    wire [8*D-1:0] convUnitLoadKControl;
    generate
        for (i = 0; i<D; i=i+1) begin
            assign convUnitLoadKControl[8*(i+1)-1-:8] 
                        = {{1'b0,ins3[1:0],loadKWrite[i]},{1'b0,HOLD,1'b0 }};
        end    
        assign loadKWrite = insLast[D-1:0];
    endgenerate

    //-------------------------------------------------------------------------
    // Divide Conv unit into groups
    //-------------------------------------------------------------------------
    wire [D-1:0] convDivRowSel;
    wire [8*D-1:0] convUnitDivControl;
    wire [1:0] convUnitDivIns = ins1;
    reg [depth-1:0] convDivIniValue;
    reg [depth-1:0] convDivRowSelection;
        assign convUnitCommonControl = {peConfig,convDivIniValue};
        
    generate
        assign convDivRowSel = 1<<convDivRowSelection;
        assign convUnitRowControl = convDivRowSel;
        for (i = 0; i<D; i=i+1) begin
            // assign convUnitRowControl[(i+1)*(1)-1 -:1] 
            //                     = {convDivRowSel[i]};
            assign convUnitDivControl[8*(i+1)-1-:8] 
                                = {2{insLast[i],convUnitDivIns,1'b0}};
        end
    endgenerate

    always @(posedge CLK) begin
        if (opcode == DIVIDE_CONV_UNIT) begin
            convDivIniValue = ins2;
            convDivRowSelection = ins3;            
        end
    end

    //-------------------------------------------------------------------------
    // Convolution
    //-------------------------------------------------------------------------
    assign convUnitControl = {(D){1'b0,ins1,2'b00,ins2[1:0],1'b0}};
    
    always @(posedge CLK) begin
        case (opcode)
            CONVOLVE: convUnitColumnControl <= convUnitControl;
            DIVIDE_CONV_UNIT: convUnitColumnControl <= convUnitDivControl;
            LOAD_LOCAL_K: convUnitColumnControl <= convUnitLoadKControl;
            LOAD_LOCAL_N: convUnitColumnControl <= convUnitLoadNControl;
            default: 
            convUnitColumnControl <= {(D){8'b00100010}};
        endcase
    end

//-----------------------------------------------------------------------------
// On Chip Buffers
//-----------------------------------------------------------------------------

    assign dataOut = nReadIO_Out;
    reg [Ab-1:0] nWCol1, nWCol2, nWRow1, nWRow2;
    reg [Ab-1:0] nRCol1, nRCol2, nRRow1, nRRow2;
    reg [Ab-1:0] kCol, kRow;
    reg [depth-1:0] nBankSel, kBankSel;
    reg nRBuffWrite, nWBuffWrite;


    //-------------------------------------------------------------------------
    // Neuron Buffer
    //-------------------------------------------------------------------------
    wire [Ab-1:0] nRBufferStep, nWBufferStep;
        assign nRBufferStep = doPooling?neuronStep*P:neuronStep;
        assign nWBufferStep = doPooling?nPooledStep:neuronStep;
    assign nWriteAddress = (nWRow1+nWRow2)*nWBufferStep+nWCol1+nWCol2;
    assign nReadAddress = (nRRow1)*nRBufferStep+nRRow2*neuronStep+nRCol1+nRCol2;
    reg nBuffIOSel, nBuffIOWrite;
    reg [D-1:0] nBuffIOData;
        assign nReadIO_In = {nBuffIOSel,nBuffIOWrite, nBankSel,nBuffIOData};

    always @(posedge CLK) begin
        if (opcode == LOAD_N_BUFFER) begin
            nBuffIOSel = 1;
            nRBuffWrite = 1;
            nBuffIOData = insLast;
        end else if (opcode == READ_N_BUFFER) begin
            nBuffIOSel = 1;
            nRBuffWrite = 0;
            nBuffIOData = 0;
        end else begin
            nRBuffWrite = 0;
            nBuffIOSel = 0;
        end
    end

    //-------------------------------------------------------------------------
    // Kernel Buffer
    //-------------------------------------------------------------------------
    reg kBuffIOSel;
    reg [W-1:0] kBuffIOData;
    wire kBuffWrite = kBuffIOSel;
    assign kBuffAddress = (kRow)*kernelStep + kCol;
        assign kBuffIn = {kBuffIOSel,kBuffWrite,kBankSel,kBuffIOData};

    always @(posedge CLK) begin
        if (opcode == LOAD_K_BUFFER) begin
            kBuffIOSel = 1;
            kBuffIOData = insLast[D-1:0];
        end else begin
            kBuffIOSel = 0;
        end
    end

//-----------------------------------------------------------------------------
// Pooling Unit
//-----------------------------------------------------------------------------

    wire [D*4-1:0] poolingControl;
    reg resetPoolReg;
    reg [D-1:0] poolSelLower;
    reg [D-1:0] poolSelUpper;
    reg [D-1:0] poolWrite;
    reg [D-1:0] poolSelCurrent;

    always @(posedge CLK) begin
        if (opcode == POOL) begin
            doPooling = 1;
        end else begin
            doPooling = 0;
        end
        if (resetPoolReg) begin
            resetPoolReg = 0;
        end
    end

    generate
        for (i = 0; i<D; i=i+1) begin
            assign poolingControl[(i+1)*4-1 -:4] = resetPoolReg? 4'b1000
            :{poolWrite[i],poolSelUpper[i],poolSelCurrent[i],poolSelLower[i]};
        end
        assign poolUnitControl = poolingControl;
    endgenerate

//-----------------------------------------------------------------------------
// ****
//-----------------------------------------------------------------------------

always @(posedge CLK) begin
    case (opcode)
        LOAD_K_BUFFER: begin
                nWBuffWrite = 0;
                case (ins1) // kernel control
                    INIT: begin kCol=0; kRow=0; end
                    INCR: begin kCol=kCol+1; end
                    JUMP: begin kCol=0;kRow=kRow+1;end
                endcase
                case (ins2[1:0]) // kernel bank select control
                    INIT: begin kBankSel=0; end
                    INCR: begin kBankSel=kBankSel+1; end
                endcase
            end
        LOAD_N_BUFFER: begin
                nWBuffWrite = 0;
                case (ins1) // neuron buffer control
                    INIT: begin nRRow1=0;nRRow2=0;nRCol1=0;nRCol2=0; end
                    INCR: begin nRCol1=nRCol1+1; end
                    JUMP: begin nRRow1=nRRow1+1;nRCol1=0; end
                endcase
                case (ins2[1:0]) // neuron bank select control
                    INIT: begin nBankSel=0; end
                    INCR: begin nBankSel=nBankSel+1; end
                endcase
            end
        READ_N_BUFFER: begin
                nWBuffWrite = 0;
                case (ins1) // neuron buffer control
                    INIT: begin nRRow1=0;nRRow2=0;nRCol1=0;nRCol2=0; end
                    INCR: begin nRCol1=nRCol1+1; end
                    JUMP: begin nRRow1=nRRow1+1;nRCol1=0; end
                endcase
                case (ins2[1:0]) // neuron bank select control
                    INIT: begin nBankSel=0; end
                    INCR: begin nBankSel=nBankSel+1; end
                endcase
            end
        LOAD_LOCAL_K: begin
                nWBuffWrite = 0;
                case (ins1) // kernel Buffer Control
                    INIT: begin kRow=0;kCol=0; end
                    INCR: begin kCol=kCol+1; end
                    JUMP: begin kCol=0;kRow=kRow+1; end
                endcase
                case (ins2[1:0]) // kernel Distribution bank control
                    INIT: begin kernelBuffBankSelect=0; end
                    INCR: begin kernelBuffBankSelect=kernelBuffBankSelect+1;end
                endcase
            end
        LOAD_LOCAL_N: begin
                nWBuffWrite = 0;
                case (ins1)// neuron Buffer Control
                    INIT: begin kRow=0;kCol=0; end
                    INCR: begin kCol=kCol+1; end
                    JUMP: begin kCol=0; kRow=kRow+1; end
                endcase
            end
        CONVOLVE: begin
                nWBuffWrite = 1;
                case (ins1) // Effect of kernel control
                    INIT: begin nWRow2=0;nWCol2=0; end
                    INCR: begin nWCol2=nWCol2-1; end
                    JUMP: begin nWRow2=nWRow2-1;nWCol2=0; end
                endcase
                case (ins2[1:0]) // Effect of neuron Control
                    INIT: begin nWRow1=0;nWCol1=0; end
                    INCR: begin nWCol1=nWCol1+1; end
                    JUMP: begin nWCol1=0;nWRow1=nWRow1+1; end
                endcase
            end
        RESET_POOLING_REG: begin
                nWBuffWrite = 0;
                resetPoolReg = 1;
            end
        POOL: begin
                nWBuffWrite = 1;
                case (ins3[1:0])
                    2'b00: begin poolSelLower     = insLast; poolWrite=0; end
                    2'b10: begin poolSelCurrent   = insLast; poolWrite=0; end
                    2'b10: begin poolSelUpper     = insLast; poolWrite=0; end
                    2'b11: poolWrite        = insLast;
                endcase
                case (ins1)
                    INIT: begin nRRow1=0; nRCol1=0; nWRow1=0; nWRow2=0;
                                nWCol1=0; nWCol2=0; end
                    INCR: begin nRCol1=nRCol1+1; nWCol1=nWCol1+1; end
                    JUMP: begin nRRow1=nRRow1+1; nWRow1=nWRow1+1; nRCol1=0;
                                nWCol1=0; end
                endcase
            end
    endcase
end

endmodule
