// created by Yiyang Shui (ericshuisyy@gmail.com), 11/8/2022
// last modified: 11/8/2022

module simple_memory_wrapper(
    input CLK,
    input nRST,

    input int mem_latency,
    input logic [31:0] mem_addr,
    input logic [3:0] mem_strobe,
    input logic mem_wen, mem_ren,
    input logic [31:0] mem_wdata,
    
    output logic mem_request_stall,
    output logic [31:0] mem_rdata
);

    bus_protocol_if bp_prif();

    simple_memory MEM (
        .CLK(CLK),
        .nRST(nRST),
        .latency(latency),
        .prif(bp_prif),
        .hintif()
    );

    assign bp_prif.wen = mem_wen;
    assign bp_prif.ren = mem_ren;
    assign bp_prif.strobe = mem_strobe;
    assign bp_prif.addr = mem_addr;
    assign bp_prif.wdata = mem_wdata;

    assign mem_request_stall = bp_prif.request_stall;
    assign mem_rdata = bp_prif.rdata;

endmodule