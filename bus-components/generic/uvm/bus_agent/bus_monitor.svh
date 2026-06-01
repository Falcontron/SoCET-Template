import uvm_pkg::*;
`include "uvm_macros.svh"
`include "bus_if.svh"
`include "bus_transaction.svh"

class bus_monitor extends uvm_monitor;
    `uvm_component_utils(bus_monitor)

    virtual bus_if bvif;

    uvm_analysis_port#(bus_transaction) bus_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        bus_ap = new("bus_ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        if (!uvm_config_db#(virtual bus_if)::get(this, "", "bus_vif", bvif))
            `uvm_fatal("bus_monitor", "No virtual interface specified for this test instance");
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        // wait for DUT reset
        @(posedge bvif.clk);
        @(posedge bvif.clk);

        forever begin
            bus_transaction tx;
            @(posedge bvif.clk);
            tx = bus_transaction::type_id::create("tx");
            tx.wen = bvif.b_p_if.wen;
            tx.ren = bvif.b_p_if.ren;
            tx.addr = bvif.b_p_if.addr;
            tx.wdata = bvif.b_p_if.wdata;
            tx.strobe = bvif.b_p_if.strobe;

            tx.rdata = bvif.b_p_if.rdata;
            tx.error = bvif.b_p_if.error;
            tx.request_stall = bvif.b_p_if.request_stall;
            bus_ap.write(tx);
        end

    endtask

endclass : bus_monitor
