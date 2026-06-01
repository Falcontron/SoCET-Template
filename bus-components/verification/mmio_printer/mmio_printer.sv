
module mmio_printer(
    input CLK,
    bus_protocol_if.peripheral_vital busif
);

    assign busif.rdata = '0;
    assign busif.error = '0;
    assign busif.request_stall = '0;

    // Writing a single character
    always_ff @(posedge CLK) begin
        if(busif.wen) begin
            casez(busif.strobe)
                'b1: if(busif.wdata[7:0] != 0) $write("%s", busif.wdata[7:0]);
                default: $write("Direct Hex: %x\n", busif.wdata);
            endcase
        end
    end


endmodule
