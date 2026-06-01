`timescale 1ns/1ps
module ahb2apb #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter logic [ADDR_WIDTH-1:0] BASE_ADDR = 'h8000_0000,
    parameter int FIFO_DEPTH = 16,
    parameter int NWORDS = 4096
)(
    ahb_if.subordinate ahbif,
    apb_if.requester   apbif
);

    // ------------------------------------------------------------
    // AHB Address Errors
    // ------------------------------------------------------------
    logic range_error, align_error, ahb_addr_error, return_error;
    localparam int RETURN_WIDTH = DATA_WIDTH + 1;
    logic [RETURN_WIDTH-1:0] return_rdata;

    localparam int WORD_LENGTH = ADDR_WIDTH / 8;
    localparam logic [ADDR_WIDTH-1:0] TOP_ADDR = BASE_ADDR + NWORDS * WORD_LENGTH;
    assign range_error  = (ahbif.HADDR < BASE_ADDR || ahbif.HADDR >= TOP_ADDR);
    assign align_error  = ((ahbif.HADDR & WORD_LENGTH - 1) != 'b0);
    assign ahb_addr_error = range_error | align_error;
    assign return_error = return_rdata [DATA_WIDTH]; //APB PSLVERR through CDC

    // ------------------------------------------------------------
    // Forward FIFO: AHB -> APB
    // ------------------------------------------------------------
    localparam STRB_WIDTH = DATA_WIDTH / 8;
    localparam FORWARD_WIDTH = ADDR_WIDTH + DATA_WIDTH + 1 + STRB_WIDTH;
    // {addr, wdata, write, strobe}

    logic [FORWARD_WIDTH-1:0] forward_packet, forward_packet_next;
    logic forward_winc, forward_winc_next, forward_full;
    logic [FORWARD_WIDTH-1:0] forward_rdata;
    logic forward_rinc, forward_empty;

    // ------------------------------------------------------------
    // Return FIFO: APB -> AHB
    // ------------------------------------------------------------

    // {hresp, rdata}

    logic [RETURN_WIDTH-1:0] return_packet;
    logic return_winc, return_full;
    logic return_rinc, return_rinc_next, return_empty;

    // ------------------------------------------------------------
    // AHB-side logic
    // ------------------------------------------------------------
    logic ahb_valid;
    logic addr_phase_valid;
    logic addr_phase_write;
    logic addr_phase_error;
    logic [ADDR_WIDTH-1:0] latched_addr;
    logic [DATA_WIDTH-1:0] latched_wdata;

    typedef enum logic [1:0] {AHB_IDLE, WAIT, ERROR} ahb_state_t;
    ahb_state_t ahb_state, next_ahb_state;

    assign ahb_valid = ahbif.HSEL && ahbif.HTRANS[1];

    always_ff @(posedge ahbif.HCLK or negedge ahbif.HRESETn) begin
        if (!ahbif.HRESETn) begin
            addr_phase_valid <= 1'b0;
            addr_phase_write <= 1'b0;
            addr_phase_error <= 1'b0;
            latched_wdata <= 'b0;
            latched_addr <= 'b0;
        end else begin
            latched_wdata <= ahbif.HWDATA;
            if (ahb_valid && ahbif.HREADYOUT) begin
                if(ahb_addr_error) begin
                    addr_phase_error <= 1'b1;
                    addr_phase_valid <= 1'b0;
                end else begin
                    addr_phase_valid <= 1'b1;
                    addr_phase_error <= 1'b0;
                    addr_phase_write <= ahbif.HWRITE;
                    latched_addr <= ahbif.HADDR - BASE_ADDR;
                end
            end else begin
                addr_phase_valid <= 1'b0;
                addr_phase_error <= 1'b0;
            end
        end
    end

    always_comb begin
        next_ahb_state = ahb_state;
        casez(ahb_state)
            AHB_IDLE: begin
                if (addr_phase_error) // if addr error go to error state
                        next_ahb_state = ERROR;
                else if (addr_phase_valid) 
                        next_ahb_state = WAIT; //write or read -> wait till response back 
            end 
            WAIT: begin
                if (!return_empty)
                    next_ahb_state = return_error ? ERROR: AHB_IDLE;
            end
            ERROR: begin
                next_ahb_state = AHB_IDLE;
            end 
        endcase
    end

    always_ff @(posedge ahbif.HCLK or negedge ahbif.HRESETn) begin
        if (!ahbif.HRESETn) begin
            ahb_state <= AHB_IDLE;
        end else begin
            ahb_state <= next_ahb_state;
        end
    end

    always_comb begin
        forward_packet_next = 'b0;
        forward_winc_next = 1'b0;
        return_rinc_next = 1'b0;
        ahbif.HREADYOUT = 1'b1;
        ahbif.HRESP = 1'b0;

        casez(ahb_state) 
            AHB_IDLE: begin
                if (addr_phase_error) begin
                    ahbif.HREADYOUT = 1'b0;
                    ahbif.HRESP = 1'b1;
                end else if (addr_phase_valid) begin // execute read or write
                    forward_packet_next = {latched_addr, ahbif.HWDATA, addr_phase_write, ahbif.HWSTRB};
                    ahbif.HREADYOUT = 1'b0;
                    forward_winc_next = 1'b1;
                end
            end 
            WAIT: begin
                ahbif.HREADYOUT = 1'b0;
                if (!return_empty) begin
                    return_rinc_next = 1'b1;
                    if(return_error) begin
                    ahbif.HRESP = 1'b1;
                    end else
                        ahbif.HREADYOUT = 1'b1;
                end
            end
            ERROR: begin //second error cycle HRESP needs to be high for two cycles AMBA protocol.
                ahbif.HREADYOUT = 1'b1;
                ahbif.HRESP = 1'b1 ;
            end
        endcase

        ahbif.HRDATA = return_rdata[DATA_WIDTH-1:0];
       end

    always_ff @(posedge ahbif.HCLK or negedge ahbif.HRESETn) begin
        if (!ahbif.HRESETn) begin
            forward_packet  <= '0;
            forward_winc    <= 1'b0;
            return_rinc     <= 1'b0;
        end else begin
            forward_packet  <= forward_packet_next;
            forward_winc    <= forward_winc_next;
            return_rinc     <= return_rinc_next;
        end
    end

    // ------------------------------------------------------------
    // CDC Forward FIFO
    // ------------------------------------------------------------ 
    socetlib_cdc_fifo #(
        .DATA_WIDTH (FORWARD_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) u_forward_fifo (
        .wdata  (forward_packet),
        .winc   (forward_winc),
        .wclk   (ahbif.HCLK),
        .wnrst  (ahbif.HRESETn),
        .wfull  (forward_full),

        .rdata  (forward_rdata),
        .rinc   (forward_rinc),
        .rclk   (apbif.PCLK),
        .rnrst  (apbif.PRESETn),
        .rempty (forward_empty)
    );

    // ------------------------------------------------------------
    // APB-side logic
    // ------------------------------------------------------------
    typedef enum logic [1:0] {
        APB_IDLE,
        SETUP,
        ACCESS
    } apb_state_t;

    apb_state_t apb_state, apb_next_state;

    logic [ADDR_WIDTH-1:0] latched_apb_addr;
    logic [DATA_WIDTH-1:0] latched_apb_wdata;
    logic latched_write;
    logic [STRB_WIDTH-1:0] latched_strobe;

    always_ff @(posedge apbif.PCLK or negedge apbif.PRESETn) begin
        if (!apbif.PRESETn) begin
            apb_state <= APB_IDLE;
        end else begin
            apb_state <= apb_next_state;
        end
    end

    always_comb begin
        apb_next_state = apb_state;
        casez(apb_state)
            APB_IDLE: begin
                if (!forward_empty) begin
                    apb_next_state = SETUP;
                end
            end
            SETUP: begin
                apb_next_state = ACCESS;
            end
            ACCESS: begin
                if (apbif.PREADY) begin
                    apb_next_state = APB_IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge apbif.PCLK or negedge apbif.PRESETn) begin
        if (!apbif.PRESETn) begin
            latched_apb_addr <= '0;
            latched_apb_wdata <= '0;
            latched_write <= 1'b0;
            latched_strobe <= '0;
        end else begin
            if (apb_state == APB_IDLE && !forward_empty) begin
                latched_strobe <= forward_rdata[STRB_WIDTH-1:0];
                latched_write <= forward_rdata[STRB_WIDTH];
                latched_apb_wdata <= forward_rdata[STRB_WIDTH + 1 +: DATA_WIDTH];
                latched_apb_addr <= forward_rdata[STRB_WIDTH + 1 + DATA_WIDTH +: ADDR_WIDTH];
            end
        end
    end

    always_comb begin
        apbif.PSEL = 1'b0;
        apbif.PENABLE = 1'b0;
        apbif.PADDR = '0;
        apbif.PWDATA = '0;
        apbif.PWRITE = '0;
        apbif.PSTRB = '0;
        forward_rinc = 1'b0;
        return_winc = 1'b0;
        return_packet = '0;

        casez(apb_state)
            APB_IDLE: begin
                if (!forward_empty) begin
                    forward_rinc = 1'b1;
                end
            end
            SETUP: begin
                apbif.PSEL = 1'b1;
                apbif.PENABLE = 1'b0;
                apbif.PADDR = latched_apb_addr;
                apbif.PWDATA = latched_apb_wdata;
                apbif.PWRITE = latched_write;
                apbif.PSTRB = latched_strobe;
            end
            ACCESS: begin
                // Access phase
                apbif.PSEL   = 1'b1;
                apbif.PENABLE = 1'b1;
                apbif.PADDR  = latched_apb_addr;
                apbif.PWDATA = latched_apb_wdata;
                apbif.PWRITE = latched_write;
                apbif.PSTRB = latched_strobe;
                
                if (apbif.PREADY) begin
                    // Transaction completing
                    if (!return_full) begin
                        // Read & Write enqueue resonse
                        return_winc = 1'b1;
                        return_packet = {apbif.PSLVERR, apbif.PRDATA}; // {HRESP= PSLVERR, data}
                    end
                end
            end 
        endcase
    end

    // ------------------------------------------------------------
    // CDC Return FIFO
    // ------------------------------------------------------------
    socetlib_cdc_fifo #(
        .DATA_WIDTH (RETURN_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) u_return_fifo (
        .wdata  (return_packet),
        .winc   (return_winc),
        .wclk   (apbif.PCLK),
        .wnrst  (apbif.PRESETn),
        .wfull  (return_full),

        .rdata  (return_rdata),
        .rinc   (return_rinc),
        .rclk   (ahbif.HCLK),
        .rnrst  (ahbif.HRESETn),
        .rempty (return_empty)
    );

endmodule