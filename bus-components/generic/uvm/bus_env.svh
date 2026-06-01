import uvm_pkg::*;
`include "uvm_macros.svh"
`include "bus_agent.svh"
`include "bus_if.svh"
`include "bus_transaction.svh"

class environment extends uvm_env;
    `uvm_component_utils(environment)
    bus_agent bus_agt;
    // scoreboard scrb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        bus_agt = bus_agent::type_id::create("bus_agt", this);
        // scrb = scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        // bus_agt.mon.bus_ap.connect(scrb.bus_export);
    endfunction
endclass : environment
