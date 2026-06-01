`define __AFTx07_WRAPPER__

`include "core_interrupt_if.vh"
`include "aftx07_macros.vh"

module sync_wrapper #(
    parameter WIDTH = 16,
    parameter bit RESET_STATE = 1'b1,
    parameter int STAGES = 2
) (
    input CLK,
    input logic nRST,
    input [WIDTH-1:0] async_in,
    output logic [WIDTH-1:0] sync_out
);
    genvar i;
    generate
        for (i = 0; i < WIDTH; i++) begin : sync_gen
            socetlib_synchronizer #(
                .STAGES(STAGES),
                .RESET_STATE(RESET_STATE)
            ) digilib_sync (
                .CLK(CLK),
                .nRST(nRST),
                .async_in(async_in[i]),
                .sync_out(sync_out[i])
            );
        end
    endgenerate
endmodule

module async_reset_sync (
    input CLK,
    input asyncrst_n,
    output logic rst_n
);
    logic rff;

    always_ff @(posedge CLK, negedge asyncrst_n) begin
        if(!asyncrst_n) begin
            {rst_n, rff} <= 2'b0;
        end else begin
            {rst_n, rff} <= {rff, 1'b1};
        end
    end
endmodule

module aftx07_wrapper #(
    parameter int GPIO_PINS_PER_PORT = 8,
    parameter int BOOT_PINS = 3,
    parameter int PWM_CHANNELS = 2,
    parameter int IO_MUX_NUM_PINS = 32,
    parameter int NUM_CHIP = 2,
    parameter int ADDR_WIDTH = 18,
    parameter int DATA_WIDTH = 16,
    parameter int FLIP_OE = 0
)(
    input HCLK,
    input PCLK,
    input nRST,
    input uart_rx,
    output logic uart_tx,
    input [BOOT_PINS-1 : 0] boot_in,
    output logic [BOOT_PINS-1 : 0] boot_out,
    output logic [BOOT_PINS-1 : 0] boot_oe,
    input [IO_MUX_NUM_PINS-1:0] io_mux_to_module_iopad,
    output logic [IO_MUX_NUM_PINS-1:0] io_mux_from_module_ff,
    output logic [IO_MUX_NUM_PINS-1:0] io_mux_output_en_ff,
    // external SRAM ICs connections
    output logic n_OE [NUM_CHIP-1:0],
    output logic n_CE [NUM_CHIP-1:0],
    output logic n_WE [NUM_CHIP-1:0],
    output logic n_LB [NUM_CHIP-1:0],
    output logic n_UB [NUM_CHIP-1:0],
    output logic [ADDR_WIDTH-1:0] addr,
    output logic iopad_n_oe, //share one n_oe signal for all io pads for data pins
    output logic [DATA_WIDTH-1:0] wdata,
    input logic [DATA_WIDTH-1:0] rdata
);

    logic ahb_nRST, apb_nRST;

    async_reset_sync ahb_reset_sync (HCLK, nRST, ahb_nRST);
    async_reset_sync apb_reset_sync (PCLK, nRST, apb_nRST);

    // Define the signals that get feed into AFTx07, should append "sync" before the signal name
    logic sync_uart_rx;
    `ADD_SYNC(uart_rx, 0, 2, HCLK, ahb_nRST)

    logic [BOOT_PINS-1 : 0] sync_boot_in;
    logic [BOOT_PINS-1 : 0] next_boot_out, next_boot_oe;
    `ADD_MULTI_SYNC(boot_in, BOOT_PINS, 0, 2, PCLK, apb_nRST)

    // Output signals should be driven by a ff
    logic nxt_uart_tx;
    logic [IO_MUX_NUM_PINS-1:0] nxt_io_mux_from_module_ff, nxt_io_mux_output_en_ff;

    always_ff @(posedge HCLK, negedge ahb_nRST) begin : LATCH_AHB_SIGNALS
        if (!ahb_nRST) begin
            uart_tx  <= '0;
        end else begin
            uart_tx  <= nxt_uart_tx;
        end
    end

    always_ff @( posedge PCLK, negedge apb_nRST ) begin : LATCH_APB_SIGNALS
        if (!apb_nRST) begin
            boot_out <= 1'b0;
            boot_oe <= FLIP_OE ? '1 : '0;
            io_mux_from_module_ff <= '0;
            io_mux_output_en_ff <= FLIP_OE ? '1 : 0;
        end else begin
            boot_out <= next_boot_out;
            boot_oe <= FLIP_OE ? ~next_boot_oe : next_boot_oe;
            io_mux_from_module_ff <= nxt_io_mux_from_module_ff;
            io_mux_output_en_ff <= FLIP_OE ? ~nxt_io_mux_output_en_ff : nxt_io_mux_output_en_ff;
        end
    end

    aftx07 AFTX07(
        .HCLK(HCLK),
        .PCLK(PCLK),
        .ahb_nRST(ahb_nRST),
        .apb_nRST(apb_nRST),
        .uart_rx(sync_uart_rx),
        .uart_tx(nxt_uart_tx),
        .boot_in(sync_boot_in),
        .boot_out(next_boot_out),
        .boot_oe(next_boot_oe),
        .io_mux_to_module_iopad(io_mux_to_module_iopad),  // IO mux has internal synchronizers
        .io_mux_from_module_ff(nxt_io_mux_from_module_ff),
        .io_mux_output_en_ff(nxt_io_mux_output_en_ff),
        .n_OE(n_OE),
        .n_CE(n_CE),
        .n_WE(n_WE),
        .n_LB(n_LB),
        .n_UB(n_UB),
        .addr(addr),
        .iopad_n_oe(iopad_n_oe),
        .wdata(wdata), 
        .rdata(rdata)
    );

endmodule