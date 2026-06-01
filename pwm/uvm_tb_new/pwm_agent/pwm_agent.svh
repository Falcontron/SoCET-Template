import uvm_pkg::*;
`include "uvm_macros.svh"
`include "pwm_monitor.svh"

class pwm_agent extends uvm_agent;
    `uvm_component_utils(pwm_agent)
    pwm_monitor mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        mon = pwm_monitor::type_id::create("mon", this);
    endfunction

endclass : pwm_agent
