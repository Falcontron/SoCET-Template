module SRAM_wrapper #(
    parameter NUM_CHIP = 2,
    parameter ADDR_WIDTH = 18, // for the memory chip
    parameter DATA_WIDTH = 16,
    parameter NREGS = 4096
)(
    input logic CLK,
    input logic n_RST,
    bus_protocol_if.peripheral_vital prif,
    bus_protocol_if.peripheral_hint hintif
);
    logic n_OE [NUM_CHIP-1:0];
    logic n_CE [NUM_CHIP-1:0];
    logic n_WE [NUM_CHIP-1:0];
    logic n_LB [NUM_CHIP-1:0];
    logic n_UB [NUM_CHIP-1:0];
    logic iopad_n_oe; //share one n_oe signal for all io pads for data pins
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;

    logic [DATA_WIDTH-1:0] sim_data_line;

    wire [DATA_WIDTH-1:0] wire_data;
    assign wire_data = sim_data_line;

    assign sim_data_line = 'bz; // Need this?

    sram_controller #(
        .MEMCHIP("IS61WV25616BLL-10TL"),
        .NUM_CHIP(NUM_CHIP),
        .ADDR_WIDTH(ADDR_WIDTH), // for the memory chip
        .DATA_WIDTH(DATA_WIDTH)
    ) SRAM_controller (
        .CLK(CLK),
        .n_RST(n_RST),
        .prif(prif),
        .hintif(hintif),
        .n_OE(n_OE),
        .n_CE(n_CE),
        .n_WE(n_WE),
        .n_LB(n_LB),
        .n_UB(n_UB),
        .iopad_n_oe(iopad_n_oe),
        .addr(addr),
        .wdata(wdata),
        .rdata_in(rdata)
    );

    io_pad SRAM_io_pad (
        .oe_n(iopad_n_oe),
        .wdata(wdata),
        .rdata(rdata),
        .data(wire_data)
    );

    sram_sim #(
        .MEMCHIP("IS61WV25616BLL-10TL"),
        .ADDR_WIDTH(ADDR_WIDTH), // for the memory chip
        .DATA_WIDTH(DATA_WIDTH),
        .NREGS(NREGS),
        .ORDER(0)
    ) SRAM_chip_1 (
        .n_OE(n_OE[0]),
        .n_CE(n_CE[0]),
        .n_WE(n_WE[0]),
        .n_LB(n_LB[0]),
        .n_UB(n_UB[0]),
        .addr(addr),
        .DOUT(wire_data)
    );

    sram_sim #(
        .MEMCHIP("IS61WV25616BLL-10TL"),
        .ADDR_WIDTH(ADDR_WIDTH), // for the memory chip
        .DATA_WIDTH(DATA_WIDTH),
        .NREGS(NREGS),
        .ORDER(1)
    ) SRAM_chip_2 (
        .n_OE(n_OE[1]),
        .n_CE(n_CE[1]),
        .n_WE(n_WE[1]),
        .n_LB(n_LB[1]),
        .n_UB(n_UB[1]),
        .addr(addr),
        .DOUT(wire_data)
    );
    
endmodule