`ifndef PWM_TEST_SVH
`define PWM_IF_SVH

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "pwm_env.svh"
`include "bus_sequences.svh"

class base_test extends uvm_test;
    `uvm_component_utils(base_test)
    localparam NUM_CHANNELS = 1;
    virtual pwm_if#(NUM_CHANNELS) vif;
    virtual bus_if bvif;
    environment env;

    function new(string name = "base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = environment::type_id::create("env", this);

        if (!uvm_config_db#(virtual pwm_if#(NUM_CHANNELS))::get(this, "", "pwm_vif", vif))
            `uvm_fatal("Test", "No virtual interface specified for this test instance")
        uvm_config_db#(virtual pwm_if#(NUM_CHANNELS))::set(this, "env.agt*", "pwm_vif", vif);

        if (!uvm_config_db#(virtual bus_if)::get(this, "", "bus_vif", bvif))
            `uvm_fatal("Test", "No virtual interface specified for this test instance")
        uvm_config_db#(virtual bus_if)::set(this, "env.agt*", "bus_vif", bvif);

        uvm_config_db#(logic)::set(null, "env.*", "check_type", 1'b0);
    endfunction

    task main_phase(uvm_phase phase);
        // bus_seq b_seq = bus_seq::type_id::create("b_seq", this);
        // configure_50p_duty b_seq = configure_50p_duty::type_id::create("b_seq", this);
        configure_30p_center_low b_seq = configure_30p_center_low::type_id::create("b_seq", this);

        phase.raise_objection(this, "Starting main phase");
        $display("%t Starting sequence...", $time);
        b_seq.start(env.bus_agt.sqr);
        #10ns
        phase.drop_objection(this, "Finished main phase");
    endtask

endclass : base_test

class config_test extends base_test;
    `uvm_component_utils(config_test)

    function new(string name = "config_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        logic [31:0] period, duty, enable, polarity, alignment;
        super.build_phase(phase);

        if (!uvm_config_db#(uvm_bitstream_t)::get(null, "", "period", period))
            `uvm_fatal("Test", "No period config specified for this test instance")
        if (!uvm_config_db#(uvm_bitstream_t)::get(null, "", "duty", duty))
            `uvm_fatal("Test", "No duty config specified for this test instance")
        if (!uvm_config_db#(uvm_bitstream_t)::get(null, "", "enable", enable))
            `uvm_fatal("Test", "No enable config specified for this test instance")
        if (!uvm_config_db#(uvm_bitstream_t)::get(null, "", "polarity", polarity))
            `uvm_fatal("Test", "No polarity config specified for this test instance")
        if (!uvm_config_db#(uvm_bitstream_t)::get(null, "", "alignment", alignment))
            `uvm_fatal("Test", "No alignment config specified for this test instance")

        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "period_reg_config", period);
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "duty_reg_config", duty);
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "control_reg_config", {29'b0, alignment[0], polarity[0], enable[0]});
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "channel_config_num", 32'b0);

        uvm_config_db#(logic[31:0])::set(null, "env.scoreboard0", "period_reg_config", period);
        uvm_config_db#(logic[31:0])::set(null, "env.scoreboard0", "duty_reg_config", duty);
        uvm_config_db#(logic[31:0])::set(null, "env.scoreboard0", "control_reg_config", {29'b0, alignment[0], polarity[0], enable[0]});
    endfunction

    task configure_phase(uvm_phase phase);
        config_seq b_seq = config_seq::type_id::create("b_seq", this);

        phase.raise_objection(this, "Starting configure phase");
        $display("%t Starting config sequence...", $time);
        b_seq.start(env.bus_agt.sqr);
        phase.drop_objection(this, "Finished configure phase");
    endtask

    task main_phase(uvm_phase phase);
        check_output_seq chk_seq = check_output_seq::type_id::create("chk_seq", this);

        phase.raise_objection(this, "Starting main phase");
        $display("%t Starting main sequence...", $time);
        chk_seq.start(env.bus_agt.sqr);
        phase.drop_objection(this, "Finished main phase");
    endtask

endclass : config_test

class rand_config_test extends base_test;
    `uvm_component_utils(rand_config_test)

    function new(string name = "rand_config_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        pwm_configuration pwm_config = pwm_configuration::type_id::create("pwm_config", this);
        super.build_phase(phase);

        if (!pwm_config.randomize())
            `uvm_fatal("Test", "Randomization failed for pwm configuration")

        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "period_reg_config", pwm_config.period);
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "duty_reg_config", pwm_config.duty);
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "control_reg_config", {29'b0, pwm_config.alignment, pwm_config.polarity, pwm_config.enable});
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "channel_config_num", 32'b0);

        uvm_config_db#(logic[31:0])::set(null, "env.scoreboard0", "period_reg_config", pwm_config.period);
        uvm_config_db#(logic[31:0])::set(null, "env.scoreboard0", "duty_reg_config", pwm_config.duty);
        uvm_config_db#(logic[31:0])::set(null, "env.scoreboard0", "control_reg_config", {29'b0, pwm_config.alignment, pwm_config.polarity, pwm_config.enable});
    endfunction

    task configure_phase(uvm_phase phase);
        config_seq b_seq = config_seq::type_id::create("b_seq", this);

        phase.raise_objection(this, "Starting configure phase");
        $display("%t Starting config sequence...", $time);
        b_seq.start(env.bus_agt.sqr);
        phase.drop_objection(this, "Finished configure phase");
    endtask

    task main_phase(uvm_phase phase);
        check_output_seq chk_seq = check_output_seq::type_id::create("chk_seq", this);

        phase.raise_objection(this, "Starting main phase");
        $display("%t Starting main sequence...", $time);
        chk_seq.start(env.bus_agt.sqr);
        phase.drop_objection(this, "Finished main phase");
    endtask

endclass : rand_config_test

class register_rw_test extends base_test;
    `uvm_component_utils(register_rw_test)

    function new(string name = "register_rw_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "period_reg_config", 32'b0);
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "duty_reg_config", 32'b0);
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "control_reg_config", 32'b0);
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "channel_config_num", 32'b0);

        uvm_config_db#(logic[31:0])::set(null, "env.scoreboard0", "period_reg_config", 32'b0);
        uvm_config_db#(logic[31:0])::set(null, "env.scoreboard0", "duty_reg_config", 32'b0);
        uvm_config_db#(logic[31:0])::set(null, "env.scoreboard0", "control_reg_config", 32'b0);
    endfunction

    task main_phase(uvm_phase phase);
        bus_rw_seq b_seq = bus_rw_seq::type_id::create("b_seq", this);

        phase.raise_objection(this, "Starting main phase");
        $display("%t Starting main sequence...", $time);
        b_seq.start(env.bus_agt.sqr);
        phase.drop_objection(this, "Finished main phase");
    endtask

endclass : register_rw_test

class multi_channel_config_test extends base_test;
    `uvm_component_utils(multi_channel_config_test)

    function new(string name = "multi_channel_config_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "period_reg_config", 32'b0);
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "duty_reg_config", 32'b0);
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "control_reg_config", 32'b0);
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "channel_config_num", 32'b0);
        uvm_config_db#(logic)::set(null, "env.*", "check_type", 1'b1);  // changing output check
    endfunction

    task configure_phase(uvm_phase phase);
        pwm_configuration pwm_config = pwm_configuration::type_id::create("pwm_config", this);
        config_seq b_seq = config_seq::type_id::create("b_seq", this);
        logic [31:0] channel = 0;

        phase.raise_objection(this, "Starting configure phase");
        $display("%t Starting config sequence...", $time);
        repeat (NUM_CHANNELS) begin
            if (!pwm_config.randomize())
            `uvm_fatal("Test", "Randomization failed for pwm configuration")

            uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "period_reg_config", pwm_config.period);
            uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "duty_reg_config", pwm_config.duty);
            uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "control_reg_config", {29'b0, pwm_config.alignment, pwm_config.polarity, pwm_config.enable});
            uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "channel_config_num", channel);

            uvm_config_db#(logic[31:0])::set(null, $sformatf("env.scoreboard%1d", channel), "period_reg_config", pwm_config.period);
            uvm_config_db#(logic[31:0])::set(null, $sformatf("env.scoreboard%1d", channel), "duty_reg_config", pwm_config.duty);
            uvm_config_db#(logic[31:0])::set(null, $sformatf("env.scoreboard%1d", channel), "control_reg_config", {29'b0, pwm_config.alignment, pwm_config.polarity, pwm_config.enable});
            b_seq.start(env.bus_agt.sqr);
            channel = channel + 1;
        end
        phase.drop_objection(this, "Finished configure phase");
    endtask

    task main_phase(uvm_phase phase);
        check_output_seq chk_seq = check_output_seq::type_id::create("chk_seq", this);

        phase.raise_objection(this, "Starting main phase");
        $display("%t Starting main sequence...", $time);
        chk_seq.start(env.bus_agt.sqr);
        phase.drop_objection(this, "Finished main phase");
    endtask

endclass : multi_channel_config_test

class rand_enable_test extends base_test;
    `uvm_component_utils(rand_enable_test)

    function new(string name = "rand_enable_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "period_reg_config", 32'b0);
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "duty_reg_config", 32'b0);
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "control_reg_config", 32'b0);
        uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "channel_config_num", 32'b0);
        uvm_config_db#(logic)::set(null, "env.*", "check_type", 1'b1);  // changing output check
    endfunction

    task configure_phase(uvm_phase phase);
        pwm_configuration pwm_config = pwm_configuration::type_id::create("pwm_config", this);
        config_seq b_seq = config_seq::type_id::create("b_seq", this);
        logic [31:0] channel = 0;

        phase.raise_objection(this, "Starting configure phase");
        $display("%t Starting config sequence...", $time);
        repeat (NUM_CHANNELS) begin
            if (!pwm_config.randomize())
            `uvm_fatal("Test", "Randomization failed for pwm configuration")

            // Initally only enable 1st channel
            if (channel == 0) pwm_config.enable = 1'b1;
            else pwm_config.enable = 1'b0;

            // Limit period and duty
            pwm_config.period = 10;
            pwm_config.duty = 6;

            uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "period_reg_config", pwm_config.period);
            uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "duty_reg_config", pwm_config.duty);
            uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "control_reg_config", {29'b0, pwm_config.alignment, pwm_config.polarity, pwm_config.enable});
            uvm_config_db#(logic[31:0])::set(null, "env.bus_agt.*", "channel_config_num", channel);

            uvm_config_db#(logic[31:0])::set(null, $sformatf("env.scoreboard%1d", channel), "period_reg_config", pwm_config.period);
            uvm_config_db#(logic[31:0])::set(null, $sformatf("env.scoreboard%1d", channel), "duty_reg_config", pwm_config.duty);
            uvm_config_db#(logic[31:0])::set(null, $sformatf("env.scoreboard%1d", channel), "control_reg_config", {29'b0, pwm_config.alignment, pwm_config.polarity, pwm_config.enable});
            b_seq.start(env.bus_agt.sqr);
            channel = channel + 1;
        end
        phase.drop_objection(this, "Finished configure phase");
    endtask

    task main_phase(uvm_phase phase);
        rand_enable_seq chk_seq = rand_enable_seq::type_id::create("rand_en_seq", this);

        phase.raise_objection(this, "Starting main phase");
        $display("%t Starting main sequence...", $time);
        chk_seq.start(env.bus_agt.sqr);
        phase.drop_objection(this, "Finished main phase");
    endtask

endclass : rand_enable_test

`endif
