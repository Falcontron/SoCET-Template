`ifndef BUS_TRANSACTION_SVH
`define BUS_TRANSACTION_SVH

import uvm_pkg::*;
`include "uvm_macros.svh"

class bus_transaction extends uvm_sequence_item;
    `uvm_object_utils(bus_transaction)
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;

    // Inputs
    rand logic wen;
    rand logic ren;
    rand logic [ADDR_WIDTH-1:0] addr;
    rand logic [DATA_WIDTH-1:0] wdata;
    rand logic [(DATA_WIDTH/8)-1:0] strobe;

    // Outputs
    logic [ADDR_WIDTH-1:0] rdata;
    logic error;
    logic request_stall;

    // Randomization constraints
    constraint tx_constr {
        if (wen) ren == 0;
        if (ren) wen == 0;
        addr dist{ 0, 4, 8 };
        strobe == '0;
    }

    function new(string name = "bus_transaction");
        super.new(name);
    endfunction

endclass : bus_transaction

`endif
