import uvm_pkg::*;
`include "pwmchannel.sv"
`include "pwm_if.svh"
`include "bus_if.svh"
`include "pwm_test.svh"

module pwm_tb_top();
    localparam NUM_CHANNELS = 1;

    logic clk;

    // generate clk
    initial begin
        clk = 0;
        forever #5 clk = !clk;
    end

    pwm_if#(NUM_CHANNELS) p_if();
    bus_if b_if();

    // clock and reset signals are shared between interfaces
    assign p_if.clk = clk;
    assign b_if.clk = clk;
    assign b_if.n_rst = p_if.n_rst;
    assign p_if.n_rst = b_if.n_rst;

    pwm_wrapper #(.NUM_CHANNELS(NUM_CHANNELS)) DUT (
        .CLK(p_if.clk),
        .nRST(p_if.n_rst),
        .pwm_out(p_if.pwm_out),
        .busif(b_if.b_p_if)
    );

    initial begin
        uvm_config_db#(virtual pwm_if#(NUM_CHANNELS))::set(null, "", "pwm_vif", p_if);
        uvm_config_db#(virtual bus_if)::set(null, "", "bus_vif", b_if);
        uvm_config_db#(int)::set(null, "", "num_channels", NUM_CHANNELS);
        run_test();
    end

endmodule : pwm_tb_top
