//Xianmeng Zhang
//Nov 17 2019
//reference: http://verilogcodes.blogspot.com/2017/10/4-bit-binary-to-gray-code-and-gray-code.html
`timescale 1ns/1ps

module flex_bin2gray
#(
	parameter int BIN2GRAY = 1, // set to 0 for gray2bin
	parameter int WIDTH = 4
)
(
	input logic [WIDTH-1:0] cinput, //binary input
	output logic [WIDTH-1:0] coutput //gray code output
);

int i;

always_comb
begin
	coutput = cinput;
	if(BIN2GRAY)
	  begin
		for (i = 0; i < WIDTH - 1; i++)
			coutput[i] = cinput[i+1] ^ cinput[i];
	  end
	else
	  begin
		for(i = WIDTH - 2; i >= 0; i--)
			coutput[i] = coutput[i+1] ^ cinput[i];
	  end
end

endmodule

