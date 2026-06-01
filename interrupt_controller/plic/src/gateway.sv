import plic_pkg::*;

// Handles incoming interrupt sources and relays them in a common format. The
// `pgif.interrupt_request` signal is an active high signal which is converted
// from rising edge, falling edge, or level triggered interrupt sources as
// declared by `INTERRUPT_TRIGGER_TYPE`. If `INTERRUPT_TRIGGER_TYPE` is
// `FALLING_EDGE` or `RISING_EDGE` then `EDGE_WANTS_COUNTER` will be used to
// determine whether or not to count interrupt requests observed after an
// interrupt has been fired, otherwise it is ignored.
module gateway#(
    parameter NUM_INTERRUPTS = 32,
    parameter interrupt_trigger_e [NUM_INTERRUPTS-1:0] INTERRUPT_TRIGGER_TYPES = '{NUM_INTERRUPTS{ACTIVE_HIGH}},
    parameter logic [NUM_INTERRUPTS-1:0] EDGE_WANTS_COUNTER = {NUM_INTERRUPTS{1'b1}}
) (
    input logic clk,
    input logic nrst,
    input logic [NUM_INTERRUPTS-1:0] source,
    plic_gateway_if.gateway pgif
);
    logic [NUM_INTERRUPTS-1:0] interrupt_requested;

    typedef enum logic [1:0] {
        waiting_for_trigger,
        waiting_for_core_claim,
        waiting_for_completion
    } gateway_state_e;

    gateway_state_e [NUM_INTERRUPTS-1:0] state;
    gateway_state_e [NUM_INTERRUPTS-1:0] next_state;

    // Generate different logic for interrupt_requested signal
    genvar i;
    generate 
        for (i = 0; i < NUM_INTERRUPTS; i = i + 1) begin : g_interrupt_requested
            // If it's level triggered, the source will stay active as long as
            // an interrupt is requested.
            if (INTERRUPT_TRIGGER_TYPES[i] == ACTIVE_HIGH) begin
                assign interrupt_requested[i] = source[i];
            end else if (INTERRUPT_TRIGGER_TYPES[i] == ACTIVE_LOW) begin
                assign interrupt_requested[i] = ~source[i];
            end else begin
                // For an edge triggered interrupt, we only need to do edge
                // detection. The spec allows for handling multiple matching edges
                // with a counter which is handled by the `EDGE_WANTS_COUNTER`
                // parameter. The counter will be decremented after the interrupt
                // has been claimed. The counter saturates to 255.
                logic edge_detected;
                logic [7:0] pending_interrupts;
                logic [7:0] pending_interrupts_next;

                // Saturating logic for an 8 bit counter
                always_comb begin
                    if (pending_interrupts == 255) pending_interrupts_next = pending_interrupts;
                    else if (state[i] == waiting_for_core_claim && next_state[i] == waiting_for_completion) pending_interrupts_next = pending_interrupts - 1;
                    else pending_interrupts_next = pending_interrupts + edge_detected;
                end

                // Update `pending_interrupts` counter
                always_ff @(posedge clk, negedge nrst) begin
                    if (!nrst) pending_interrupts <= 'h0;
                    else if (EDGE_WANTS_COUNTER[i]) pending_interrupts <= pending_interrupts_next;
                end

                if (INTERRUPT_TRIGGER_TYPES[i] == RISING_EDGE)
                    socetlib_edge_detector ed(
                        .CLK(clk),
                        .nRST(nrst),
                        .signal(source[i]),
                        .pos_edge(edge_detected),
                        .neg_edge()
                    );
                else
                    socetlib_edge_detector #(
                        .RESET(1)
                    ) ed(
                        .CLK(clk),
                        .nRST(nrst),
                        .signal(source[i]),
                        .pos_edge(),
                        .neg_edge(edge_detected)
                    );

                assign interrupt_requested[i] = EDGE_WANTS_COUNTER[i] ? |pending_interrupts : edge_detected;
            end
        end
    endgenerate

    // Next state logic
    always_comb begin
        for (int i = 0; i < NUM_INTERRUPTS; i = i + 1) begin
            next_state[i] = state[i];
            case (state[i])
                waiting_for_trigger : begin
                    if (interrupt_requested[i]) next_state[i] = waiting_for_core_claim;
                end
                waiting_for_core_claim : begin
                    if (pgif.interrupt_pending[i]) next_state[i] = waiting_for_completion;
                end
                waiting_for_completion : begin
                    if (pgif.interrupt_completed[i]) next_state[i] = waiting_for_trigger;
                end
                default : begin
                end
            endcase
        end
    end

    // Update state
    always_ff @(posedge clk, negedge nrst) begin
        if (!nrst) begin
            state <= '{NUM_INTERRUPTS{waiting_for_trigger}};
        end else begin
            state <= next_state;
        end
    end

    // Send signals to interface
    always_comb begin
        for (int i = 0; i < NUM_INTERRUPTS; i = i + 1) begin
            pgif.interrupt_notification[i] = state[i] == waiting_for_core_claim;
            pgif.interrupt_still_requested[i] = (INTERRUPT_TRIGGER_TYPES[i] == ACTIVE_HIGH || INTERRUPT_TRIGGER_TYPES[i] == ACTIVE_LOW) ?
                interrupt_requested[i] :
                1'b1;
        end
    end
endmodule
