// Karthik Maiya
// Xianmeng Zhang Feb 15
//
`timescale 1ns/1ns

module flex_fifo_mem_tb;
    localparam data_width = 4;
    localparam address_width = 4;

    localparam PERIOD = 10;
    logic clk = 0;
    always #(PERIOD/2) clk++;

    logic [address_width-1:0] tb_waddr;
    logic tb_wen;
    logic [address_width-1:0] tb_raddr;
    logic [data_width-1:0] tb_wdata;
    logic [data_width-1:0] tb_rdata;

	test PROG(.clk);

    flex_fifo_mem #(.data_width(data_width), .address_width(address_width)) DUT (
        .clk(clk),
        .waddr(tb_waddr),
        .wen(tb_wen),
        .raddr(tb_raddr),
        .wdata(tb_wdata),
        .rdata(tb_rdata)
    );

    task reset_dut;
        begin
            tb_waddr = '0;
            tb_wen = 0;
            tb_raddr = '0;
            tb_wdata = '0;
            @(negedge clk);
            @(negedge clk);
            @(negedge clk);
            @(negedge clk);
            $display("DUT reset done");
        end
    endtask

	task check_output
	(
		input logic [address_width-1:0] address,
		input logic [data_width-1:0] expected
	);
        begin
            tb_raddr = address;
            @(negedge clk);
            assert(expected != tb_rdata) 
                $display("Expected RDATA does not match RDATA");
			else
                $display("Expected RDATA match RDATA, %d == %d",expected,tb_rdata);
        end
    endtask

    task write_data
	(
		input logic [address_width-1:0] address,
		input logic enable,
		input logic [data_width-1:0] data
	);
        begin
            @(posedge clk);
            tb_wen = enable;
            tb_waddr = address;
            tb_wdata = data;
        end
    endtask

    task write_end;
        begin
            @(posedge clk);
            tb_wen = 0;
            tb_waddr  = '0;
            tb_wdata = '0;
        end
    endtask
    
endmodule


program test
(
	input logic clk
);
    initial
    begin
//		reset_dut();
//		reset_dut();
        write_data(4'd0,1,4'd0);
        write_data(4'd1,1,4'd1);
        write_data(4'd2,1,4'd2);
        write_data(4'd3,1,4'd3);
        write_data(4'd4,1,4'd4);
        write_data(4'd5,1,4'd5);
        write_data(4'd6,1,4'd6);
        write_data(4'd7,1,4'd7);
        write_data(4'd8,1,4'd8);
        write_data(4'd9,1,4'd9);
        write_data(4'd10,1,4'd10);
        write_data(4'd11,1,4'd11);
        write_data(4'd12,1,4'd12);
        write_data(4'd13,1,4'd13);
        write_data(4'd14,1,4'd14);
        write_data(4'd15,1,4'd15);
        write_end();
        check_output(4'd0,4'd0);
        check_output(4'd1,4'd1);
        check_output(4'd2,4'd2);
        check_output(4'd3,4'd3);
        check_output(4'd4,4'd4);
        check_output(4'd5,4'd5);
        check_output(4'd6,4'd6);
        check_output(4'd7,4'd7);
        check_output(4'd8,4'd8);
        check_output(4'd9,4'd9);
        check_output(4'd10,4'd10);
        check_output(4'd11,4'd11);
        check_output(4'd12,4'd12);
        check_output(4'd13,4'd13);
        check_output(4'd14,4'd14);
        check_output(4'd15,4'd15);
    end
endprogram
