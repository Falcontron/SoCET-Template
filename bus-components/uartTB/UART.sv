
import uvm_pkg::*;

`include "Scoreboard.sv"
`include "uvm_macros.svh"
`include "bus_protocol_if.sv"
`include "bus_agent.sv"
`include "bus_driver.sv"
`include "bus_monitor.sv"
`include "bus_seq_item.sv"
`include "bus_seqr.sv"
`include "bus_sequence.sv"


`include "uart_intf.sv"
`include "uart_agent.sv"
`include "uart_driver.sv"
`include "uart_monitor.sv"
`include "uart_seq_item.sv"
`include "uart_seqr.sv"
`include "uart_sequence.sv"

module top;

    logic clock;


    bus_interface bus_intf();//?? what parameters to pass

    uart_interface uart_intf(); //?? what parameters to pass
 
    //UART DUT call??

    //intf setting
    initial begin
        //check this??
        // my und: it sets the bus_intf to be available everywhere with the handle bus_vif
        //this bus_intf will be accessed by bus_driver and bus_monitor
        uvm_config_db #(virtual bus_interface):: set(null, "*", "bus_vif", bus_vif);
        uvm_config_db #(virtual uart_interface):: set(null, "*", "uart_vif", uart_vif);
    end


    //Clock Generation.
    initial begin
        clock = 0;
        #5;
        forever begin
            clock = ~clock;
            #2;
        end
    end

    initial begin
        run_test();
    end
    //Safety Check. terminates after 5000 clock cycles.
    initial begin
        #5000;
        $display("Sorry! Ran out of Clock Cycles!");
        $finish();
    end

    //dumping variables for seeing waveforms.
    initial begin
        $dumpfile("d.vcd");
        $dumpvars();
    end

endmodule
