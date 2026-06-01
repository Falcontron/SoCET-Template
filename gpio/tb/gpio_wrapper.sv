
module gpio_wrapper #(
    parameter int NUM_PINS = 8
) (
    input CLK,
    input nRST,
    input [NUM_PINS-1:0] in_data,
    output logic [NUM_PINS-1:0] oe_data,
    output logic [NUM_PINS-1:0] out_data,
    output logic [NUM_PINS-1:0] irq,

    input wen,
    input ren,
    input [31:0] addr,
    input [31:0] wdata,
    input [3:0] strobe,

    output logic request_stall,
    output logic error,
    output logic [31:0] rdata
);

    bus_protocol_if busif ();
    gpio_if #(.NUM_PINS(NUM_PINS)) gpioif ();

    gpio #(
        .NUM_PINS(NUM_PINS)
    ) GPIO (
        .CLK,
        .nRST,
        .busif,
        .gpioif
    );

    assign gpioif.in_data = in_data;
    assign out_data = gpioif.out_data;
    assign oe_data = gpioif.oe_data;
    assign irq = gpioif.irq;

    assign busif.wen = wen;
    assign busif.ren = ren;
    assign busif.addr = addr;
    assign busif.wdata = wdata;
    assign busif.strobe = strobe;
    assign rdata = busif.rdata;
    assign error = busif.error;
    assign request_stall = busif.request_stall;

    // hack for verilator to be able to access parameter
    // from C++ TB
    function int get_num_pins();
        // verilator public
        get_num_pins = NUM_PINS;
    endfunction

endmodule
