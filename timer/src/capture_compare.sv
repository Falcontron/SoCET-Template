`include "timer_pkg.svh"
import timer_pkg::*;
module capture_compare
#(
    parameter int BITS_WIDTH = 32,
    // 8 TCCR, 8 TCCMR, TCNT, TCR, TPSC, TARR
    parameter int NUM_REGISTERS = 20,
    parameter int TCCMR_IND = 4,
    parameter int TCCR_IND = 12,
    parameter int MAX_BIT = BITS_WIDTH - 1
)
(
    input logic clk,
    input logic n_rst,
    input logic t_in,
    input logic [MAX_BIT:0] tcnt, nxt_tcnt, tcr, nxt_tcr, tpsc, tarr, strobe_expanded,
    //input logic [MAX_BIT:0] TCCMR_IND, TCCR_IND,
    input logic [NUM_REGISTERS - 1: 0] reg_select,
    /*
    output logic [31:0] tccmr_read,
    output logic [31:0] tccr_read,
    */
    output logic [MAX_BIT:0] tccmr,
    output logic [MAX_BIT:0] tccr,
    output logic t_out,
    output logic error,
    output logic t_irq,
    output logic t_oe,
    // bus_protocol_if.peripheral_vital busif
    input logic wen,
    input logic [MAX_BIT:0] wdata
);
//---------------------------------------//
// Input Capture
//---------------------------------------//
logic pos_edge, neg_edge, nxt_t_out, cc_intr, tc_en, nxt_tc_en, tc_rst, nxt_tc_rst, nxt_t_irq;
logic [MAX_BIT:0] nxt_tccmr, nxt_tccr;
enable_t cc_en, cc_intr_en, nxt_cc_en, nxt_cc_intr_en;
polarity_t cc_polarity, nxt_cc_polarity;
direction_t cc_sel, nxt_cc_sel;

socetlib_edge_detector #(.WIDTH(1)) e0 (.CLK(clk), .nRST(n_rst), .signal(t_in), .pos_edge(pos_edge), .neg_edge(neg_edge));

always_comb begin: misc_comb_out
    cc_en = enable_t'(tccmr[0]);
    cc_polarity = polarity_t'(tccmr[2:1]);
    cc_sel = direction_t'(tccmr[4:3]);
    cc_intr_en = enable_t'(tccmr[8]);
    cc_intr = tccmr[10];
    nxt_cc_en = enable_t'(nxt_tccmr[0]);
    nxt_cc_polarity = polarity_t'(nxt_tccmr[2:1]);
    nxt_cc_sel = direction_t'(nxt_tccmr[4:3]);
    nxt_cc_intr_en = enable_t'(nxt_tccmr[8]);
    tc_en = tcr[7];
    tc_rst = tcr[0];
    nxt_tc_en = nxt_tcr[7];
    nxt_tc_rst = nxt_tcr[0];
    error = 1'b0;
    if(cc_sel == TI1_IN) begin
        //attempt write to TCCR while in input mode
        if (reg_select[TCCR_IND] && wen) begin
            error = 1'b1;
        end
    end
end
always_ff @(posedge clk, negedge n_rst) begin: TCCR_TCCMR_WRITE
    if (n_rst == 1'b0) begin
        tccr <= '0;
        tccmr <= '0;
        t_irq <= '0;
    end
    else begin
       tccr <= nxt_tccr;
       tccmr <= nxt_tccmr;
       t_irq <= nxt_t_irq;
    end
end
always_comb begin: NXT_TCCR_TCCMR_WRITE
    nxt_tccmr = tccmr;
    nxt_tccr  = tccr;
    nxt_t_irq = t_irq;
    if (reg_select[TCCMR_IND] && wen) begin
        nxt_tccmr = (wdata[MAX_BIT : 0] & strobe_expanded[MAX_BIT : 0]);
    end
    //write to tccr in output mode regardless if CC channel enabled
    if(nxt_cc_sel == OUTPUT) begin
        if (reg_select[TCCR_IND] && wen) begin
            nxt_tccr = (wdata[MAX_BIT : 0] & strobe_expanded[MAX_BIT : 0]);
        end
        //CC enabled, interrupt enabled, output mode, count initialize/increment on clk posedge, and count transition to CCR on clk posedge
        if(nxt_cc_en == ENABLED && nxt_cc_intr_en == ENABLED && ((nxt_tc_en == 1'b1 && nxt_tc_rst == 1'b0 && nxt_tcnt == 32'd0) || (tcnt >= tarr && nxt_tcnt == 32'd0) || (nxt_tcnt == tcnt + 1)) && nxt_tcnt == tccr) begin
            nxt_t_irq = 1'b1;
        end
    end
    else if(nxt_cc_en == ENABLED) begin
        if(nxt_cc_sel == TI1_IN) begin
            if(nxt_cc_polarity == RISING) begin
                if(pos_edge == 1'b1) begin
                    nxt_tccr = tcnt;
                    if(nxt_cc_intr_en == ENABLED) begin
                        nxt_t_irq = 1'b1;
                    end
                end
            end
            else if (cc_polarity == FALLING) begin
                if(neg_edge == 1'b1) begin
                    nxt_tccr = tcnt;
                    if(nxt_cc_intr_en == ENABLED) begin
                        nxt_t_irq = 1'b1;
                    end
                end
            end
            else if (cc_polarity == BOTH) begin
                if(pos_edge == 1'b1 || neg_edge == 1'b1) begin
                    nxt_tccr = tcnt;
                    if(nxt_cc_intr_en == ENABLED) begin
                        nxt_t_irq = 1'b1;
                    end
                end
            end
        end
    end
end
//---------------------------------------//
// Output Compare
//---------------------------------------//  
outmode_t cc_outmode, nxt_cc_outmode;

assign cc_outmode = outmode_t'(tccmr[7:5]);
assign nxt_cc_outmode = outmode_t'(nxt_tccmr[7:5]);
assign t_oe = cc_sel == OUTPUT ? 1 : 0;

always_ff @(posedge clk, negedge n_rst) begin: t_out_sequential
    if(n_rst == 1'b0) begin
        t_out <= 1'b0;
    end
    else begin
        t_out <= nxt_t_out;
    end
end

always_comb begin: nxt_t_out_combinational
    nxt_t_out = t_out;
    if(nxt_cc_en == ENABLED && nxt_cc_sel == OUTPUT) begin
        case(nxt_cc_outmode)
            FROZEN:   nxt_t_out = t_out;
            FORCE_LO: nxt_t_out = 1'b0;
            FORCE_HI: nxt_t_out = 1'b1;
            default: begin
                if((nxt_tc_en == 1'b1 && nxt_tc_rst == 1'b0 && nxt_tcnt == 32'd0) || (tcnt >= tarr && nxt_tcnt == 32'd0) || (nxt_tcnt == tcnt + 1)) begin //counter increments/resets on next clk posedge
                    if(nxt_tcnt > tccr) begin //next count greater than CCR
                        case(nxt_cc_outmode)
                            PWM1:     nxt_t_out = 1'b0;
                            PWM2:     nxt_t_out = 1'b1;
                            default:  nxt_t_out = t_out;
                        endcase
                    end
                    else if(nxt_tcnt == tccr) begin //next count matches CCR
                        case(nxt_cc_outmode)
                            MATCH_HI: nxt_t_out = 1'b1;
                            MATCH_LO: nxt_t_out = 1'b0;
                            TOGGLE:   nxt_t_out = ~t_out;
                            PWM1:     nxt_t_out = 1'b0;
                            PWM2:     nxt_t_out = 1'b1;
                            default:  nxt_t_out = t_out;
                        endcase
                    end
                    else if(nxt_tcnt < tccr) begin //next count less than CCR
                        case(nxt_cc_outmode)
                            PWM1:     nxt_t_out = 1'b1;
                            PWM2:     nxt_t_out = 1'b0;
                            default:  nxt_t_out = t_out;
                        endcase
                    end
                    else begin
                        nxt_t_out = t_out;
                    end
                end
                else begin
                    nxt_t_out = t_out;
                end
            end
        endcase
    end
end

endmodule
