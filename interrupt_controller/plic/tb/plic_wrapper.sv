module plic_wrapper #(
    parameter int NUM_INTERRUPTS = 64,
    parameter int NUM_CONTEXTS = 4
)(
    input logic CLK,
    input logic nRST,
    // plic
    input logic [NUM_INTERRUPTS-1:0] hw_interrupt_requests,
    output logic [NUM_CONTEXTS-1:0] interrupt_service_request,
    // bus
    input wen,
    input ren,
    input [31:0] addr,
    input [31:0] wdata,
    input [3:0] strobe,
    // plic-gateway
    input [NUM_INTERRUPTS-1:0] interrupt_requests,

    output logic error,
    output logic [31:0] rdata
);
    bus_protocol_if busif();
    plic_if #(
        .NUM_CONTEXTS(NUM_CONTEXTS),
        .NUM_INTERRUPTS(NUM_INTERRUPTS)
    ) plicif();

    plic #(
        .NUM_CONTEXTS(NUM_CONTEXTS),
        .NUM_INTERRUPTS(NUM_INTERRUPTS),
        .INTERRUPT_TRIGGER_TYPES({{60{ACTIVE_HIGH}}, FALLING_EDGE, RISING_EDGE, ACTIVE_HIGH, ACTIVE_HIGH})
    ) PLIC(.*);

    assign plicif.hw_interrupt_requests = hw_interrupt_requests;
    assign interrupt_service_request = plicif.interrupt_service_request;
    
    assign busif.wen = wen;
    assign busif.ren = ren;
    assign busif.addr = addr;
    assign busif.wdata = wdata;
    assign busif.strobe = strobe;
    assign rdata = busif.rdata;
    assign error = busif.error;
endmodule
