module apb_interconnect_wrapper #(
    parameter int NCOMPLETERS = 2,
    parameter int COMPLETER_ADDR_BITS = 16,
    parameter logic [31:0] BUS_REGION_BEGIN = 32'h80000000
)(
    input CLK,
    input nRST
);

    apb_if requester(CLK, nRST);
    apb_if completers[NCOMPLETERS](CLK, nRST);

    apb_interconnect #(
        .NCOMPLETERS,
        .COMPLETER_ADDR_BITS,
        .BUS_REGION_BEGIN
    ) APBI (
        .*
    );

endmodule
