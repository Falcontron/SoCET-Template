// Karthik Maiya
// Xianmeng Zhang
// Feb 15 2020
`timescale 1ns/1ps

module flex_fifo_mem
#(
    parameter int DATA_WIDTH = 4,
    parameter int FIFO_DEPTH = 16
)
(
    input logic clk,
    input logic [$clog2(FIFO_DEPTH)-1: 0] waddr,
    input logic wen,
    input logic [$clog2(FIFO_DEPTH)-1: 0] raddr,
    input logic [DATA_WIDTH-1: 0] wdata,
    output logic [DATA_WIDTH-1: 0] rdata
);

logic [DATA_WIDTH-1:0] mem [FIFO_DEPTH-1:0];

always @(posedge clk) begin
    if (wen) mem[waddr] <= wdata;
end

assign rdata = mem[raddr];

endmodule
