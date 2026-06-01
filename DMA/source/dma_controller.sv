// `include "ahb_if.vh"
// `include "ahb_if.vh"

module dma_controller
(
    input logic clk,
    input logic n_rst,
    input logic drq,
    output logic daq,
    ahb_if.subordinate subordinate,
    ahb_if.manager manager,
    output logic dma_interrupt
);
    localparam WORD_W = 32;

    // Register Wires
    logic [WORD_W-1:0] status_reg;
    logic [WORD_W-1:0] control_reg;
    logic [WORD_W-1:0] transfer_reg;
    logic [WORD_W-1:0] source_reg;
    logic [WORD_W-1:0] dest_reg;

    // Counter Wires
    logic count_enable;
    logic clear;
    logic [7:0] count;
    logic [7:0] rollover_val;
    logic rollover_flag;

    // Read Control Wires
    logic fifo_full, wen, clear_fifo, r_hwrite, r_hsel;
    logic r_hready;
    logic [31:0] read_data; //Changed to 32
    logic status_read;
    logic async_reset;
    logic [65:0] read_data_addr_packet; //Changed to 66
    logic [2:0] r_hsize;
    logic [31:0] r_haddr;
    logic r_finished, r_error_flag;

    //Write Control Wires
    logic fifo_empty;
    logic w_hready;
    logic ren, w_hwrite, w_hsel;
    logic [2:0] w_hsize;
    logic [31:0] w_haddr; 
    logic [31:0] w_hwdata;
    logic [65:0] write_data_addr_packet;
    logic w_error_flag;
    logic daq_write;
    logic read_pause;

    // Assignments
    assign async_reset = '0;
//    assign dma_interrupt = r_finished & control_reg[8]; // Uncomment for CPU interrupt TODO
    assign dma_interrupt = r_finished & control_reg[1]; // Uncomment for CPU interrupt TODO, Yiyang

    // --- special signal bus for interacting with memory arbiter ---
    memArb_if memA(.CLK());
    assign memA.r_hsize = r_hsize;
    assign memA.r_hsel = r_hsel;
    assign memA.r_haddr = r_haddr;
    assign memA.w_hsize = w_hsize;
    assign memA.w_hwrite = w_hwrite;
    assign memA.w_hsel = w_hsel;
    assign memA.w_haddr = w_haddr;
    assign memA.w_hwdata = w_hwdata;
    assign w_hready = memA.w_hready;
    assign r_hready = memA.r_hready;
    assign read_data = memA.hrdata;

    memArbiter ARB
    (
        .CLK(clk),
        .nRST(n_rst),
        .memA(memA),
        .ahb_m(manager)
    );

    fifo_new FIF
    (
        .clock(clk),
        .n_rst(n_rst),
        .DATAIN(read_data_addr_packet),
        .DATAOUT(write_data_addr_packet),
        .wn(wen),
        .rn(ren),
        .clear(clear_fifo),
        .full(fifo_full),
        .empty(fifo_empty)
    );

    write_control write_control
    (
        .clk(clk),
        .n_rst(n_rst),
        .async_reset(async_reset),
        .fifo_empty(fifo_empty),
        .hready(w_hready),
        .control_signals(control_reg),
        .data_addr_packet(write_data_addr_packet),
        .ren(ren),
        .hwrite(w_hwrite),
        .hsel(w_hsel),
        .hsize(w_hsize),
        .haddr(w_haddr),
        .hwdata(w_hwdata),
        .error_flag(w_error_flag),
        .finished(daq_write),
        .read_pause(read_pause),
        .clear_fifo()
    );

    read_control RCTRL
    (
        .clk(clk),
        .n_rst(n_rst),
        .count_enable(count_enable),
        .count(count),
        .rollover_flag(rollover_flag),
        .control_signals(control_reg),
        .fifo_full(fifo_full),
        .hready(r_hready),
        .dest_addr(dest_reg),
        .src_addr(source_reg),
        .drq(drq),
        .read_data(read_data),
        .status_read(status_read),
        .async_reset(async_reset),
        .clear(clear),
        .daq(daq),
        .data_addr_packet(read_data_addr_packet),
        .wen(wen),
        .clear_fifo(clear_fifo),
        .hwrite(r_hwrite),
        .hsel(r_hsel),
        .hsize(r_hsize),
        .haddr(r_haddr),
        .finished(r_finished),
        .error_flag(r_error_flag),
        .daq_write(daq_write),
        .read_pause(read_pause)
    );

    registers REGI
    (
        .CLK(clk),
        .nRST(n_rst),
        .ahb_s(subordinate),
        .status_reg(status_reg),
        .control_reg(control_reg),
        .transfer_reg(transfer_reg),
        .source_reg(source_reg),
        .dest_reg(dest_reg),
        .status_read_flag(status_read),
        .error(r_error_flag | w_error_flag),
        .finished(r_finished)
    );

    counter CNTR
    (
        .clk(clk),
        .n_rst(n_rst),
        .count_enable(count_enable),
        .clear(clear),
        .count_out(count),
        .rollover_val(transfer_reg[7:0]),
        .rollover_flag(rollover_flag)
    );

endmodule


    



