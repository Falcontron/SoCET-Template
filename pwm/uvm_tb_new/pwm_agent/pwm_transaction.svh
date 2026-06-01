`ifndef PWM_TRANSACTION_SVH
`define PWM_TRANSACTION_SVH

import uvm_pkg::*;
`include "uvm_macros.svh"

class pwm_transaction extends uvm_sequence_item;
    `uvm_object_utils(pwm_transaction)

    logic pwm_out;

    function new(string name = "pwm_transaction");
        super.new(name);
    endfunction

endclass : pwm_transaction

`endif
