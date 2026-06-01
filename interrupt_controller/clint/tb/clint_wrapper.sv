
module clint_wrapper #(
    parameter NUM_HARTS = 1
)(
    input CLK,
    input nRST,
    // clint
    output [NUM_HARTS-1:0] timer_int, clear_timer_int,
    output [NUM_HARTS-1:0] soft_int, clear_soft_int,
    // bus protocol
    input wen,
    input ren,
    input [31:0] addr,
    input [31:0] wdata,
    input [3:0] strobe,

    output logic request_stall,
    output logic error,
    output logic [31:0] rdata

);

    bus_protocol_if busif();
    clint_if #(.NUM_HARTS(NUM_HARTS)) clif();

    assign timer_int        = clif.timer_int;
    assign clear_timer_int  = clif.clear_timer_int;
    assign soft_int         = clif.soft_int;
    assign clear_soft_int   = clif.clear_soft_int;


    assign busif.wen = wen;
    assign busif.ren = ren;
    assign busif.addr = addr;
    assign busif.wdata = wdata;
    assign busif.strobe = strobe;
    assign rdata = busif.rdata;
    assign error = busif.error;
    assign request_stall = busif.request_stall;

    clint #(.NUM_HARTS(NUM_HARTS)) CLINT(.*);


endmodule
