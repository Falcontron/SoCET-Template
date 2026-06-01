module io_pad #(
    parameter WIDTH = 16
) (
    input logic oe_n,
    input logic [WIDTH-1:0] wdata,
    output logic [WIDTH-1:0] rdata,
    inout wire [WIDTH-1:0] data
);
    assign data = oe_n ? 'bz : wdata;
    assign rdata = data;
    
endmodule