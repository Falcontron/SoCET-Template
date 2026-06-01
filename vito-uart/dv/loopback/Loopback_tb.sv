module Loopback_tb (
    input clk,
    input nReset,
    input syncReset,

    input logic [7:0] data_tx,
    input logic [15:0] rate,
    input valid,
    output busy,
    output done_tx,

    output logic [7:0] data_rx,
    output done_rx,
    output err,

    input wen,
    input ren,
    input [31:0] addr,
    input [31:0] wdata,
    input [3:0] strobe,

    output logic [31:0] rdata,
    output logic error,
    output logic request_stall
);

  logic rxClk;
  logic txClk;

  BaudRateGen #(2**16, 1) bg (
      .phase(1'b0),
      .*
  );

  logic inAHB;
  logic syncInAHB;

  logic outAHB;
  logic syncOutAHB;
  
  always_ff @(posedge clk, negedge nReset) begin
    if(!nReset) begin
      syncInAHB <= 1;
      syncOutAHB <= 1;
    end else begin
      syncInAHB <= inAHB;
      syncOutAHB <= outAHB;
    end
  end

  UartTxEn tx (
      .en  (txClk),
      .data(data_tx),
      .out (inAHB),
      .done(done_tx),
      .*
  );

  UartRxEn rx (
      .en  (rxClk),
      .data(data_rx),
      .in  (syncOutAHB),
      .done(done_rx),
      .*
  );

  bus_protocol_if bp ();

  always_comb begin
    bp.wen = wen;
    bp.ren = ren;
    bp.addr = addr;
    bp.wdata = wdata;
    bp.strobe = strobe;

    rdata = bp.rdata;
    error = bp.error;
    request_stall = bp.request_stall;
  end

  AHBUart uart (
      .rx(syncInAHB),
      .tx(outAHB),
      .*
  );

endmodule
