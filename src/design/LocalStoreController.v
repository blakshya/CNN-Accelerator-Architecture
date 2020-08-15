`timescale 1ns / 1ps
/*
 * Local controller within each PE
 *
 * Ports
 */
/*
 * Use INCR for loading
 */
module LocalStoreController #(parameter 
        depth = 2,
        A = 7,
        D = (1<<depth),
        W = 16
    )(
        input wire [5:0] controlSignal,
        input wire [2*depth+2*A-1:0] peConfig,
        input wire initPESelect,
        input wire [depth-1:0] initSettings,
        output wire [A-1:0] kernelAddress,
        output wire [A-1:0] neuronAddress,
        input wire CLK
    );

    wire [2*depth+A-1:0] kernelConfig;
    wire [A-1:0] neuronConfig;
        assign {kernelConfig, neuronConfig} = peConfig;

    wire [2:0] kernelControl, neuronControl;
        assign {kernelControl, neuronControl} = controlSignal;
    
    kernelFSM #(.depth(depth),.A(A)) kernelStoreController(
        .control(kernelControl),
        .initPESelect(initPESelect),
        .kernelConfig(kernelConfig),
        .kernelAddress(kernelAddress),
        .write(kernelWrite),
        .setInput(initSettings),
        .CLK(CLK)
    );

    neuronFSM #(.depth(depth),.A(A)) neuronStoreController(
        .control(neuronControl),
        .initPESelect(initPESelect),
        .neuronConfig(neuronConfig),
        .neuronAddress(neuronAddress),
        .setInput(initSettings),
        .CLK(CLK)
    );

endmodule


module kernelFSM #(parameter    
        depth = 2,
        D = 1<<depth,
        A = 7
    )(
        input wire [2:0] control,
        input wire initPESelect,
        input wire [depth*2+A-1:0] kernelConfig,
        input wire [depth-1:0] setInput,
        input wire write,
        output wire[A-1:0] kernelAddress,
        input wire CLK
    );
parameter INIT = 3'b000;
parameter HOLD = 3'b001;
parameter INCR = 3'b010;
parameter JUMP = 3'b011;

parameter SET_K_ROW_OFST = 3'b100 ;
parameter SET_K_COL_OFST = 3'b101 ;
parameter SET_N_ROW_OFST = 3'b110 ;
parameter SET_N_COL_OFST = 3'b111 ;

    wire [depth-1:0] Tc, Tr;
    wire [A-1:0] kernelStep;
    assign {Tc,Tr,kernelStep} = kernelConfig;

    reg [A-1:0] row, col;
    reg [depth-1:0] rowOffset, columnOffset;

    initial begin
        row = 0;
        col = 0;
        rowOffset = 0;
        columnOffset=0;
    end

    assign kernelAddress = (row+rowOffset)*kernelStep+col+columnOffset;

    always @(negedge CLK) begin
        case (control)
            INIT    : begin
                    row = 0;
                    col = 0;
                end
            // HOLD    : begin
            //         // row = row;
            //         col = col;
            //     end
            INCR    : begin
                    // row = row;
                    if (write) begin
                        col = col + 1;
                    end else begin
                        col = col + Tc;
                    end
                end
            JUMP    : begin
                    row = row + Tr;
                    col = 0;
                end
            SET_K_ROW_OFST  : begin
                    if (initPESelect) begin
                        rowOffset = setInput;                        
                    end
                end
            SET_K_COL_OFST  : begin
                    if (initPESelect) begin
                        columnOffset =setInput;                        
                    end
                end
        endcase
    end
endmodule

module neuronFSM #( parameter
        depth = 2,
        A = 7
    )(
        input wire [2:0] control,
        input wire initPESelect,
        input wire [A-1:0] neuronConfig,
        input wire [depth-1:0] setInput,
        output wire[A-1:0] neuronAddress,
        input wire CLK
    );
parameter INIT = 3'b000;
parameter HOLD = 3'b001;
parameter INCR = 3'b010;
parameter JUMP = 3'b011;

parameter SET_K_ROW_OFST = 3'b100 ;
parameter SET_K_COL_OFST = 3'b101 ;
parameter SET_N_ROW_OFST = 3'b110 ;
parameter SET_N_COL_OFST = 3'b111 ;    

    wire [A-1:0] nStep = neuronConfig;

    reg [A-1:0] row, col;
    reg [depth-1:0] rowOffset, columnOffset;

    initial begin
        row = 0;
        col = 0;
        rowOffset = 0;
        columnOffset = 0;
    end

    assign neuronAddress = (row+rowOffset)*nStep+col+columnOffset;

    always @(negedge CLK) begin
        case (control)
            INIT    : begin
                    row = 0;
                    col = 0;
                end
            // HOLD    : begin
            //         // row = row;
            //         col = col;
            //     end
            INCR    : begin
                    // row = row;
                    col = col + 1;
                end
            JUMP    : begin
                    row = row + 1;
                    col = 0;
                end
            SET_N_ROW_OFST  : begin
                    if (initPESelect) begin
                       rowOffset = setInput; 
                    end
                end
            SET_N_COL_OFST  : begin
                    if (initPESelect) begin
                        columnOffset = setInput;                        
                    end
                end
        endcase
    end

endmodule
