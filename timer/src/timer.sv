 module advanced_timer
#(
    parameter int CHANNELS = 8,
    parameter int BITS_WIDTH = 32
)
(
    input logic clk, n_rst, 
    /*
    input logic [CHANNELS - 1: 0] t_in,
    output logic [CHANNELS - 1: 0] t_out,
    output logic [CHANNELS - 1: 0] t_irq,
    output logic tc_irq,
    */
    timer_if.timer timerif,
    bus_protocol_if.peripheral_vital busif
);

localparam int MAX_CHNNL = CHANNELS - 1;
localparam int MAX_BIT = BITS_WIDTH - 1;
//localparam int BUS_DATA_WIDTH = $bits(busif.rdata);

genvar i;

//timer Register indicies
localparam int TCNT_IND = 0;  //32'hXXXXX000
localparam int TCR_IND = 1;  //32'hXXXXX004
localparam int TPSC_IND = 2;  //32'hXXXXX008
localparam int TARR_IND = 3;  //32'hXXXXX00C
/*
logic [MAX_CHNNL:0] [MAX_BIT:0] TCCMR_IND; //variable number of TCCMR and TCCR registers
logic [MAX_CHNNL:0] [MAX_BIT:0] TCCR_IND;
*/
localparam int TCCMR_IND = TARR_IND + 1;
localparam int TCCR_IND = TARR_IND + CHANNELS + 1;

logic [MAX_BIT:0] tcnt, nxt_tcnt, tcr, nxt_tcr, tpsc, nxt_tpsc, tarr, nxt_tarr;
logic [MAX_CHNNL:0] [MAX_BIT:0] tccmr;
logic [MAX_CHNNL:0] [MAX_BIT:0] tccr;

/*
generate
    for(i = 0; i < CHANNELS; i++) begin
        assign TCCMR_IND[i] = TARR_IND + i + 1; //may need to check cast of int to logic in SV
        assign TCCR_IND[i] = TARR_IND + CHANNELS + i + 1;
    end
endgenerate
*/
localparam int NUM_REGISTERS = 2 * CHANNELS + 4;

// bus information
logic [NUM_REGISTERS - 1 : 0][31:0] bus_read;
logic [NUM_REGISTERS - 1:0] reg_select;
logic [31:0] strobe_expanded;  // 32b since max pins are 32
logic [MAX_CHNNL:0] error;

assign reg_select = 1 << (busif.addr >> 2);  // Offset addr in multiples of 4
assign busif.rdata = bus_read[(busif.addr>>2)];
assign busif.request_stall = 0;
assign busif.error = |error[MAX_CHNNL:0]; //will need to change this in case of invalid write

generate
    for (i = 0; i < 4; i++) begin : gen_strobe
        if (i < BITS_WIDTH / 8) begin : gen_strobe_data
            assign strobe_expanded[8*i+:8] = {8{busif.strobe[i]}};
        end else begin : gen_strobe_padding
            assign strobe_expanded[8*i+:8] = 8'h00;
        end
    end
endgenerate

//---------------------------------------//
// Writing to registers
//---------------------------------------//        
always_ff @(posedge clk, negedge n_rst) begin : TCR_TPSC_TARR_WRITE
    if (~n_rst) begin
        tcr <= '0;
        tpsc <= '0;
        tarr <= '1;
    end 
    else begin
        tcr <= nxt_tcr;
        tpsc <= nxt_tpsc;
        tarr <= nxt_tarr;
    end
end
always_comb begin: nxt_reg_comb
    nxt_tcr = tcr;
    nxt_tpsc = tpsc;
    nxt_tarr = tarr;
    if (reg_select[TCR_IND] && busif.wen) begin
        nxt_tcr = (busif.wdata[MAX_BIT : 0] & strobe_expanded[MAX_BIT : 0]);
    end
    if (reg_select[TPSC_IND] && busif.wen) begin
        nxt_tpsc = (busif.wdata[MAX_BIT : 0] & strobe_expanded[MAX_BIT : 0]);
    end
    if (reg_select[TARR_IND] && busif.wen) begin
        nxt_tarr = (busif.wdata[MAX_BIT : 0] & strobe_expanded[MAX_BIT : 0]);
    end
end
//---------------------------------------//
// Reading from first 4 registers
//---------------------------------------//   

generate
    for (i = 0; i < NUM_REGISTERS; i++) begin : gen_rdata
        //set unused bits to 0
        if (BITS_WIDTH < 32) assign bus_read[i][31 : BITS_WIDTH] = '0;
    end
endgenerate

generate
    assign bus_read[TCNT_IND][MAX_BIT:0] = tcnt;
    assign bus_read[TCR_IND][MAX_BIT:0] = tcr;
    assign bus_read[TPSC_IND][MAX_BIT:0] = tpsc;
    assign bus_read[TARR_IND][MAX_BIT:0] = tarr;
    for(i = 0; i < CHANNELS; i++) begin : bus_read_tcc
        assign bus_read[TCCMR_IND + i][MAX_BIT:0] = tccmr[i];
        assign bus_read[TCCR_IND + i][MAX_BIT:0] = tccr[i];
        //assign t_irq[i]= tccmr[i][10];
    end
endgenerate
/*
always_comb begin: read_reg
    bus_read[TCNT_IND][MAX_BIT:0] = tcnt;
    bus_read[TCR_IND][MAX_BIT:0] = tcr;
    bus_read[TPSC_IND][MAX_BIT:0] = tpsc;
    bus_read[TARR_IND][MAX_BIT:0] = tarr;
end
*/
time_base #(.BITS_WIDTH(BITS_WIDTH)) c0 (.clk(clk),
                               .n_rst(n_rst),
                               .tc_en(tcr[7]),
                               .nxt_tc_en(nxt_tcr[7]),
                               .tc_rst(tcr[0]),
                               .nxt_tc_rst(nxt_tcr[0]),
                               .tc_irq_en(tcr[1]),
                               .nxt_tc_irq_en(nxt_tcr[1]),
                               .tarr(tarr),
                               .tpsc(tpsc),
                               .tcnt(tcnt),
                               .nxt_tcnt(nxt_tcnt),
                               .tc_irq(timerif.tc_irq)
                               ); //add bus write functionality to counter

generate
    for(i = 0; i < CHANNELS; i++) begin : gen_cc_channels
    capture_compare #(.BITS_WIDTH(BITS_WIDTH),.NUM_REGISTERS(NUM_REGISTERS),.TCCMR_IND(TCCMR_IND + i),.TCCR_IND(TCCR_IND + i)) a0 
                                                (.clk(clk),
                                                 .n_rst(n_rst),
                                                 .t_in(timerif.t_in[i]),
                                                 .tcnt(tcnt),
                                                 .nxt_tcnt(nxt_tcnt),
                                                 .tcr(tcr),
                                                 .nxt_tcr(nxt_tcr),
                                                 .tpsc(tpsc),
                                                 .tarr(tarr),
                                                 .strobe_expanded(strobe_expanded),
                                                 .reg_select(reg_select),
                                                 /*
                                                 .TCCMR_IND(TCCMR_IND + i),
                                                 .TCCR_IND(TCCR_IND + i),
                                                 .reg_select(reg_select),
                                                 .tccmr_read(bus_read[TCCMR_IND[i]]),
                                                 .tccr_read(bus_read[TCCR_IND[i]]),
                                                 */
                                                 .tccmr(tccmr[i]),
                                                 .tccr(tccr[i]),
                                                 .t_out(timerif.t_out[i]),
                                                 .error(error[i]),
                                                 .t_oe(timerif.t_oe[i]),
                                                 .t_irq(timerif.t_irq[i]),
                                                //  .busif(busif)
                                                 .wen(busif.wen),
                                                 .wdata(busif.wdata)
                                                 );
    end
endgenerate

endmodule