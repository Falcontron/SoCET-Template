// File name:   top_level_digital_mux_wrapper.sv
// Created:     4/22/2023
// Author:      Rohan Gangaraju
// Description: Top level wrapper for the digital multiplexer

module top_level_digital_mux_wrapper#(
    parameter NUM_PINS = 16, // max:32
    parameter NUM_FUNC = 2, // max:4
    parameter NUM_BITS = 2, // max:2
    parameter NUM_REGS = 1 // max:2
)(
    input logic [NUM_PINS * NUM_FUNC - 1:0] from_module,
    input logic [NUM_PINS * NUM_FUNC - 1:0] output_enable,
    output logic [NUM_PINS * NUM_FUNC - 1:0] to_module,
    input logic [NUM_PINS - 1:0] to_module_iopad,
    output logic [NUM_PINS - 1:0] from_module_ff,
    output logic [NUM_PINS - 1:0] output_en_ff,

    apb_if.completer apbif
);

    top_level_digital_mux top_digital_mux (.CLK(apbif.PCLK), .RESETn(apbif.PRESETn), 
                                         .PSEL(apbif.PSEL), .PENABLE(apbif.PENABLE), .PWRITE(apbif.PWRITE), .PADDR(apbif.PADDR), 
                                         .PWDATA(apbif.PWDATA), .PRDATA(apbif.PRDATA), .PSLVERR(apbif.PSLVERR), .PREADY(apbif.PREADY), 
                                         .PSTRB(apbif.PSTRB), .from_module(from_module), .output_enable(output_enable), .to_module(to_module),
                                         .to_module_iopad(to_module_iopad), .from_module_ff(from_module_ff), .output_en_ff(output_en_ff));
                                         
    defparam top_digital_mux.NUM_PINS = NUM_PINS;
    defparam top_digital_mux.NUM_FUNC = NUM_FUNC;
    defparam top_digital_mux.NUM_BITS = NUM_BITS;
    defparam top_digital_mux.NUM_REGS = NUM_REGS;

endmodule