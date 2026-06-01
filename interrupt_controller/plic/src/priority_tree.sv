module priority_tree#(
    // Here, NUM_INTERRUPTS are actual interrupts, not including fake
    // interrupt 0
    parameter int NUM_INTERRUPTS = 32,
    parameter int ID_WIDTH = $clog2(NUM_INTERRUPTS + 1),
    parameter int PRIORITY_REGISTER_WIDTH = 8
)(
    input [NUM_INTERRUPTS-1 : 0] interrupt_pending,
    input [NUM_INTERRUPTS-1 : 0] [ID_WIDTH-1 : 0] ids,
    input [NUM_INTERRUPTS-1 : 0] [PRIORITY_REGISTER_WIDTH-1 : 0] interrupt_priority,
    output logic [ID_WIDTH-1 : 0] max_priority_id,
    output logic [PRIORITY_REGISTER_WIDTH-1 : 0] max_priority
);
    generate
        if (NUM_INTERRUPTS == 1) begin
            assign max_priority_id = interrupt_pending[0] ? ids[0] : 0;
            assign max_priority = interrupt_pending[0] ? interrupt_priority[0] : 0;
        end else begin
            logic [ID_WIDTH-1:0] left_max_priority_id, right_max_priority_id;
            logic [PRIORITY_REGISTER_WIDTH-1:0] left_max_priority, right_max_priority;

            priority_tree #(
                .NUM_INTERRUPTS(NUM_INTERRUPTS / 2),
                .ID_WIDTH(ID_WIDTH),
                .PRIORITY_REGISTER_WIDTH(PRIORITY_REGISTER_WIDTH)
            ) LEFT (
                .interrupt_pending(interrupt_pending[0+:NUM_INTERRUPTS/2]),
                .ids(ids[0+:NUM_INTERRUPTS/2]),
                .interrupt_priority(interrupt_priority[0+:NUM_INTERRUPTS/2]),
                .max_priority_id(left_max_priority_id),
                .max_priority(left_max_priority)
            );
            priority_tree #(
                .NUM_INTERRUPTS(NUM_INTERRUPTS / 2),
                .ID_WIDTH(ID_WIDTH),
                .PRIORITY_REGISTER_WIDTH(PRIORITY_REGISTER_WIDTH)
            ) RIGHT (
                .interrupt_pending(interrupt_pending[NUM_INTERRUPTS/2+:NUM_INTERRUPTS/2]),
                .ids(ids[NUM_INTERRUPTS/2+:NUM_INTERRUPTS/2]),
                .interrupt_priority(interrupt_priority[NUM_INTERRUPTS/2+:NUM_INTERRUPTS/2]),
                .max_priority_id(right_max_priority_id),
                .max_priority(right_max_priority)
            );

            always_comb begin
                max_priority_id = 0;
                max_priority = 0;
                // In cases of priority tie, spec says that small IDs hold
                // precendence. Left will always be smaller than right since
                // it is the lower half of the interrupt array
                if (left_max_priority >= right_max_priority ||
                    left_max_priority == right_max_priority) begin
                    max_priority_id = left_max_priority_id;
                    max_priority = left_max_priority;
                end else begin
                    max_priority_id = right_max_priority_id;
                    max_priority = right_max_priority;
                end
            end
        end
    endgenerate
endmodule
