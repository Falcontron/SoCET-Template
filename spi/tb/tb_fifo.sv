`timescale 1ns / 100ps
module tb_fifo;
	parameter PERIOD = 10;
	integer i;
  logic clk = 1, nRST;

  // clock
  always #(PERIOD/2) clk++;

    	logic WEN,REN;
    	logic [31:0] wdata;
    	logic [31:0] rdata;
    	logic empty,full,half;

	fifo DUT
	(
		.CLK(clk), 
		.nRST(nRST),
    		.WEN(WEN),
		.REN(REN),
    		.wdata(wdata),
    		.rdata(rdata),
    		.empty(empty),
		.full(full),
		.half(half)
	);

	initial begin
	nRST = 0;
	#(PERIOD);
	nRST = 1;
	#(PERIOD);
	for(i = 0;i<250;i = i + 1)
	begin
		WEN = $random;
		REN = $random;
		wdata = $random;
		
		#(PERIOD);
	end
	$finish;
    end
endmodule
