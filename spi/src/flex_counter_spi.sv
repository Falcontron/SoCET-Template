// $Id: $
// File name:   flex_counter.sv
// Created:     2/2/2016
// Author:      Kuo Tian
// Lab Section: 337-04
// Version:     1.0  Initial Design Entry
// Description: flexable counter
module flex_counter_spi
#(
	NUM_CNT_BITS = 4
)
(
	input wire clk,
	input wire n_rst,
	input wire clear,
	input wire count_enable,
	input wire [NUM_CNT_BITS-1:0] rollover_val,
	output wire [NUM_CNT_BITS-1:0] count_out,
	output wire rollover_flag
);
	reg rollover_flag_curr;
	reg rollover_flag_next;
	reg [NUM_CNT_BITS-1:0] curr_count;
	reg [NUM_CNT_BITS-1:0] next_count;

	always_ff @ (posedge clk, negedge n_rst)
	begin
		if( n_rst == 0)
		begin
			curr_count <= '0;
			rollover_flag_curr <= 0; 
		end
		else
		begin
			curr_count <= next_count;
			rollover_flag_curr <= rollover_flag_next;
		end
	end

	always_comb
	begin
		if(clear)
		begin
			next_count = 0;
			rollover_flag_next = 0;
		end
		else
		begin
			if(count_enable)
			begin
				next_count = curr_count + 1;
				rollover_flag_next = 0;
				if(curr_count == rollover_val)
				begin
					next_count = 1;
				end
				if(next_count == rollover_val)
				begin
					rollover_flag_next = 1;
				end
			end
			else
			begin
				next_count = curr_count;
				rollover_flag_next = rollover_flag_curr ? 0 : rollover_flag_curr;
			end
			
		end
	end

	assign count_out = curr_count;
	assign rollover_flag = rollover_flag_curr;
endmodule 

