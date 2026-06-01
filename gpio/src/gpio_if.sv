/* 
Interface for the I/O of GPIO (top level)

Author: Dwezil D'souza
Revised 7/29/22: Cole Nelson
*/

interface gpio_if ();

    parameter NUM_PINS = 8;  //MAX32

    logic [NUM_PINS - 1 : 0] irq;
    logic [NUM_PINS - 1 : 0] out_data;  // Data for GPIO output mode
    logic [NUM_PINS - 1 : 0] in_data;  // Data from pin (I/O mux) for GPIO input mode
    logic [NUM_PINS - 1 : 0] oe_data;  // GPIO output enable (1 = GPIO output mode)

    modport gpio(input in_data, output oe_data, out_data, irq);

    modport io(output in_data, input oe_data, out_data);

    modport interrupt_controller(input irq);

endinterface
