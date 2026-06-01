module plic_core #(
    parameter NUM_CONTEXTS = 1,
    // Most uses of `NUM_INTERRUPTS` will use `NUM_INTERRUPTS` not
    // `NUM_INTERRUPTS-1` due to the implied interrupt 0.
    // This relies on the compiler to optimize out the backing storage for
    // interrupt 0.
    parameter NUM_INTERRUPTS = 32,
    parameter PRIORITY_REGISTER_WIDTH = 8
)(
    input logic clk,
    input logic nrst,
    bus_protocol_if.peripheral_vital busif,
    plic_if.ic plicif,
    plic_gateway_if.plic_core pgif
);
    assign busif.request_stall = 0;
    // Number of words needed to contain `NUM_INTERRUPTS` as a packed word.
    localparam NUM_PACKED_INTERRUPTS = (NUM_INTERRUPTS + 32 - 1) / 32;
    // Number of used bits in the final word of a packed word of signals.
    localparam NUM_UNDERFIT_INTERRUPTS = (NUM_INTERRUPTS + 1) % 32;
    // Address generation
    localparam logic [31:0] INTERRUPT_BASE_ADDR                    = 32'h0,
                            INTERRUPT_PRIORITY_BASE_ADDR           = INTERRUPT_BASE_ADDR + 32'h0,
                            INTERRUPT_PRIORITY_BASE_ADDR_MAX       = INTERRUPT_PRIORITY_BASE_ADDR + (NUM_INTERRUPTS * 4),
                            INTERRUPT_PENDING_BASE_ADDR            = INTERRUPT_BASE_ADDR + 32'h1000,
                            INTERRUPT_PENDING_BASE_ADDR_MAX        = INTERRUPT_PENDING_BASE_ADDR + (NUM_PACKED_INTERRUPTS * 4),
                            INTERRUPT_ENABLE_BASE_ADDR             = INTERRUPT_BASE_ADDR + 32'h2000,
                            INTERRUPT_ENABLE_BASE_ADDR_MAX         = INTERRUPT_ENABLE_BASE_ADDR + (NUM_PACKED_INTERRUPTS * 4) + ((NUM_CONTEXTS - 1) * 'h80),
                            PRIORITY_THRESHOLD_BASE_ADDR           = INTERRUPT_BASE_ADDR + 32'h200000,
                            PRIORITY_THRESHOLD_BASE_ADDR_MAX       = PRIORITY_THRESHOLD_BASE_ADDR + ((NUM_CONTEXTS - 1) * 'h1000),
                            INTERRUPT_CLAIM_COMPLETE_BASE_ADDR     = INTERRUPT_BASE_ADDR + 32'h200004,
                            INTERRUPT_CLAIM_COMPLETE_BASE_ADDR_MAX = INTERRUPT_CLAIM_COMPLETE_BASE_ADDR + ((NUM_CONTEXTS - 1) * 'h1000);

    // Converts a packed index to a normal index usually needing a +:32 to
    // select 32 bits.
    function logic [$clog2(NUM_INTERRUPTS):0] packed_idx_to_idx(int i);
        packed_idx_to_idx = i * 32;
    endfunction
    
    // Logic for possible bus errors
    logic bus_rerr, bus_werr;
    assign busif.error = busif.ren ? bus_rerr :
                         busif.wen ? bus_werr :
                         1'b0;

    // Interrupt priority registers as defined in Chapter 4 of the PLIC spec v1.0
    // Supports up to 2^`PRIORITY_REGISTER_WIDTH` - 1 different priority
    // levels.
    logic [NUM_INTERRUPTS:0] [PRIORITY_REGISTER_WIDTH-1:0] interrupt_priority, interrupt_priority_next;
    // Interrupt pending registers as defined in Chapter 5 of the PLIC spec v1.0.
    // Active high after a gateway brings `pgif.interrupt_notification` high
    // until it has been claimed by a context.
    logic [NUM_INTERRUPTS:0] interrupt_pending, interrupt_pending_next;
    // Interrupt enabled registers as defined in Chapter 6 of the PLIC spec v1.0
    logic [NUM_CONTEXTS-1:0] [NUM_INTERRUPTS:0] interrupt_enabled, interrupt_enabled_next;
    // Priority threshold registers as defined in Chapter 7 of the PLIC spec v1.0
    logic [NUM_CONTEXTS-1:0] [PRIORITY_REGISTER_WIDTH-1:0] priority_threshold, priority_threshold_next;
    // Interrupt claim registers as defined in Chapter 8 of the PLIC spec v1.0
    // Stays high from when an interrupt is claimed to when it is completed
    logic [NUM_INTERRUPTS:0] interrupt_claim;
    logic [NUM_INTERRUPTS:0] interrupt_being_claimed, interrupt_being_completed;

    // Logic for determining the ID of the maximum priority interrupt
    logic [$clog2(NUM_INTERRUPTS + 1)-1:0] max_priority_id;
    // Intermediate signal to determine the previous maximum priority seen in
    // the scan
    logic [PRIORITY_REGISTER_WIDTH-1:0] max_priority;

    // Intermediate signal to determine if interrupt is still requested, padded with 0
    logic [NUM_INTERRUPTS : 0] i_interrupt_still_requested;

    assign i_interrupt_still_requested = {pgif.interrupt_still_requested, 1'b0};

    // Update registers
    always_ff @(posedge clk, negedge nrst) begin
        if (~nrst) begin
            interrupt_priority <= '0; // Disable all interrupts by default
            interrupt_pending  <= '0;
            interrupt_enabled  <= '0;
            priority_threshold <= '0;
            interrupt_claim    <= '0;
        end else begin
            interrupt_priority <= interrupt_priority_next;
            interrupt_pending  <= interrupt_pending_next;
            interrupt_enabled  <= interrupt_enabled_next;
            priority_threshold <= priority_threshold_next;
            interrupt_claim    <= (interrupt_claim | interrupt_being_claimed) & ~interrupt_being_completed;
        end
    end

    logic [$clog2(NUM_INTERRUPTS)-1:0] interrupt_priority_interrupt_sel;
    logic [$clog2(NUM_CONTEXTS)-1:0] interrupt_enable_context_sel, priority_claim_context_sel;
    logic [4:0] interrupt_enable_interrupt_sel;
    logic addr_is_priority_thresh, addr_is_claim_complete;

    assign interrupt_priority_interrupt_sel = busif.addr[2+:$clog2(NUM_INTERRUPTS)];
    assign interrupt_enable_context_sel = busif.addr[7+:$clog2(NUM_CONTEXTS)];
    assign interrupt_enable_interrupt_sel = busif.addr[6:2];
    assign addr_is_priority_thresh = busif.addr[11:0] == 'h0;
    assign addr_is_claim_complete = busif.addr[11:0] == 'h4;
    assign priority_claim_context_sel = busif.addr[12+:$clog2(NUM_CONTEXTS)];

    // Handle bus reads
    always_comb begin
        bus_rerr = 1'b1;
        busif.rdata = 32'hBAD1BAD1;
        interrupt_being_claimed = '0;
        interrupt_pending_next = interrupt_pending | {pgif.interrupt_notification, 1'b0};
        if (busif.addr <= INTERRUPT_PRIORITY_BASE_ADDR_MAX && busif.ren) begin
            bus_rerr = 1'b0;
            busif.rdata = interrupt_priority[interrupt_priority_interrupt_sel];
        end else if (busif.addr >= INTERRUPT_PENDING_BASE_ADDR && busif.addr <= INTERRUPT_PENDING_BASE_ADDR_MAX && busif.ren) begin
            bus_rerr = 1'b0;
            // Pad out underfit words with 0
            if (busif.addr == INTERRUPT_PENDING_BASE_ADDR_MAX) begin
                busif.rdata = {{(32-NUM_UNDERFIT_INTERRUPTS){1'b0}}, interrupt_pending[NUM_INTERRUPTS-:NUM_UNDERFIT_INTERRUPTS]};
            end else begin
                busif.rdata = interrupt_pending[packed_idx_to_idx(interrupt_priority_interrupt_sel)+:32];
            end
        end else if (busif.addr >= INTERRUPT_ENABLE_BASE_ADDR && busif.addr <= INTERRUPT_ENABLE_BASE_ADDR_MAX && interrupt_enable_interrupt_sel <= NUM_PACKED_INTERRUPTS && busif.ren) begin
            bus_rerr = 1'b0;
            // Pad out underfit bits with 0
            if (interrupt_enable_interrupt_sel == NUM_PACKED_INTERRUPTS) begin
                busif.rdata = {{(32-NUM_UNDERFIT_INTERRUPTS){1'b0}}, interrupt_enabled[interrupt_enable_context_sel][NUM_INTERRUPTS-:NUM_UNDERFIT_INTERRUPTS]};
            end else begin
                busif.rdata = interrupt_enabled[interrupt_enable_context_sel][packed_idx_to_idx(interrupt_enable_interrupt_sel)+:32];
            end
        end else if (busif.addr >= PRIORITY_THRESHOLD_BASE_ADDR && busif.addr <= PRIORITY_THRESHOLD_BASE_ADDR_MAX && addr_is_priority_thresh && busif.ren) begin
            bus_rerr = 1'b0;
            busif.rdata = priority_threshold[priority_claim_context_sel];
        end else if (busif.addr >= INTERRUPT_CLAIM_COMPLETE_BASE_ADDR && busif.addr <= INTERRUPT_CLAIM_COMPLETE_BASE_ADDR_MAX && addr_is_claim_complete && busif.ren) begin
            bus_rerr = 1'b0;
            if (max_priority_id > 0 && interrupt_enabled[priority_claim_context_sel][max_priority_id]) begin
                interrupt_pending_next[max_priority_id] = 1'b0;
            end
            if (i_interrupt_still_requested[max_priority_id] && interrupt_enabled[priority_claim_context_sel][max_priority_id]) begin
                busif.rdata = max_priority_id;
                interrupt_being_claimed[max_priority_id] = 1'b1;
            end else begin
                busif.rdata = 'h0;
            end
        end
    end

    // Truncated wdata to be used to represent an interrupt source
    logic [$clog2(NUM_INTERRUPTS)-1:0] wdata_interrupt;

    // Handle bus writes
    always_comb begin
        // Causes last test to fail
        interrupt_being_completed = 'b0;
        wdata_interrupt = busif.wdata[$clog2(NUM_INTERRUPTS)-1:0];

        interrupt_priority_next = interrupt_priority;
        priority_threshold_next = priority_threshold;
        interrupt_enabled_next = interrupt_enabled;
        bus_werr = 1'b1;

        if (busif.addr <= INTERRUPT_PRIORITY_BASE_ADDR_MAX && busif.wen) begin
            bus_werr = 1'b0;
            interrupt_priority_next[interrupt_priority_interrupt_sel] = busif.wdata[PRIORITY_REGISTER_WIDTH-1:0];
        end else if (busif.addr >= INTERRUPT_ENABLE_BASE_ADDR && busif.addr <= INTERRUPT_ENABLE_BASE_ADDR_MAX && interrupt_enable_interrupt_sel <= NUM_PACKED_INTERRUPTS && busif.wen) begin
            bus_werr = 1'b0;
            interrupt_enabled_next[interrupt_enable_context_sel][packed_idx_to_idx(interrupt_enable_interrupt_sel)+:32] = busif.wdata;
            // Ensure writes to bit 0 of word 0 are shifted to ignore writes to interrupt 0
            if (interrupt_enable_interrupt_sel == 0) interrupt_enabled_next[interrupt_enable_context_sel][0] = 1'b0;
        end else if (busif.addr >= PRIORITY_THRESHOLD_BASE_ADDR && busif.addr <= PRIORITY_THRESHOLD_BASE_ADDR_MAX && addr_is_priority_thresh && busif.wen) begin
            bus_werr = 1'b0;
            priority_threshold_next[priority_claim_context_sel] = busif.wdata[PRIORITY_REGISTER_WIDTH-1:0];
        end else if (busif.addr >= INTERRUPT_CLAIM_COMPLETE_BASE_ADDR && busif.addr <= INTERRUPT_CLAIM_COMPLETE_BASE_ADDR_MAX && addr_is_claim_complete && busif.wen) begin
            // Logic for whether an interrupt is being marked as completed by the core
            // The spec defines that the completion ID not necessarily match the
            // claimed interrupt ID, only that the ID be enabled
            if (interrupt_enabled[priority_claim_context_sel][wdata_interrupt]) begin
                interrupt_being_completed[wdata_interrupt] = 1'b1;
            end
            bus_werr = 1'b0;
        end
    end

    // Determine maximum priority interrupt
    interrupt_priority #(
        .NUM_INTERRUPTS(NUM_INTERRUPTS),
        .PRIORITY_REGISTER_WIDTH(PRIORITY_REGISTER_WIDTH)
    ) PRIORITIZER (
        .interrupt_pending(interrupt_pending[1 +: NUM_INTERRUPTS]),
        .interrupt_priority(interrupt_priority[1 +: NUM_INTERRUPTS]),
        .max_priority_id,
        .max_priority
    );

    // Forward interrupt requests to different hart contexts depending on
    // their threshold
    always_comb begin
        for (int i = 0; i < $size(plicif.interrupt_service_request); i = i + 1) begin
            plicif.interrupt_service_request[i] = (max_priority > priority_threshold[i]) & interrupt_enabled[i][max_priority_id];
        end
    end

    // Forward signals to gateway
    assign pgif.interrupt_pending = interrupt_pending[NUM_INTERRUPTS:1];
    assign pgif.interrupt_completed = interrupt_being_completed[NUM_INTERRUPTS:1];
endmodule
