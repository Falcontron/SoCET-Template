module interrupt_priority#(
    parameter int NUM_INTERRUPTS = 32,
    parameter int PRIORITY_REGISTER_WIDTH = 8
)(
    input [NUM_INTERRUPTS-1:0] interrupt_pending,
    input [NUM_INTERRUPTS-1:0] [PRIORITY_REGISTER_WIDTH-1:0] interrupt_priority,
    output logic [$clog2(NUM_INTERRUPTS + 1)-1:0] max_priority_id,
    output logic [PRIORITY_REGISTER_WIDTH-1:0] max_priority
);
    logic [NUM_INTERRUPTS-1:0] [$clog2(NUM_INTERRUPTS+1)-1:0] ids;

    always_comb begin
        for (int i = 0; i < NUM_INTERRUPTS; i++) begin
            ids[i] = i + 1;
        end
    end


    priority_tree#(
        .NUM_INTERRUPTS(NUM_INTERRUPTS),
        .PRIORITY_REGISTER_WIDTH(PRIORITY_REGISTER_WIDTH)
    ) PRIOHELPER (
        .interrupt_pending,
        .ids,
        .interrupt_priority,
        .max_priority_id,
        .max_priority
    );
endmodule
