module gateway_wrapper(
    input logic clk,
    input logic nrst,
    input logic source,
    input logic active_high_interrupt_completed,
    input logic rising_interrupt_completed,
    input logic falling_interrupt_completed,
    input logic active_low_interrupt_completed,
    input logic active_high_interrupt_pending,
    input logic rising_interrupt_pending,
    input logic falling_interrupt_pending,
    input logic active_low_interrupt_pending,
    // plic-gateway if
    output logic active_high_interrupt_notification,
    output logic rising_interrupt_notification,
    output logic falling_interrupt_notification,
    output logic active_low_interrupt_notification
);
    plic_gateway_if pgif [3:0] ();

    gateway #(
        .NUM_INTERRUPTS(1),
        .INTERRUPT_TRIGGER_TYPES({ACTIVE_HIGH})
    ) gateway0 (
        .source(source),
        .pgif(pgif[0]),
        .*
    );
    gateway #(
        .NUM_INTERRUPTS(1),
        .INTERRUPT_TRIGGER_TYPES({RISING_EDGE})
    ) gateway1 (
        .source(source),
        .pgif(pgif[1]),
        .*
    );
    gateway #(
        .NUM_INTERRUPTS(1),
        .INTERRUPT_TRIGGER_TYPES({FALLING_EDGE})
    ) gateway2 (
        .source(~source),
        .pgif(pgif[2]),
        .*
    );
    gateway #(
        .NUM_INTERRUPTS(1),
        .INTERRUPT_TRIGGER_TYPES({ACTIVE_LOW})
    ) gateway3 (
        .source(~source),
        .pgif(pgif[3]),
        .*
    );

    assign active_high_interrupt_notification = pgif[0].interrupt_notification;
    assign rising_interrupt_notification = pgif[1].interrupt_notification;
    assign falling_interrupt_notification = pgif[2].interrupt_notification;
    assign active_low_interrupt_notification = pgif[3].interrupt_notification;
    assign pgif[0].interrupt_pending = active_high_interrupt_pending;
    assign pgif[1].interrupt_pending = rising_interrupt_pending;
    assign pgif[2].interrupt_pending = falling_interrupt_pending;
    assign pgif[3].interrupt_pending = active_low_interrupt_pending;
    assign pgif[0].interrupt_completed = active_high_interrupt_completed;
    assign pgif[1].interrupt_completed = rising_interrupt_completed;
    assign pgif[2].interrupt_completed = falling_interrupt_completed;
    assign pgif[3].interrupt_completed = active_low_interrupt_completed;
endmodule
