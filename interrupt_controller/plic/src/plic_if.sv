/*
    Interface for interrupt controller
    Author: Ruoyi Chen
*/

interface plic_if #(
    parameter NUM_CONTEXTS = 1,
    parameter NUM_INTERRUPTS = 32
)();
    // External interrupt sources
    logic [NUM_INTERRUPTS-1:0] hw_interrupt_requests;
    // Signal to set {m,s}eip bit in a core. Active high until a claim occurs.
    logic [NUM_CONTEXTS-1:0] interrupt_service_request;

    modport ic (
        input   hw_interrupt_requests,
        output  interrupt_service_request

    );

    modport top (
        input  interrupt_service_request,
        output  hw_interrupt_requests
    );
endinterface
