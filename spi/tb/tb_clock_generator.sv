`timescale 1ns / 100ps
module tb_clock_generator;

	localparam PERIOD = 20;
	logic CLK,nRST;
	logic [31:0] tb_divider;
	logic SCK_out;
	integer i,j;
	clock_generator DUT
	(
		.CLK(CLK),
		.nRST(nRST),
		.divider(tb_divider),
		.SCK(SCK_out)
	);


	// Clock
    always begin
        CLK = 1'b0;
        #(PERIOD/2);
        CLK = 1'b1;
        #(PERIOD/2);
    end

    initial begin
	nRST = 0;
	#(PERIOD);
	nRST = 1;
	#(PERIOD);
	for(i = 0;i<250;i = i + 1)
	begin
		j = 1;
		tb_divider = $random;
		while(tb_divider != j)
		begin
			#(PERIOD);
			j = j + 1;
			if (SCK_out != 0)
			$info("Error at testcase: %d, counter value : %d, divider: %d",i,j,tb_divider);
		end
		//here should get SCK_out == 1?
		#(PERIOD);
	end
    end
endmodule
