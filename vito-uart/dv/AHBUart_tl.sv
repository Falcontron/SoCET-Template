module AHBUart_tl #(
    int DefaultRate = 5207  // Chosen by fair dice roll
) (
    input clk,
    input nReset,

    input  rx,
    output tx,

    input wen,
    input ren,
    input [31:0] addr,
    input [31:0] wdata,
    input [3:0] strobe,

    output logic [31:0] rdata,
    output logic error,
    output logic request_stall
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

  AHBUart #(DefaultRate) uart (.*);

endmodule
