import uvm_pkg::*;
`include "uvm_macros.svh"
`include "bus_if.svh"
`include "bus_transaction.svh"

class bus_driver extends uvm_driver#(bus_transaction);
    `uvm_component_utils(bus_driver)

    virtual bus_if bvif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual bus_if)::get(this, "", "bus_vif", bvif))
            `uvm_fatal("bus_driver", "No virtual interface specified for this test instance");
    endfunction

    task run_phase(uvm_phase phase);
        bus_transaction req_item;
        DUT_reset();
        forever begin
            seq_item_port.get_next_item(req_item);
            @(negedge bvif.clk);
            bvif.n_rst = 1;
            bvif.b_p_if.wen = req_item.wen;
            bvif.b_p_if.ren = req_item.ren;
            bvif.b_p_if.addr = req_item.addr;
            bvif.b_p_if.wdata = req_item.wdata;
            bvif.b_p_if.strobe = req_item.strobe;
            @(posedge bvif.clk);
            seq_item_port.item_done();
        end
    endtask

    task DUT_reset();
        @(posedge bvif.clk);
        bvif.n_rst = 1;
        @(posedge bvif.clk);
        bvif.n_rst = 0;
        @(posedge bvif.clk);
        bvif.n_rst = 1;
    endtask

endclass : bus_driver
