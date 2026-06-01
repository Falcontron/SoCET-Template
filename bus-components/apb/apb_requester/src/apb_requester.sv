
module apb_requester (
    apb_if.requester apbif,
    bus_protocol_if.peripheral_vital busif 
);

    typedef enum logic [1:0] {
        IDLE,
        REQUEST,
        DATA
    } state_t;

    typedef struct packed {
        logic [31:0] addr;
        logic [31:0] wdata;
        logic wen; // ren unneeded since only used in data phase, !wen -> ren
        logic [3:0] strobe;
    } request_t;

    state_t state, n_state;
    request_t request, request_n;

    always_ff @(posedge apbif.PCLK, negedge apbif.PRESETn) begin
        if(!apbif.PRESETn) begin
            state <= IDLE;
            request <= '0;
        end else begin
            state <= n_state;
            request <= request_n;
        end
    end

    always_comb begin
        request_n = request;
        if(state == IDLE || (state == DATA && apbif.PREADY)) begin
            request_n.addr = {busif.addr[31:2], 2'b00};
            request_n.wdata = busif.wdata;
            request_n.wen = busif.wen;
            request_n.strobe = busif.strobe;
        end
    end


    // TODO: How does APB work with the memory controller?
    always_comb begin
        n_state = state;
        if(state == IDLE && (busif.ren || busif.wen)) begin
            n_state = REQUEST;
        end else if(state == REQUEST) begin
            n_state = DATA;
        end else if(state == DATA && !apbif.PREADY) begin
            n_state = DATA;
        //end else if(state == DATA && apbif.PREADY && (busif.ren || busif.wen)) begin
        //    n_state = REQUEST;
        end else if(state == DATA && apbif.PREADY) begin//&& !(busif.ren || busif.wen)) begin
            n_state = IDLE;
        end

        /*
        if(state == DATA && !apbif.PREADY) begin
            n_state = state;
        end else if(state == DATA && apbif.PREADY && (busif.ren || busif.wen)) begin
            n_state = REQUEST;
        end else if(state == REQUEST) begin
            n_state = DATA;
        end else begin
            n_state = IDLE;
        end
        */
    end

    always_comb begin
        if(state == IDLE) begin
            apbif.PADDR = '0;
            apbif.PSEL = '0; 
            apbif.PPROT = '0;
            apbif.PENABLE = '0;
            apbif.PWRITE = '0;
            apbif.PSTRB = '0;
        end else if(state == REQUEST) begin
            apbif.PADDR = request.addr;
            apbif.PSEL = 1'b1;
            apbif.PPROT = '0;
            apbif.PENABLE = 1'b0;
            apbif.PWRITE = request.wen;
            apbif.PSTRB = request.strobe;
        end else begin
            apbif.PADDR = request.addr;
            apbif.PSEL = 1'b1;
            apbif.PPROT = '0;
            apbif.PENABLE = 1'b1;
            apbif.PWRITE = request.wen;
            apbif.PSTRB = request.strobe;
        end
    end

    // Response
    assign busif.rdata = apbif.PRDATA;
    assign busif.request_stall = (state == IDLE && (busif.wen || busif.ren)) || (state == REQUEST) || ~apbif.PREADY;
    assign busif.error = apbif.PSLVERR;
    assign apbif.PWDATA = request.wdata;

endmodule
