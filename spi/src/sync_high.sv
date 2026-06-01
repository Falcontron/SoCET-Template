// $Id: $
// File name:   sync_high.sv
// Created:     1/27/2016
// Author:      Sam Sowell
// Lab Section: 337-05
// Version:     1.0  Initial Design Entry
// Description: Logic High Synchronizer
module sync_high
(
  input wire clk,
  input wire n_rst,
  input wire async_in,
  output reg sync_out
);

reg sync;

always_ff @ (posedge clk, negedge n_rst)
begin
  if(1'b0 == n_rst)
  begin
    sync_out <= 1'b1;
    sync <= 1'b1;
  end
  else
  begin
  sync <= async_in;
  sync_out <= sync;
  end
end

endmodule
