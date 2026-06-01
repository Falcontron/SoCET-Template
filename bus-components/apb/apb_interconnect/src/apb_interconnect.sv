
module apb_interconnect #(
    parameter int NCOMPLETERS = 2,
    parameter int COMPLETER_ADDR_BITS = 16,
    parameter logic [31:0] BUS_REGION_BEGIN = 32'h80000000,
    parameter logic [31:0] APB_MAP[NCOMPLETERS] = '{default: '0}
) (
    // Note: From perspective of requester, interconnect is a "completer",
    // and vice-versa, hence modports being opposite of names. Names here
    // indicate source of the signal, NOT direction!
    apb_if.completer requester,
    apb_if.requester completers[NCOMPLETERS]
);

    // Addressing
    // COMPLETER_ADDR_BITS is the address "suffix" that is used within completers
    // The completer will be selected based on the 32-COMPLETER_ADDR_BITS prefix
    // APB_MAP must provide the 32b addresses consisting of {prefix, suffix} for each
    // completer index (i.e. mapping between completer 0 and completer 0's base address)

    logic [31:0] PRDATA_arr[NCOMPLETERS];
    logic PSLVERR_arr[NCOMPLETERS];
    logic PREADY_arr[NCOMPLETERS];
    logic addr_match_arr[NCOMPLETERS];
    genvar i; // Quartus does not accept this declared inline

    function automatic logic addr_match(logic [31:0] bus_addr, int completer_idx);
        return (bus_addr >= APB_MAP[completer_idx] && (completer_idx == NCOMPLETERS-1 || bus_addr < APB_MAP[(completer_idx + 1) % NCOMPLETERS]));
    endfunction

    generate
        for(i = 0; i < NCOMPLETERS; i++) begin : g_addr_match
            assign addr_match_arr[i] = addr_match(requester.PADDR, i);
        end
    endgenerate


    // This just implements simple multiplexing, no logic needed
    generate
        for (i = 0; i < NCOMPLETERS; i++) begin : g_request
            assign completers[i].PADDR   = requester.PADDR;
            assign completers[i].PWDATA  = requester.PWDATA;
            assign completers[i].PSTRB   = requester.PSTRB;
            assign completers[i].PPROT   = requester.PPROT;
            assign completers[i].PWRITE  = requester.PWRITE;
            assign completers[i].PENABLE = requester.PENABLE;
            assign completers[i].PSEL    = (requester.PSEL && addr_match_arr[i]);
        end
    endgenerate

    // NOTE: This is a path from requester.PSEL -> requester.PREADY.
    // Requesters must be careful not to incur comb. loop
    always_comb begin : response
        requester.PRDATA  = 32'hBAD1BAD1;
        requester.PREADY  = 1'b1;
        // Error defaults to 0, unless we're in data phase. In data phase, return error if no addresses matched.
        requester.PSLVERR = (requester.PSEL && requester.PENABLE);
        for (int i = 0; i < NCOMPLETERS; i++) begin
            if (requester.PSEL && addr_match_arr[i]) begin
                // Note: This indirection (assign iface -> array, array -> iface)
                // is a limitation of tools not supporting arrays of interface fully.
                // Ideally we could do as above, but since this must be "always_comb" rather
                // than "generate", "i" is treated as a non-const index
                requester.PRDATA  = PRDATA_arr[i];
                requester.PREADY  = PREADY_arr[i];
                requester.PSLVERR = PSLVERR_arr[i];
            end
        end
    end

    generate
        for (i = 0; i < NCOMPLETERS; i++) begin : g_unpack_response
            assign PREADY_arr[i]  = completers[i].PREADY;
            assign PSLVERR_arr[i] = completers[i].PSLVERR;
            assign PRDATA_arr[i]  = completers[i].PRDATA;
        end
    endgenerate

endmodule
