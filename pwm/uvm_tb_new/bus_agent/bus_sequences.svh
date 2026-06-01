import uvm_pkg::*;
`include "uvm_macros.svh"
`include "bus_transaction.svh"

class bus_seq extends uvm_sequence#(bus_transaction);
    `uvm_object_utils(bus_seq)

    function new(string name = "bus_seq");
        super.new(name);
    endfunction

    task body();
        bus_transaction req_item;
        req_item = bus_transaction::type_id::create("req_item");

        start_item(req_item);
        req_item.wen = 1;
        req_item.ren = 0;
        req_item.addr = 0;
        req_item.wdata = 0;
        req_item.strobe = 0;
        finish_item(req_item);
    endtask
endclass : bus_seq

class configure_50p_duty extends uvm_sequence#(bus_transaction);
    `uvm_object_utils(configure_50p_duty)

    function new(string name = "configure_50p_duty");
        super.new(name);
    endfunction

    task body();
        bus_transaction req_item;
        req_item = bus_transaction::type_id::create("req_item");

        // Write to period register - 10 cycles
        start_item(req_item);
        req_item.wen = 1;
        req_item.ren = 0;
        req_item.addr = 32'h0;
        req_item.wdata = 32'h10;
        req_item.strobe = 4'h0;
        finish_item(req_item);

        // Write to duty register - 5 cycles
        start_item(req_item);
        req_item.wen = 1;
        req_item.ren = 0;
        req_item.addr = 32'h4;
        req_item.wdata = 32'h5;
        req_item.strobe = 4'h0;
        finish_item(req_item);

        // Write to control register - enable
        start_item(req_item);
        req_item.wen = 1;
        req_item.ren = 0;
        req_item.addr = 32'h8;
        req_item.wdata = 32'h1;
        req_item.strobe = 4'h0;
        finish_item(req_item);

        // Wait 10 cycles
        repeat (10) begin
            start_item(req_item);
            req_item.wen = 0;
            req_item.ren = 0;
            req_item.addr = 32'h0;
            req_item.wdata = 32'h0;
            req_item.strobe = 0;
            finish_item(req_item);
        end
    endtask

endclass : configure_50p_duty

class configure_30p_center_low extends uvm_sequence#(bus_transaction);
    `uvm_object_utils(configure_30p_center_low)

    function new(string name = "configure_30p_center_low");
        super.new(name);
    endfunction

    task body();
        bus_transaction req_item;
        req_item = bus_transaction::type_id::create("req_item");

        // Write to period register - 10 cycles
        start_item(req_item);
        req_item.wen = 1;
        req_item.ren = 0;
        req_item.addr = 32'h0;
        req_item.wdata = 32'h10;
        req_item.strobe = 4'h0;
        finish_item(req_item);

        // Write to duty register - 3 cycles
        start_item(req_item);
        req_item.wen = 1;
        req_item.ren = 0;
        req_item.addr = 32'h4;
        req_item.wdata = 32'h3;
        req_item.strobe = 4'h0;
        finish_item(req_item);

        // Write to control register - enable, active low, center aligned
        start_item(req_item);
        req_item.wen = 1;
        req_item.ren = 0;
        req_item.addr = 32'h8;
        req_item.wdata = 32'h3;
        req_item.strobe = 4'h0;
        finish_item(req_item);

        // Wait 60 cycles
        repeat (60) begin
            start_item(req_item);
            req_item.wen = 0;
            req_item.ren = 0;
            req_item.addr = 32'h0;
            req_item.wdata = 32'h0;
            req_item.strobe = 0;
            finish_item(req_item);
        end
    
    endtask

endclass : configure_30p_center_low

class config_seq extends uvm_sequence#(bus_transaction);
    `uvm_object_utils(config_seq)

    function new(string name = "config_seq");
        super.new(name);
    endfunction

    task body();
        bus_transaction req_item;
        logic [31:0] period_cfg, duty_cfg, control_cfg, channel_num;
        req_item = bus_transaction::type_id::create("req_item");

        if (!uvm_config_db#(logic[31:0])::get(null, "env.bus_agt.*", "period_reg_config", period_cfg))
            `uvm_fatal("Sequence", "No period config specified for this test instance")
        if (!uvm_config_db#(logic[31:0])::get(null, "env.bus_agt.*", "duty_reg_config", duty_cfg))
            `uvm_fatal("Sequence", "No duty config specified for this test instance")
        if (!uvm_config_db#(logic[31:0])::get(null, "env.bus_agt.*", "control_reg_config", control_cfg))
            `uvm_fatal("Sequence", "No control config specified for this test instance")
        if (!uvm_config_db#(logic[31:0])::get(null, "env.bus_agt.*", "channel_config_num", channel_num))
            `uvm_fatal("Sequence", "No channel num specified for this test instance")

        // Write to period register
        start_item(req_item);
        req_item.wen = 1;
        req_item.ren = 0;
        req_item.addr = 32'h0 + 32'd12 * channel_num;
        req_item.wdata = period_cfg;
        req_item.strobe = 4'h0;
        finish_item(req_item);

        // Write to duty register
        start_item(req_item);
        req_item.wen = 1;
        req_item.ren = 0;
        req_item.addr = 32'h4 + 32'd12 * channel_num;
        req_item.wdata = duty_cfg;
        req_item.strobe = 4'h0;
        finish_item(req_item);

        // Write to control register
        start_item(req_item);
        req_item.wen = 1;
        req_item.ren = 0;
        req_item.addr = 32'h8 + 32'd12 * channel_num;
        req_item.wdata = control_cfg;
        req_item.strobe = 4'h0;
        finish_item(req_item);
    endtask

endclass : config_seq

class check_output_seq extends uvm_sequence#(bus_transaction);
    `uvm_object_utils(check_output_seq)

    function new(string name = "check_output_seq");
        super.new(name);
    endfunction

    task body();
        bus_transaction req_item;
        logic [31:0] period_cfg, control_cfg;
        req_item = bus_transaction::type_id::create("req_item");

        if (!uvm_config_db#(logic[31:0])::get(null, "env.bus_agt.*", "period_reg_config", period_cfg))
            `uvm_fatal("Sequence", "No period config specified for this test instance")
        if (!uvm_config_db#(logic[31:0])::get(null, "env.bus_agt.*", "control_reg_config", control_cfg))
            `uvm_fatal("Sequence", "No control config specified for this test instance")

        // Allow for output to be checked
        if (control_cfg[0]) begin  // pwm_out is enabled
            repeat (period_cfg * 10) begin
                start_item(req_item);
                req_item.wen = 0;
                req_item.ren = 0;
                req_item.addr = 32'h0;
                req_item.wdata = 32'h0;
                req_item.strobe = 0;
                finish_item(req_item);
            end
        end else begin  // pwm_out is disabled
            repeat (10) begin
                start_item(req_item);
                req_item.wen = 0;
                req_item.ren = 0;
                req_item.addr = 32'h0;
                req_item.wdata = 32'h0;
                req_item.strobe = 0;
                finish_item(req_item);
            end
        end
    endtask

endclass : check_output_seq

class bus_rw_seq extends uvm_sequence#(bus_transaction);
    `uvm_object_utils(bus_rw_seq)

    function new(string name = "bus_rw_seq");
        super.new(name);
    endfunction

    task body();
        bus_transaction req_item = bus_transaction::type_id::create("req_item");

        // PWM implementation does not support reads

        repeat (20) begin
            start_item(req_item);
            if (!req_item.randomize())
                `uvm_fatal("Sequence", "Randomization failed for bus transaction")
            finish_item(req_item);
        end
    endtask

endclass : bus_rw_seq

class rand_enable_seq extends uvm_sequence#(bus_transaction);
    `uvm_object_utils(rand_enable_seq)

    function new(string name = "rand_enable_seq");
        super.new(name);
    endfunction

    task body();
        bus_transaction req_item;
        logic [31:0] channel_num, i;
        req_item = bus_transaction::type_id::create("req_item");

        if (!uvm_config_db#(logic[31:0])::get(null, "env.bus_agt.*", "channel_config_num", channel_num))
            `uvm_fatal("Sequence", "No channel num specified for this test instance")

        for (i = 1; i <= channel_num; i++) begin
            repeat (10) begin  // wait some cycles
                start_item(req_item);
                req_item.wen = 0;
                req_item.ren = 0;
                req_item.addr = 32'h0;
                req_item.wdata = 32'h0;
                req_item.strobe = 0;
                finish_item(req_item);
            end

            // Write to control register
            start_item(req_item);
            req_item.wen = 1;
            req_item.ren = 0;
            req_item.addr = 32'h8 + 32'd12 * i;
            req_item.wdata = 32'b1;
            req_item.strobe = 4'h0;
            finish_item(req_item);
        end

        repeat (100) begin  // wait some cycles
            start_item(req_item);
            req_item.wen = 0;
            req_item.ren = 0;
            req_item.addr = 32'h0;
            req_item.wdata = 32'h0;
            req_item.strobe = 0;
            finish_item(req_item);
        end
    endtask

endclass : rand_enable_seq


class pwm_configuration extends uvm_object;
    `uvm_object_utils(pwm_configuration)

    rand logic [31:0] period;
    rand logic [31:0] duty;
    rand logic enable;
    rand logic polarity;
    rand logic alignment;

    // Randomization constraints
    constraint config_constr {
        period dist{ [0:1000] };
        duty dist{ [0:1000] };
        enable dist{ 0 := 1, 1 := 19 };
    }

    function new(string name = "pwm_configuration");
        super.new(name);
    endfunction

endclass : pwm_configuration
