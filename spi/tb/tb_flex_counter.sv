`timescale 1ns / 100ps
module tb_flex_counter;
	//Bit size of value to count to
	localparam NUM_COUNT_BITS = 4;
	
	localparam PERIOD = 20;

	//Input logic
	logic clk, n_rst, clear, count_enable;
	logic [NUM_COUNT_BITS - 1:0] rollover_val;

	//Output logic
	logic [NUM_COUNT_BITS - 1:0] count_out;
	logic rollover_flag;
	
	integer i, j;

	flex_counter DUT //Need to add parameter part for NUM_CNT_BITS
	(
		.clk(clk),
		.n_rst(n_rst),
		.clear(clear),
		.count_enable(count_enable),
		.rollover_val(rollover_val),
		.count_out(count_out),
		.rollover_flag(rollover_flag)
	);

	//Clock
	always begin
		clk = 1'b0;
		#(PERIOD / 2);
		clk = 1'b1;
		#(PERIOD / 2);
	end

	initial begin
		n_rst = 1'b0;
		#(PERIOD);
		n_rst = 1'b1;
		#(PERIOD);

		for (i = 0; i < 2 ** NUM_COUNT_BITS - 1; i = i + 1) begin
			count_enable = 1'b0;
			//clear = 1'b0;
			rollover_val = i;
			#(PERIOD);
			count_enable =  1'b1;

			j = 0; //Reset the while loop variable

			while (count_out != j) begin
				#(PERIOD);
				j = j + 1;
				if (count_out != 0)
					$info("Error at rollover value = %d, counter value = %d, rollover flag = %d", rollover_val, count_out, rollover_flag);
			end
			if (rollover_flag != 1)
				$info("Error at rollover value = %d, counter value = %d, rollover flag = %d", rollover_val, count_out, rollover_flag);
			//#(PERIOD);
			//clear = 1'b1;
			#(PERIOD);
		end
	end	
endmodule
