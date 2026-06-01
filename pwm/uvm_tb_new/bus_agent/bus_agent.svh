import uvm_pkg::*;
`include "uvm_macros.svh"
`include "bus_sequencer.svh"
`include "bus_driver.svh"
`include "bus_monitor.svh"

class bus_agent extends uvm_agent;
    `uvm_component_utils(bus_agent)
    bus_sequencer sqr;
    bus_driver drv;
    bus_monitor mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        sqr = bus_sequencer::type_id::create("sqr", this);
        drv = bus_driver::type_id::create("drv", this);
        mon = bus_monitor::type_id::create("mon", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

endclass : bus_agent
