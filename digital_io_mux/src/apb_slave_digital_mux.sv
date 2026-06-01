// File name:   apb_slave_digital_mux.sv
// Created:     6/28/2022
// Author:      Xinyu Yang
// Description: APB Slave interface for the digital multiplexer

module apb_slave_digital_mux
#(
    //original: 10; 2; 1; 1; 
    parameter NUM_PINS = 16, // max:32
    parameter NUM_FUNC = 2, // max:4
    parameter NUM_BITS = 2, // max:2
    parameter NUM_REGS = 1 // max:2
)
(
    input logic PCLK,
    input logic PRESETn,
    input logic PSEL,
    input logic PENABLE,
    input logic PWRITE,
    output logic PSLVERR,
    output logic PREADY,
    // input logic PWAKEUP,
    // input logic [2:0] PPROT,
    input logic [3:0] PSTRB,
    input logic [31:0] PADDR,
    input logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic [NUM_PINS * NUM_BITS - 1:0] fsel
);

    logic REN; // 1 bit, since max # of registers = 2
    logic [1:0] WEN; // # of Bits fixed = 2
    logic [31:0] FSR0_IN, FSR0_OUT, FSR1_IN, FSR1_OUT;
    logic [31:0] PRE_READ;

    assign PREADY = 1'b1;

    always_comb begin : controller
        // default
        REN = 1'b0;
        WEN = 2'b0;
        PSLVERR = 1'b0;

        if (PSEL == 1'b1) begin
            if (PWRITE == 1) begin // write transfer
                if (PADDR == 32'h00005000) begin
                    WEN[0] = 1'b1;
                end else if (PADDR == 32'h00005004 && NUM_REGS == 2) begin
                    WEN[1] = 1'b1;
                end else begin
                    PSLVERR = 1'b1;
                end
            end else if (PWRITE == 0) begin // read transfer
                if (PSTRB == 4'b0) begin
                    if (PADDR == 32'h00005000) begin
                        REN = 1'b0;
                    end else if (PADDR == 32'h00005004 && NUM_REGS == 2) begin
                        REN = 1'b1;
                    end else begin
                        PSLVERR = 1'b1;
                    end
                end else begin
                    PSLVERR = 1'b1;
                end
            end
        end
    end

    always_comb begin : writeData
        // default
        FSR0_IN = FSR0_OUT;
        FSR1_IN = FSR1_OUT;

        if (WEN[0] == 1) begin
            if (PSTRB[0] == 1'b1)
                FSR0_IN[7:0] = PWDATA[7:0];
            if (PSTRB[1] == 1'b1)
                FSR0_IN[15:8] = PWDATA[15:8];
            if (PSTRB[2] == 1'b1)
                FSR0_IN[23:16] = PWDATA[23:16];
            if (PSTRB[3] == 1'b1)
                FSR0_IN[31:24] = PWDATA[31:24];
        end 

        if (NUM_REGS == 2) begin
            if (WEN[1] == 1) begin
                if (PSTRB[0] == 1'b1)
                    FSR1_IN[7:0] = PWDATA[7:0];
                if (PSTRB[1] == 1'b1)
                    FSR1_IN[15:8] = PWDATA[15:8];
                if (PSTRB[2] == 1'b1)
                    FSR1_IN[23:16] = PWDATA[23:16];
                if (PSTRB[3] == 1'b1)
                    FSR1_IN[31:24] = PWDATA[31:24];
            end 
        end
    end

    always_ff @(posedge PCLK, negedge PRESETn) begin : writeDataff
        if (PRESETn == 1'b0) begin
            FSR0_OUT <= '0;
            FSR1_OUT <= '0;
        end else begin
            FSR0_OUT <= FSR0_IN;
            FSR1_OUT <= FSR1_IN;
        end
    end

    always_comb begin : readData
        // default
        PRE_READ = FSR0_OUT;

        if (REN == 1 && NUM_REGS == 2) begin
            PRE_READ = FSR1_OUT;
        end 
    end

    always_ff @(posedge PCLK, negedge PRESETn) begin : readDataff
        if (PRESETn == 1'b0) begin
            PRDATA <= '0;
        end else begin
            PRDATA <= PRE_READ;
        end
    end

    logic [63:0] totalfsel;
    assign totalfsel = {FSR1_OUT, FSR0_OUT};

    always_comb begin : controlFSEL
        fsel = totalfsel[NUM_PINS * NUM_BITS - 1:0];
    end

endmodule