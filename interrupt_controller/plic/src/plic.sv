import plic_pkg::*;

module plic #(
    parameter NUM_CONTEXTS = 1,
    parameter NUM_INTERRUPTS = 32,
    parameter interrupt_trigger_e [NUM_INTERRUPTS-1:0] INTERRUPT_TRIGGER_TYPES = '{NUM_INTERRUPTS{ACTIVE_HIGH}}
)(
    input CLK,
    input nRST,
    bus_protocol_if.peripheral_vital busif,
    plic_if.ic plicif
);
    plic_gateway_if #(
        .NUM_INTERRUPTS(NUM_INTERRUPTS)
    ) pgif ();

    gateway #(
        .NUM_INTERRUPTS(NUM_INTERRUPTS),
        .INTERRUPT_TRIGGER_TYPES(INTERRUPT_TRIGGER_TYPES)
    ) gateway (
        .clk(CLK),
        .nrst(nRST),
        .source(plicif.hw_interrupt_requests),
        .pgif(pgif)
    );

    plic_core #(
        .NUM_CONTEXTS(NUM_CONTEXTS),
        .NUM_INTERRUPTS(NUM_INTERRUPTS)
    ) core (
        .clk(CLK),
        .nrst(nRST),
        .busif(busif),
        .plicif(plicif),
        .pgif(pgif)
    );
endmodule
