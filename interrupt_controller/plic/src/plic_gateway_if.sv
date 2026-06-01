interface plic_gateway_if #(
    parameter NUM_INTERRUPTS = 32
) ();
    // Active high signal to notify `plic_core` to set an interrupt
    // pending bit
    logic [NUM_INTERRUPTS-1:0] interrupt_notification;
    // Active high signal to indicate whether an interrupt is still requested.
    // This is used to handle the edge case where a level triggered interrupt
    // unasserts after `plic_core` has set its pending bit but before
    // a context has claimed it. It is always high for edge triggered
    // interrupts.
    logic [NUM_INTERRUPTS-1:0] interrupt_still_requested;
    // Pulse signal to notify `gateway` that an interrupt is being completed
    // and another `interrupt_notification` can be sent
    logic [NUM_INTERRUPTS-1:0] interrupt_completed;
    // Active high signal indicating the `plic_core` has set the corresponding
    // `interrupt_pending` bit
    logic [NUM_INTERRUPTS-1:0] interrupt_pending;

    modport plic_core (
        input interrupt_notification, interrupt_still_requested,
        output interrupt_completed, interrupt_pending
    );

    modport gateway (
        input interrupt_completed, interrupt_pending,
        output interrupt_notification, interrupt_still_requested
    );
endinterface
