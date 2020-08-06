`timescale 1ns / 1ps


module MasterController #(parameter
        depth = 2,
        D = (1<<depth),
        Ab = 11,
        Al = 7,
        W = 16,
        insW = (2 > depth)? 2: depth,
        insD = (D>W)?D:W,
        insWidth = 4+2+2*insW+insD

    )(
        input wire [W-1:0] dataIn,
        input wire [insWidth-1:0] instruction,
        output wire [W-1:0]dataOut,

        output wire [W-1+depth+2 :0] kBuffIn,
        output wire [Ab-1:0] kBuffAddress,
        output wire [2*depth-1:0] kernelDistControl,

        output wire [Ab-1:0] nReadAddress,
        output wire [Ab-1:0] nWriteAddress,

        output wire [W-1+depth+2 :0] nReadIO_In,
        output wire [W-1:0] nReadIO_Out,

        output reg [D*8-1:0] convUnitColumnControl,
        output wire [(depth+1)*D-1:0] convUnitRowControl,
        output wire [2*depth+2*Al-1:0] convUnitCommonControl,

        output wire doPooling,
        output wire [D*4-1:0] poolUnitControl,

        input wire CLK
    );

    /*
     * Currently Empty
     * Someone pls help
     */

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
    localparam SET_POOL_USE_LOWER   = 4'b1110;
    localparam SET_POOL_USE_UPPER   = 4'b1111;

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
// Common Repetitive stuff
//-----------------------------------------------------------------------------

    reg [depth-1:0] Tr;     // ins1 = 2'b00, ins2 = 2'b00
    reg [depth-1:0] Tc;     // ins1 = 2'b00, ins2 = 2'b01
    reg [Al-1:0] kernelStep;// ins1 = 2'b00, ins2 = 2'b10
    reg [Al-1:0] neuronStep;// ins1 = 2'b00, ins2 = 2'b11
    reg [Al-1:0] P;         // ins1 = 2'b01, ins2 = 2'b00

    always @(posedge CLK) begin
        if (opcode == LOAD_CONSTANTS) begin
            Tr <= (ins1 == 2'b00 && ins2 ==2'b00)?insLast:Tr;
            Tc <= (ins1 == 2'b00 && ins2 ==2'b01)?insLast:Tc;
            kernelStep <= (ins1 == 2'b00 && ins2 ==2'b10)?insLast:kernelStep;
            neuronStep <= (ins1 == 2'b00 && ins2 ==2'b11)?insLast:neuronStep;
            P <= (ins1 == 2'b01 && ins2 ==2'b00)?insLast:P;
        end
    end

//-----------------------------------------------------------------------------
// Kernel Buffer Distribution
//-----------------------------------------------------------------------------

    wire [depth-1:0] Trc; 
        assign Trc = Tr * Tc;
    reg [depth-1:0] bankSelect;
    // wire [2*depth-1:0] kernelDistControl;
        assign kernelDistControl = {Trc,bankSelect};

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
        assign convUnitCommonControl = peConfig;

    //-------------------------------------------------------------------------
    // Load Local Stores - NEURON
    //-------------------------------------------------------------------------
    wire [8*D-1:0] convUnitLoadNControl;
    generate
        for (i = 0; i<D; i=i+1) begin
            assign convUnitLoadNControl[8*(i+1)-1-:8] = {1'b0, HOLD,2'b00,ins1,1'b1};
        end
    endgenerate
    //-------------------------------------------------------------------------
    // Load Local Stores - KERNEL
    //-------------------------------------------------------------------------
    wire [D-1:0] loadKWrite;
    wire [8*D-1:0] convUnitLoadKControl;
    generate
        for (i = 0; i<D; i=i+1) begin
            assign convUnitLoadKControl[8*(i+1)-1-:8] = {1'b0, ins1,loadKWrite[i],1'b0,HOLD,1'b0 };
        end    
        assign loadKWrite = (opcode == LOAD_LOCAL_K)?insLast:0;
    endgenerate

    always @(posedge CLK) begin
        if (opcode == LOAD_LOCAL_K) begin
            case (ins2)
                INIT: bankSelect <= 0;
                INCR: bankSelect<= bankSelect +1; 
                default: bankSelect <= bankSelect;
            endcase
        end else begin
            bankSelect <= 0;
        end
    end

    //-------------------------------------------------------------------------
    // Divide Conv unit into groups
    //-------------------------------------------------------------------------
    wire [(depth)*D-1:0] iniSetting;
    wire [D-1:0] convDivRowSel;
    wire [8*D-1:0] convUnitDivControl;
    wire [1:0] conDivIns = (opcode == DIVIDE_CONV_UNIT)?ins1:HOLD;
    wire [depth-1:0] covDivIniSet = (opcode == DIVIDE_CONV_UNIT)?ins2:0;
    wire [depth-1:0] convDivRowSelection = (opcode == DIVIDE_CONV_UNIT)?ins3:0;
        
    generate
        assign convDivRowSel = 1<<convDivRowSelection;
        for (i = 0; i<D; i=i+1) begin
            // assign iniSetting[(i+1)*depth-1-:depth] = {(D){covDivIniSet}};
            // assign convUnitRowControl[(i+1)*(depth+1)-1 -:depth+1] = {iniSetting[(i+1)*depth-1-:depth],convDivRowSel[i]};
            assign convUnitRowControl[(i+1)*(depth+1)-1 -:depth+1] = {covDivIniSet,convDivRowSel[i]};
            assign convUnitDivControl[8*(i+1)-1-:8] = {2{insLast[i]?1'b1:1'b0,conDivIns,1'b0}};
        end
    endgenerate

    //-------------------------------------------------------------------------
    // Convolution
    //-------------------------------------------------------------------------
    assign convUnitControl = (opcode == CONVOLVE)? {(D){1'b0,ins1,2'b00,ins2[1:0],1'b0}}:{(D){8'b00100010}};
    
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
// Pooling Unit
//-----------------------------------------------------------------------------

    wire [D*4-1:0] poolingControl;
    reg [D-1:0] selLower;
    reg [D-1:0] selUpper;
    wire poolWrite[D-1:0], poolUseCurrent[D-1:0];

    always @(posedge CLK) begin
        selLower <= (opcode == SET_POOL_USE_LOWER)? insLast : selLower;
        selUpper <= (opcode == SET_POOL_USE_UPPER)? insLast : selUpper;
    end

    generate
        for (i = 0; i<D; i=i+1) begin
            assign poolingControl[(i+1)*4-1 -:4] = {poolWrite[i],selUpper[i],poolUseCurrent[i],selLower[i]};
            assign poolUseCurrent[i] = doPooling?insLast[i]:0;
        end
        assign poolUnitControl = poolingControl;
        assign doPooling = (opcode == POOL);
    endgenerate

//-----------------------------------------------------------------------------
// Write To Buffers
//-----------------------------------------------------------------------------

    reg [Ab-1:0] nCol1, nCol2, nRow1, nRow2;
    reg [Ab-1:0] kCol, kRow;
    wire [Ab-1:0] bufferStep = neuronStep;
    reg [depth-1:0] nBankSel, kBankSel;

    always @(posedge CLK) begin
        case (opcode)
            LOAD_N_BUFFER: begin
                case (ins1)
                    INIT: begin
                        nCol1 = 0;
                        nCol2 = 0;
                        nRow1 = 0;
                        nRow2 = 0;
                        end
                    INCR: begin
                        nCol1 = nCol1 + 1;
                        end
                    JUMP : begin
                        nRow1 = nRow1 +1;
                        end
                endcase
                case (ins2[1:0])
                    INIT: begin
                        nBankSel = 0;
                        end
                    INCR: begin
                        nBankSel = nBankSel+1;
                        end
                endcase
                end
            LOAD_K_BUFFER: begin
                case (ins1)
                    INIT: begin
                        kCol = 0;
                        kRow = 0;
                        end
                    INCR: begin
                        kCol = kCol +1;
                        end
                    JUMP: begin
                        kRow = kRow+1;
                        end
                endcase
                case (ins2[1:0])
                    INIT:  begin
                        kBankSel = 0;
                        end
                    INCR: begin
                        kBankSel = kBankSel +1;
                        end
                endcase
                end
        endcase
    end

    //-------------------------------------------------------------------------
    // Neuron Buffer
    //-------------------------------------------------------------------------
    assign nWriteAddress = (nRow1+nRow2)*bufferStep+nCol1+nCol2;
    reg nBuffIOSel;
    reg [D-1:0] nBuffIOData;


    always @(posedge CLK) begin
        if (opcode == LOAD_N_BUFFER) begin
            nBuffIOSel = 1;
            nBuffIOData = insLast;
        end else begin
            nBuffIOSel = 0;
            nBuffIOData = 0;
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
            kBuffIOData = insLast;
        end else begin
            kBuffIOSel = 0;
            kBuffIOData = 0;
        end
    end

//-----------------------------------------------------------------------------
// Read Neuron Buffer
//-----------------------------------------------------------------------------

endmodule
  