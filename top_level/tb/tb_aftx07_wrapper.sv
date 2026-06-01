`timescale 1ns / 10ps     

module tb_aftx07_wrapper;
    localparam int GPIO_PINS_PER_PORT = 8;
    localparam int BOOT_PINS = 3;
    localparam int PWM_CHANNELS = 2;
    localparam int IO_MUX_NUM_PINS = 32;
    localparam int NUM_CHIP = 2;
    localparam int ADDR_WIDTH = 18;
    localparam int DATA_WIDTH = 16;
    localparam int NREGS = 64 * 1024 / 4;

    logic nRST;
    int cycles = 0;
    int count;

    localparam int HCLK_PERIOD_NS = 10; // 100 MHz
    localparam int PCLK_PERIOD_NS = HCLK_PERIOD_NS * 8;

    logic PCLK = 0, HCLK = 0;

    always #(PCLK_PERIOD_NS/2) PCLK++;
    always #(HCLK_PERIOD_NS/2) HCLK++;

    
    logic uart_rx, uart_tx;
    logic [31:0] io_mux_to_module_iopad;
    logic [31:0] io_mux_from_module_ff;
    logic [31:0] io_mux_output_en_ff;

    // sram signals
    logic n_OE [NUM_CHIP-1:0];
    logic n_CE [NUM_CHIP-1:0];
    logic n_WE [NUM_CHIP-1:0];
    logic n_LB [NUM_CHIP-1:0];
    logic n_UB [NUM_CHIP-1:0];
    logic [ADDR_WIDTH-1:0] addr;
    wire [DATA_WIDTH-1:0] wire_data;
    logic iopad_n_oe;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;

    logic [BOOT_PINS-1:0] boot_in, boot_out, boot_oe;

    aftx07_wrapper AFTX07_wrapper(
        .PCLK,
        .HCLK,
        .nRST,
        .uart_rx,
        .uart_tx,

        .io_mux_to_module_iopad,
        .io_mux_from_module_ff,
        .io_mux_output_en_ff,
        // sram signals
        .n_OE, .n_CE, .n_WE, .n_LB, .n_UB,
        .addr, .iopad_n_oe, .wdata, .rdata,
        .boot_in, .boot_out, .boot_oe
    );

    // simpluation of the io pad
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

    task reset();
        nRST = 0;
        repeat(2) @(negedge PCLK);
        nRST = 1;
        @(posedge PCLK);
        #(1);
    endtask

    initial begin
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0,tb_aftx07_wrapper);
        $fsdbDumpMDA(0, tb_aftx07_wrapper);
    end

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_aftx07_wrapper);
    end

    localparam integer max_cycles = 10000;

    initial begin
        nRST = 1;

        uart_rx = '0;
        io_mux_to_module_iopad = '0;
        boot_in = 3'b111;
        count = 500;

        reset();
        
        while(cycles < max_cycles && !AFTX07_wrapper.AFTX07.halt) begin
            @(posedge PCLK);
            cycles += 1;
            count -= 1;
            if(count == 1) begin
                io_mux_to_module_iopad = 32'hFF;
            end else if(count == 0) begin
                io_mux_to_module_iopad = 32'h0;
                count = 500;
            end
        end

        $display("Ran for %0d cycles.\n", cycles);
        if(cycles == max_cycles) begin
            $display("Warning: Terminated due to number of cycles!");
        end
        $finish();

    end

endmodule
