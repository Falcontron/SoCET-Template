// interface bus_if(input logic clk, input logic nReset);
//   logic [31:0] addr;
//   logic [31:0] wdata;
//   logic [31:0] rdata;
//   logic [3:0]  strobe;
//   logic        wen;
//   logic        ren;
//   logic        error;
//   logic        request_stall;
//   modport master(input clk, nReset, output addr, wdata, strobe, wen, ren, input rdata, error, request_stall);
//   modport slave(input clk, nReset, addr, wdata, strobe, wen, ren, output rdata, error, request_stall);
// endinterface