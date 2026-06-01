// File name:   top_level_digital_mux.sv
// Created:     6/28/2022
// Author:      Xinyu Yang
// Description: Top level for the digital multiplexer

module top_level_digital_mux
#(
    parameter NUM_PINS = 16, // max:32
    parameter NUM_FUNC = 2, // max:4
    parameter NUM_BITS = 2, // max:2
    parameter NUM_REGS = 1 // max:2
)
(
    input logic CLK,
    input logic RESETn,
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

    input logic [NUM_PINS * NUM_FUNC - 1:0] from_module,
    input logic [NUM_PINS * NUM_FUNC - 1:0] output_enable,
    output logic [NUM_PINS * NUM_FUNC - 1:0] to_module,
    input logic [NUM_PINS - 1:0] to_module_iopad,
    output logic [NUM_PINS - 1:0] from_module_ff,
    output logic [NUM_PINS - 1:0] output_en_ff
);

    logic [NUM_PINS * NUM_BITS - 1:0] fsel;

    apb_slave_digital_mux apb_digit_mux (.PCLK(CLK), .PRESETn(RESETn), 
                                         .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE), .PADDR(PADDR), 
                                         .PWDATA(PWDATA), .PRDATA(PRDATA), .fsel(fsel),
                                         .PSLVERR(PSLVERR), .PREADY(PREADY), .PSTRB(PSTRB));
    defparam apb_digit_mux.NUM_PINS = NUM_PINS;
    defparam apb_digit_mux.NUM_FUNC = NUM_FUNC;
    defparam apb_digit_mux.NUM_BITS = NUM_BITS;
    defparam apb_digit_mux.NUM_REGS = NUM_REGS;

    genvar i;
    generate 
        for (i = 0; i < NUM_PINS; i = i+1) begin : g_pin_mux
            digital_mux # (
                .NUM_FUNC(NUM_FUNC), 
                .NUM_BITS(NUM_BITS)
            ) 
            IX ( 
                .CLK(CLK), .RESETn(RESETn),
                .from_module(from_module[(i+1)*NUM_FUNC-1:i*NUM_FUNC]), .to_module(to_module[(i+1)*NUM_FUNC-1:i*NUM_FUNC]), 
                .output_enable(output_enable[(i+1)*NUM_FUNC-1:i*NUM_FUNC]), .fsel(fsel[(i+1)*NUM_BITS-1:i*NUM_BITS]),
                .to_module_iopad(to_module_iopad[i]), .from_module_ff(from_module_ff[i]), .output_en_ff(output_en_ff[i])
            );
        end
    endgenerate


endmodule
