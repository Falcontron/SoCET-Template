import uvm_pkg::*;
`include "uvm_macros.svh"
`include "pwm_transaction.svh"

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)
    uvm_analysis_export#(pwm_transaction) pwm_export;
    uvm_tlm_analysis_fifo#(pwm_transaction) pwm_fifo;
    int channel;
    logic [31:0] period_cfg, duty_cfg, control_cfg;
    logic expected_out, prev_out;
    logic check_type;  // 0 checks all output after enable, 1 waits for change in output to start

    int n_matches, n_mismatches;
    logic[31:0] count, inactive;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        n_matches = 0;
        n_mismatches = 0;
        count = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        pwm_export = new("pwm_export", this);
        pwm_fifo = new("pwm_fifo", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        pwm_export.connect(pwm_fifo.analysis_export);
    endfunction

    task post_configure_phase(uvm_phase phase);
        if (!uvm_config_db#(int)::get(this, "", "channel_num", channel))
            `uvm_fatal("Scoreboard", "No channel number specificed for this test instance")
        if (!uvm_config_db#(logic[31:0])::get(null, $sformatf("env.scoreboard%1d", channel), "period_reg_config", period_cfg))
            `uvm_fatal("Scoreboard", "No period config specified for this test instance")
        if (!uvm_config_db#(logic[31:0])::get(null, $sformatf("env.scoreboard%1d", channel), "duty_reg_config", duty_cfg))
            `uvm_fatal("Scoreboard", "No duty config specified for this test instance")
        if (!uvm_config_db#(logic[31:0])::get(null, $sformatf("env.scoreboard%1d", channel), "control_reg_config", control_cfg))
            `uvm_fatal("Scoreboard", "No control config specified for this test instance")
        if (!uvm_config_db#(logic)::get(null, "env.*", "check_type", check_type))
            `uvm_fatal("Scoreboard", "No check type specified for this test instance")
    endtask

    task main_phase(uvm_phase phase);
        pwm_transaction mon_tx;
        case (check_type)
        0: begin  // checks all output values after enable (assumes main_phase begins directly after channel is enabled)
            count = 1;
            forever begin
                pwm_fifo.get(mon_tx);

                // Calculate cycles pwm_out should be inactive
                if ((duty_cfg - 1) >= period_cfg) inactive = 0;
                else inactive = period_cfg - (duty_cfg - 1);

                if (control_cfg[0]) begin  // pwm_out is enabled
                    if (control_cfg[1]) expected_out = 1'b0;  // active low
                    else expected_out = 1'b1;  // active high

                    if (control_cfg[2]) begin  // center aligned
                        if ((count < (inactive / 2)) || (count > (period_cfg - (inactive / 2)))) expected_out = ~expected_out;
                    end else begin  // left aligned
                        if (count >= duty_cfg) expected_out = ~expected_out;
                    end
                end else begin  // pwm_out is disabled
                    expected_out = 1'b0;
                end

                if (mon_tx.pwm_out == expected_out) begin
                    n_matches++;
                    // uvm_report_info("Scoreboard", $psprintf("Correct\nExpected pwm_out: %d\nActual pwm_out:   %d\nCount: %d\n", expected_out, mon_tx.pwm_out, count),
                    //                 UVM_LOW);
                end
                else begin
                    n_mismatches++;
                    uvm_report_info("Scoreboard", $psprintf("INCORRECT\nExpected pwm_out: %d\nActual pwm_out:   %d\nCount: %d\n", expected_out, mon_tx.pwm_out, count),
                                    UVM_LOW);
                end

                if (count == period_cfg) count = 1;
                else count++;
            end
        end
        1: begin  // begins to check output after change in output value (useful when testing multiple channels)
            // Calculate cycles pwm_out should be inactive
            if ((duty_cfg - 1) >= period_cfg) inactive = 0;
            else if (control_cfg[2]) begin
                inactive = period_cfg - (((duty_cfg * 2) / 2) - 1) - 1;
                duty_cfg += 1;
            end
            else inactive = period_cfg - (duty_cfg - 1);

            pwm_fifo.get(mon_tx);
            prev_out = mon_tx.pwm_out;
            pwm_fifo.get(mon_tx);
            // Wait until output changes
            while (mon_tx.pwm_out == prev_out) begin
                prev_out = mon_tx.pwm_out;
                pwm_fifo.get(mon_tx);
            end  // output change detected
            if (inactive == 0) begin
                n_mismatches++;
                uvm_report_info("Scoreboard", $psprintf("INCORRECT\nExpected pwm_out: %d\nActual pwm_out:   %d\n", prev_out, mon_tx.pwm_out),
                                UVM_LOW);
            end

            if (control_cfg[0]) count = 1;
            else count = 0;
            forever begin
                prev_out = mon_tx.pwm_out;
                pwm_fifo.get(mon_tx);

                if ((prev_out != ~control_cfg[1]) && (count < inactive)) begin
                    expected_out = prev_out;
                    count++;
                end else if (prev_out != ~control_cfg[1]) begin
                    expected_out = ~prev_out;
                    count = 1;
                end else if ((prev_out == ~control_cfg[1]) && (count < (duty_cfg - 1))) begin
                    expected_out = prev_out;
                    count++;
                end else begin
                    expected_out = ~prev_out;
                    count = 1;
                end
                if (inactive == 0) expected_out = ~control_cfg[1];

                if (mon_tx.pwm_out == expected_out) begin
                    n_matches++;
                    prev_out = mon_tx.pwm_out;
                    // uvm_report_info("Scoreboard", $psprintf("Correct\nExpected pwm_out: %d\nActual pwm_out:   %d\nCount: %d\n", expected_out, mon_tx.pwm_out, count),
                    //                 UVM_LOW);
                end else begin
                    n_mismatches++;
                    prev_out = expected_out;  // set 'previous' value to expected
                    uvm_report_info("Scoreboard", $psprintf("INCORRECT\nExpected pwm_out: %d\nActual pwm_out:   %d\nCount: %d\nPeriod: %d\nDuty: %d\n", expected_out, mon_tx.pwm_out, count, period_cfg, duty_cfg),
                                    UVM_LOW);
                    count = 2;
                end
            end
        end
        endcase
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_info("Scoreboard", $psprintf("Matches:    %d", n_matches), UVM_LOW);
        uvm_report_info("Scoreboard", $psprintf("Mismatches: %d", n_mismatches), UVM_LOW);
    endfunction

endclass : scoreboard
