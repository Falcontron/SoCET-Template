`ifndef BUS_IF_SVH
`define BUS_IF_SVH

interface bus_if;
    logic clk;
    logic n_rst;

    // Bus interface
    bus_protocol_if b_p_if();

endinterface : bus_if

`endif
