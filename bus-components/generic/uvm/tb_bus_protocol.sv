`timescale 1ns / 1ps

import uvm_pkg::*;
`include "bus_protocol_if.sv"
`include "bus_if.svh"
`include "bus_test.svh"
`include "ff_ram.sv"

module tb_bus_protocol;
    logic clk;

    // generate clock
    initial begin
        clk = 0;
        forever #10 clk = !clk;
    end

    bus_if bif();  // contains a bus_protocol_if instance

    assign bif.clk = clk;

    ff_ram #(
        .NBYTES(4096),
        .LATENCY(0)
    ) RAM (
        .CLK(clk),
        .nRST(bif.n_rst),
        .busif(bif.b_p_if)
    );

    initial begin
        uvm_config_db#(virtual bus_if)::set(null, "", "bus_vif", bif);
        run_test();
    end

endmodule : tb_bus_protocol
