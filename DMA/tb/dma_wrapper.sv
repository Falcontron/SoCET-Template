// created by Yiyang Shui (ericshuisyy@gmail.com), 09/27/2022
// last modified: 09/28/2022 

// This wrapper file contains both dma wrapper file 
// and the non-synthesizable memory model (simple_memory)

module dma_wrapper(
    input logic CLK,
    input logic nRST,
    input logic drq,
    output logic daq,
    output logic dma_interrupt,

    // AHB subordinate interface
    input logic [1:0] SUB_HTRANS,
    input logic [2:0] SUB_HSIZE,
    input logic [31:0] SUB_HADDR,
    input logic [31:0] SUB_HWDATA,
    input logic SUB_HWRITE, SUB_HREADY, SUB_HSEL, SUB_HMASTLOCK,
    input logic [2:0] SUB_HBURST,
    input logic [3:0] SUB_HPROT,
    
    output logic SUB_HREADYOUT,
    output logic SUB_HRESP,
    output logic [31:0] SUB_HRDATA,

    // AHB managaer interface
    output logic [1:0] MAN_HTRANS,
    output logic [2:0] MAN_HSIZE,
    output logic [31:0] MAN_HADDR,
    output logic [31:0] MAN_HWDATA,
    output logic MAN_HWRITE, MAN_HMASTLOCK, // MAN_HSEL,   // normally not in manager
    output logic [2:0] MAN_HBURST,
    output logic [3:0] MAN_HPROT,
    
    input logic MAN_HREADY,
    input logic MAN_HRESP,
    input logic [31:0] MAN_HRDATA,

    input int latency,

    output logic mem_request_stall,
    output logic [31:0] mem_rdata,
    input logic [3:0] mem_strobe,

    input int test_num,
    input int test_case
);
    ahb_if ahb_if_subordinate(.HCLK(), .HRESETn());
    ahb_if ahb_if_manager(.HCLK(), .HRESETn());
    bus_protocol_if bp_prif();
    bus_protocol_if bp_hintif();
    logic mem_enable;

    dma_controller DMA (
        .clk(CLK),
        .n_rst(nRST),
        .drq(drq),
        .daq(daq),
        .subordinate(ahb_if_subordinate),
        .manager(ahb_if_manager),
        .dma_interrupt
    );

    assign ahb_if_subordinate.HTRANS = SUB_HTRANS;
    assign ahb_if_subordinate.HSIZE = SUB_HSIZE;
    assign ahb_if_subordinate.HADDR = SUB_HADDR;
    assign ahb_if_subordinate.HWDATA = SUB_HWDATA;
    assign ahb_if_subordinate.HWRITE = SUB_HWRITE;
    assign ahb_if_subordinate.HREADY = SUB_HREADY;
    assign ahb_if_subordinate.HSEL = SUB_HSEL;
    assign ahb_if_subordinate.HMASTLOCK = SUB_HMASTLOCK;
    assign ahb_if_subordinate.HBURST = SUB_HBURST;
    assign ahb_if_subordinate.HPROT = SUB_HPROT;
    assign SUB_HREADYOUT = ahb_if_subordinate.HREADYOUT;
    assign SUB_HRESP = ahb_if_subordinate.HRESP;
    assign SUB_HRDATA = ahb_if_subordinate.HRDATA;

    assign MAN_HTRANS = ahb_if_manager.HTRANS;
    assign MAN_HSIZE = ahb_if_manager.HSIZE;
    assign MAN_HADDR = ahb_if_manager.HADDR;
    assign MAN_HWDATA = ahb_if_manager.HWDATA;
    assign MAN_HWRITE = ahb_if_manager.HWRITE;
    assign MAN_HMASTLOCK = ahb_if_manager.HMASTLOCK;
    assign MAN_HBURST = ahb_if_manager.HBURST;
    assign MAN_HPROT = ahb_if_manager.HPROT;

    assign ahb_if_manager.HREADY = MAN_HREADY & (~bp_prif.request_stall); // either TB control or simple_memory module control
    assign mem_request_stall = bp_prif.request_stall;

    assign ahb_if_manager.HRDATA = MAN_HRDATA | bp_prif.rdata;
    assign ahb_if_manager.HRESP = MAN_HRESP;

    // memory: 1024 words, 32 bit per word
    simple_memory #(2**10, 32) MEM (
        .CLK(CLK),
        .nRST(nRST),
        .latency(latency),
        .enable(mem_enable),
        .prif(bp_prif),
        .hintif(bp_hintif)
    );

    assign mem_enable = |(MAN_HADDR);

    assign bp_prif.wen = MAN_HWRITE;
    assign bp_prif.ren = ~MAN_HWRITE;
    assign bp_prif.addr = MAN_HADDR;
    assign bp_prif.wdata = MAN_HWDATA;
    assign bp_prif.strobe = mem_strobe;


endmodule