// $Id: $
// File name:   edge_detect.sv
// Created:     2/24/2016
// Author:      Kuo Tian
// Lab Section: 337-04
// Version:     1.0  Initial Design Entry
// Description: edge detect
module edge_detect_spi
(
	input logic clk,
	input logic n_rst,
	input logic edge_mode, //1 active high 0 active low
	input logic d_plus,
	output logic d_edge
);

	logic dprev,dcurr;

	always_ff @ (posedge clk, negedge n_rst)
	begin
		if(n_rst == 0)
		begin
			dprev <= 1;
			dcurr <= 1;
		end
		else begin
			dprev <= dcurr;
			dcurr <= d_plus;	
		end
	end

	assign d_edge = edge_mode ? (~dprev & dcurr):(dprev & ~dcurr);
endmodule

