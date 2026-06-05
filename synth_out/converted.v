module counter (
	clk,
	rst_n,
	en,
	count
);
	parameter signed [31:0] WIDTH = 8;
	input wire clk;
	input wire rst_n;
	input wire en;
	output reg [WIDTH - 1:0] count;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			count <= 1'sb0;
		else if (en)
			count <= count + 1'b1;
endmodule
