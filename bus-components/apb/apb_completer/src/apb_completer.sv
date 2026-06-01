
module apb_completer #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter logic [ADDR_WIDTH-1:0] BASE_ADDR = 'h8000_0000,
    parameter int NWORDS = 4 // # of words of address space to cover (address space)
)(
    apb_if.completer apbif,
    bus_protocol_if.protocol protif
);

`ifndef SYNTHESIS
    if(NWORDS <= 0) begin
        $error("%s (%s): APB Completer MUST have at least 1 word of address space!\n", `__FILE__, `__LINE__);
    end
`endif

    localparam WORD_LENGTH = ADDR_WIDTH / 8;
    localparam TOP_ADDR = BASE_ADDR + NWORDS*WORD_LENGTH;
    
    typedef enum logic [1:0] {
        IDLE,
        ACCESS,
        ERROR
    } APBState;

    APBState state, state_next;

    logic [ADDR_WIDTH-1:0] decoded_addr;
    logic [ADDR_WIDTH-1:0] offset_next;
    logic WEN_next, REN_next;
    logic [3:0] write_strobe_next;
    logic request_error; // TODO: Currently not factoring in protif.error. Is this even a valuable signal? Should we permit data phase errors?

    /*
    * Hint signals
    */
    // Remove burst transfer hints
    assign protif.is_burst = 0;
    assign protif.burst_type = 0;
    assign protif.burst_length = 0;
   
    // Secure transfer when PPROT[1] = 1
    // TODO: PPROT[0] and PPROT[2] ignored currently
    assign protif.secure_transfer = apbif.PPROT[1];
   
    /*
    *   Function: Latch address phase signals and provide to module.
    *   Data phase: Provide wdata signal. If we get request_error/stall, handle
    *   condition.
    */

    always_ff @(posedge apbif.PCLK, negedge apbif.PRESETn) begin
        if(!apbif.PRESETn) begin
            state <= IDLE;
        end else begin
            state <= state_next;
        end
    end

    always_comb begin : STATE_UPDATE
        casez(state)
            IDLE: begin
                if(apbif.PSEL && request_error) begin
                    state_next = ERROR;
                end else if(apbif.PSEL && !request_error) begin
                    state_next = ACCESS;
                end else begin
                    state_next = IDLE;
                end
            end

            ACCESS: begin
                if(protif.request_stall) begin
                    state_next = ACCESS;
                end else begin
                    state_next = IDLE;
                end
            end

            ERROR: begin
                state_next = IDLE;
            end
            
            // This is unreachable due to enum definition, but
            // requires definition by some tools
            default: state_next = IDLE;
        endcase
    end : STATE_UPDATE




    /*
    * Address Decode + Address request_error checks
    */
    assign decoded_addr = apbif.PADDR - BASE_ADDR;

    logic range_error;
    logic align_error;
    
    assign range_error = (apbif.PADDR < BASE_ADDR || apbif.PADDR >= TOP_ADDR);
    assign align_error = ((apbif.PADDR & WORD_LENGTH-1) != 'b0); // WORD_LENGTH - 1 is a mask for the required-zero bits if access is aligned
    assign request_error = apbif.PSEL && (range_error || align_error);
    
    /*
    * Latched signals
    */
    always_comb begin : CONTROL_LATCH
        write_strobe_next = '0;
        WEN_next = 1'b0;
        REN_next = 1'b0;
        offset_next = '0;

        casez(state)
            IDLE: begin
                WEN_next = apbif.PSEL & apbif.PWRITE & ~request_error;
                REN_next = apbif.PSEL & ~apbif.PWRITE & ~request_error;
                write_strobe_next = apbif.PSTRB;
                offset_next = decoded_addr;
            end

            ACCESS: begin
                // Only case to maintain is when we stall
                if(protif.request_stall) begin
                    WEN_next = protif.wen;
                    REN_next = protif.ren;
                    write_strobe_next = protif.strobe;
                    offset_next = protif.addr;
                end
            end
        endcase
    end : CONTROL_LATCH

    always_ff @(posedge apbif.PCLK, negedge apbif.PRESETn) begin
        if(!apbif.PRESETn) begin
            protif.wen <= 1'b0;
            protif.ren <= 1'b0;
            protif.strobe <= 4'b0;
            protif.addr <= 32'b0;
        end else begin
            protif.wen <= WEN_next;
            protif.ren <= REN_next;
            protif.strobe <= write_strobe_next;
            protif.addr <= offset_next;
        end
    end

    /*
    *   Data Phase
    */
    assign apbif.PSLVERR = (state == ERROR) || request_error;
    assign apbif.PREADY = !protif.request_stall;
    assign apbif.PRDATA = protif.rdata;
    assign protif.wdata = apbif.PWDATA;

endmodule
