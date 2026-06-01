import uvm_pkg::*;
`include "uvm_macros.svh"
`include "pwm_if.svh"
`include "pwm_transaction.svh"

class pwm_monitor extends uvm_monitor;
    `uvm_component_utils(pwm_monitor)
    localparam NUM_CHANNELS = 1;
    int channel_num = 0;

    virtual pwm_if#(NUM_CHANNELS) vif;

    uvm_analysis_port#(pwm_transaction) pwm_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        pwm_ap = new("pwm_ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        if (!uvm_config_db#(virtual pwm_if#(NUM_CHANNELS))::get(this, "", "pwm_vif", vif))
            `uvm_fatal("pwm_monitor", "No virtual interface specified for this test instance");
        if (!uvm_config_db#(int)::get(this, "mon.*", "channel_num", channel_num))
            `uvm_fatal("pwm_monitor", "No channel number specificed for this test instance");
    endfunction

    virtual task main_phase(uvm_phase phase);
        super.main_phase(phase);
        // wait for DUT reset
        @(posedge vif.clk);
        @(posedge vif.clk);

        forever begin
            pwm_transaction tx;
            @(posedge vif.clk);
            tx = pwm_transaction::type_id::create("tx");
            tx.pwm_out = vif.pwm_out[channel_num];
            pwm_ap.write(tx);
        end
    
    endtask

endclass : pwm_monitor
