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
        req_item.wen = 0;
        req_item.ren = 0;
        req_item.addr = 0;
        req_item.wdata = 0;
        req_item.strobe = 0;
        finish_item(req_item);
    endtask
endclass : bus_seq

class read_seq extends uvm_sequence#(bus_transaction);
    `uvm_object_utils(read_seq)

    function new(string name = "read_seq");
        super.new(name);
    endfunction

    task body();
        bus_transaction req_item;
        req_item = bus_transaction::type_id::create("req_item");

        start_item(req_item);
        req_item.wen = 0;
        req_item.ren = 1;
        req_item.addr = 32'h0;
        req_item.wdata = 0;
        req_item.strobe = 0;
        finish_item(req_item);
    endtask
endclass : read_seq

class write_seq extends uvm_sequence#(bus_transaction);
    `uvm_object_utils(write_seq)

    function new(string name = "write_seq");
        super.new(name);
    endfunction

    task body();
        bus_transaction req_item;
        req_item = bus_transaction::type_id::create("req_item");

        start_item(req_item);
        req_item.wen = 1;
        req_item.ren = 0;
        req_item.addr = 32'h4;
        req_item.wdata = 32'hdeadbeef;
        req_item.strobe = 0;
        finish_item(req_item);
    endtask
endclass : write_seq

class random_seq extends uvm_sequence#(bus_transaction);
    `uvm_object_utils(random_seq)

    function new(string name = "random_seq");
        super.new(name);
    endfunction

    task body();
        bus_transaction req_item;
        req_item = bus_transaction::type_id::create("req_item");

        start_item(req_item);
        if (!req_item.randomize())
            `uvm_fatal("Sequence", "Randomization failed for bus transaction")
        finish_item(req_item);
    endtask
endclass : random_seq
