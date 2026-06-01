`include "apb_if.vh"
`include "apb_rw.svh"
`include "apb_driver_seq_mon.svh"
// `include "apb_sequences.svh"

`timescale 1ns/1ps

`include "uvm_macros.svh"

module tb_pwm();

	import uvm_pkg::*;
	//import i2c_test_lib_pkg::*;

	logic clk; logic n_rst;
	//Generates clock
	initial begin
		clk = 0;
		forever #10 clk = !clk;
	end

	initial begin 
		n_rst=0;
		@(posedge clk);
		n_rst=1;
	end

//Instantiate interface and connections to it-------------
        apb_if apbif(.pclk(clk));
        pwm_if pwmcif();
	
//DUT
	pwm DUT ( .clk(clk), .n_rst(n_rst),
	 	.apb_bus(apbif),
		 .pwm(pwmcif)
		);

initial begin
	uvm_config_db#(virtual apb_if)::set( null, "", "apb_vif", apbif);
	uvm_config_db #(virtual pwm_if)::set(null, "", "pwm_vif", pwmif);
	run_test();
end
endmodule
