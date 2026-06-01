
module pwm_wrapper#(
    parameter NUM_CHANNELS = 2   
)(
    input CLK,
    input nRST,
    output logic [NUM_CHANNELS-1:0] pwm_out,
    bus_protocol_if.peripheral_vital busif
);
    localparam int NUM_REG_PER_CHAN = 3;
    localparam int NUM_REGS = NUM_REG_PER_CHAN * NUM_CHANNELS;

    localparam PERIOD_IND = 0;
    localparam DUTY_IND = 1;
    localparam COUNT_IND = 2;

    genvar i;

    logic [NUM_REGS-1:0] addr_match;
    logic [NUM_REGS-1:0] wen;
    logic [NUM_REGS-1:0] ren;

    // Write only module
    assign busif.error = 1'b0;
    assign busif.rdata = 1'b0;
    assign busif.request_stall = 1'b0;

    generate
        for(i = 0; i < NUM_REGS; i++) begin : g_wen_ren
            assign addr_match[i] = (busif.addr == i*4);
            assign wen[i] = (busif.wen && addr_match[i]);
            assign ren[i] = (busif.ren && addr_match[i]);
        end
    endgenerate

    generate
        for(i = 0; i < NUM_CHANNELS; i++) begin : g_pwm_channel
            pwmchannel CHANNEL(
                .clk(CLK),
                .n_rst(nRST),
                .pwm_out(pwm_out[i]),
                .cont_wen(wen[(i*NUM_REG_PER_CHAN) + COUNT_IND]),
                .period_wen(wen[(i*NUM_REG_PER_CHAN) + PERIOD_IND]),
                .duty_wen(wen[(i*NUM_REG_PER_CHAN) + DUTY_IND]),
                .duty_in(busif.wdata),
                .period_in(busif.wdata),
                .control_in(busif.wdata[2:0])
            );
        end
    endgenerate

endmodule
