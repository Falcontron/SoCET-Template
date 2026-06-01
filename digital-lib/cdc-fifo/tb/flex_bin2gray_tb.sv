//Xianmeng Zhang
//Nov 17 2019
//reference: http://verilogcodes.blogspot.com/2017/10/4-bit-binary-to-gray-code-and-gray-code.html

`timescale 1ns / 1ns

module flex_bin2gray_tb();

    localparam tb_bin2gray = 1; // 0 for gray2bin_test, 0 for bin2gray_test
    localparam tb_width = 4;
/*
    localparam PERIOD = 10; // clock
    logic CLK = 0;
    always #(PERIOD/2) CLK++;
*/
    logic [tb_width-1:0] tb_Input;
    logic [tb_width-1:0] tb_Output;

    flex_bin2gray	#(.bin2gray(tb_bin2gray), .width(tb_width))		DUT		(.Input(tb_Input), .Output(tb_Output));
    if(tb_bin2gray)
        bin2gray_test	#(.tb_bin2gray(tb_bin2gray), .tb_width(tb_width))	PROGbg	(.tb_Input(tb_Input), .tb_Output(tb_Output));
    else
	    gray2bin_test	#(.tb_bin2gray(tb_bin2gray), .tb_width(tb_width))	PROGgb	(.tb_Input(tb_Input), .tb_Output(tb_Output));

endmodule


program bin2gray_test
#(
	parameter tb_bin2gray = 1, // set to 0 for gray2bin
	parameter tb_width = 4
)
(
    output logic [tb_width-1:0] tb_Input,
    input logic [tb_width-1:0] tb_Output
);

    task TEST
    (
    	input logic [tb_width-1:0] in, expected
    );
        begin
        	#10
        	tb_Input = in;
        	#10
            assert (expected == tb_Output)
                $display ("Correct bin2gray_test In:%b",tb_Input);
            else
                $display("\t\tERROR bin2gray_test\tIn:%b\tExpected:%b\tActually:%b",tb_Input,expected,tb_Output);
        end
    endtask

  initial
    begin
    
		TEST(4'b0000,4'b0000);
		TEST(4'b0001,4'b0001);
		TEST(4'b0010,4'b0011);
		TEST(4'b0011,4'b0010);
		TEST(4'b0100,4'b0110);
		TEST(4'b0101,4'b0111);
		TEST(4'b0110,4'b0101);
		TEST(4'b0111,4'b0100);
		TEST(4'b1000,4'b1100);
		TEST(4'b1001,4'b1101);
		TEST(4'b1010,4'b1111);
		TEST(4'b1011,4'b1110);
		TEST(4'b1100,4'b1010);
		TEST(4'b1101,4'b1011);
		TEST(4'b1110,4'b1001);
		TEST(4'b1111,4'b1000);

		$finish(1);

  end
endprogram



program gray2bin_test
#(
	parameter tb_bin2gray = 0, // set to 0 for gray2bin
	parameter tb_width = 4
)
(
    output logic [tb_width-1:0] tb_Input,
    input logic [tb_width-1:0] tb_Output
);
    task TEST
    (
    	input logic [tb_width-1:0] in, expected
    );
        begin
        	#10
        	tb_Input = in;
        	#10
            assert (expected == tb_Output) begin
                $display ("Correct gray2bin_test In:%b",tb_Input);
            end else begin
                $display("\t\tERROR gray2bin_test\tIn:%b\tExpected:%b\tActually:%b",tb_Input,expected,tb_Output);
            end
        end
    endtask

    initial
      begin
    
    	TEST(4'b0000,4'b0000);
    	TEST(4'b0001,4'b0001);
    	TEST(4'b0011,4'b0010);
    	TEST(4'b0010,4'b0011);
    	TEST(4'b0110,4'b0100);
    	TEST(4'b0111,4'b0101);
    	TEST(4'b0101,4'b0110);
    	TEST(4'b0100,4'b0111);
    	TEST(4'b1100,4'b1000);
    	TEST(4'b1101,4'b1001);
    	TEST(4'b1111,4'b1010);
    	TEST(4'b1110,4'b1011);
    	TEST(4'b1010,4'b1100);
    	TEST(4'b1011,4'b1101);
    	TEST(4'b1001,4'b1110);
    	TEST(4'b1000,4'b1111);

		$finish();

      end
endprogram
