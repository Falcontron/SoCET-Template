module aftx07_fpga(
    input logic CLOCK_50,
    input logic [3:0] KEY,
    output logic [8:0] LEDG,
    output logic [17:0] LEDR,
    inout logic [31:0] GPIO,  // GPIO[31:0] on FPGA
    input logic UART_RX,  // GPIO[32]
    output logic UART_TX,  // GPIO[33]
    inout logic [2:0] BOOT_PIN,  // GPIO[2:0]
    output logic n_OE [1:0],
    output logic n_CE [1:0],
    output logic n_WE [1:0],
    output logic n_LB [1:0],
    output logic n_UB [1:0],
    output logic [17:0] addr,
    inout wire [15:0] wire_data
);

    localparam DATA_WIDTH = 16;

    initial begin
        auto_nRST = '0;
        rst_count = '0;
        cgen = '0;
    end

    // Clock divider
    logic cgen;
    logic [3:0] rst_count;
    logic auto_nRST;
    logic nRST;

    always_ff @(posedge CLOCK_50) begin
        cgen <= ~cgen;
    end

    always_ff @(posedge CLOCK_50) begin
        if(rst_count != 4'hF) begin
            rst_count <= rst_count + 4'h1;
            auto_nRST <= '0;
        end else begin
            auto_nRST <= '1;
        end
    end

    logic uart_rx, uart_tx;
    logic [31:0] io_mux_in, io_mux_out, io_mux_oe;
    logic [31:0] int_io_mux_in, int_io_mux_out;
    logic [2:0] boot_in, boot_out, boot_oe, int_boot_in;

    logic iopad_n_oe;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;

    io_pad SRAM_io_pad (
        .oe_n(iopad_n_oe),
        .wdata(wdata),
        .rdata(rdata),
        .data(wire_data)
    );


`ifndef WRAPPER

    aftx07 AFTX07(
        .CLK(cgen),
        .nRST(nRST),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .boot_in(boot_in),
        .boot_out(boot_out),
        .boot_oe(boot_oe),
        .io_mux_to_module_iopad(io_mux_in),
        .io_mux_from_module_ff(io_mux_out),
        .io_mux_output_en_ff(io_mux_oe),
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

`else

    aftx07_wrapper AFTX07(
        .CLK(cgen),
        .nRST(nRST),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .boot_in(boot_in),
        .boot_out(boot_out),
        .boot_oe(boot_oe),
        .io_mux_to_module_iopad(io_mux_in),
        .io_mux_from_module_ff(io_mux_out),
        .io_mux_output_en_ff(io_mux_oe),
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

`endif

    /*
    // -------------------------------------
    // For using KEY[0] as gpio[7] (io_mux[7]) interrupt
    genvar i;
    generate
        for (i = 0; i < 7; i++) begin : bidir_gen_1
            assign GPIO[i] = io_mux_oe[i] ? int_io_mux_out[i] : 1'bZ;
        end
        for (i = 8; i < 32; i++) begin : bidir_gen_2
            assign GPIO[i] = io_mux_oe[i] ? int_io_mux_out[i] : 1'bZ;
        end
    endgenerate
    assign io_mux_in[6:0] = int_io_mux_in[6:0];
    assign io_mux_in[31:8] = int_io_mux_in[31:8];

    always_ff @(posedge cgen) begin
        int_io_mux_out <= io_mux_out;
        int_io_mux_in[6:0] <= GPIO[6:0];
        int_io_mux_in[31:8] <= GPIO[31:8];
        int_boot_in <= BOOT_PIN;
    end
    assign boot_in = int_boot_in;

    assign io_mux_in[7] = ~KEY[0];  // used for GPIO interrupts

    assign LEDG[8] = io_mux_in[7];
    // -------------------------------------
    */

    // ----------------------------------------------
    // Normal routing of all io mux pins to FPGA GPIO pins
    genvar i;
    generate
        for (i = 0; i < 32; i++) begin : bidir_gen
        `ifndef WRAPPER
            assign GPIO[i] = io_mux_oe[i] ? int_io_mux_out[i] : 1'bZ;
        `else
            assign GPIO[i] = io_mux_oe[i] ? 1'bZ : int_io_mux_out[i];
        `endif
        end
        for (i = 0; i < 3; i++) begin : bidir_gen2
            assign BOOT_PIN[i] = boot_oe[i] ? boot_out[i] : 1'bZ;
        end
    endgenerate
    assign io_mux_in = int_io_mux_in;
    assign boot_in[1:0] = int_boot_in[1:0];

    always_ff @(posedge cgen) begin
        int_io_mux_out <= io_mux_out;
        int_io_mux_in <= GPIO;
        int_boot_in <= BOOT_PIN;
    end

    // ----------------------------------------------

    assign uart_rx = UART_RX;
    assign UART_TX = uart_tx;

    assign boot_in[2] = ~KEY[1];

    // assign LEDR[17:0] = io_mux_out[17:0];

    assign nRST = auto_nRST & (KEY[0]);

    assign LEDR[0+:3] = boot_out;
    assign LEDR[3+:3] = ~boot_in;
    assign LEDR[6+:3] = boot_oe;
    assign LEDR[9+:8] = int_io_mux_out[7:0];
endmodule
