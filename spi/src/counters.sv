`include "spi_type_pkg.vh"
module counters
(
	input logic clk,
	input logic n_rst,
	input logic clear,
	input logic count_enable,
	input logic count_clk,
	input logic [31:0] bytelen,
	output logic OPC,w_done
);
	import spi_type_pkg::*;
	
	logic byte_cnt_en;
	word_t bytes_trs;
	logic [2:0] word_rollover_val;

    // Word size is 1 byte
    assign w_done = byte_cnt_en;

	//bit counter
	flex_counter_spi bitcnt
	(
		.clk(clk),
		.n_rst(n_rst),
		.clear(w_done),
		.count_enable(count_enable & count_clk),
		.rollover_val(4'd8),
		.rollover_flag(byte_cnt_en)
	);

	//byte counter
	flex_counter_spi #(32) bytecnt 
	(
		.clk(clk),
		.n_rst(n_rst),
		.clear(OPC),
		.count_enable(byte_cnt_en),
		.rollover_val(bytelen),
		.count_out(bytes_trs),
		.rollover_flag(OPC)
	);

    /*
	flex_counter #(3) wordcnt
	(
		.clk(clk),
		.n_rst(n_rst),
		.clear(w_done),
		.count_enable(byte_cnt_en),
		.rollover_val(word_rollover_val),
		.rollover_flag(w_done)
	);

	always_comb
	begin
		if ((bytelen - bytes_trs) > 4)
			word_rollover_val = 4;
		else
			word_rollover_val = bytelen - bytes_trs;
	end*/

endmodule
