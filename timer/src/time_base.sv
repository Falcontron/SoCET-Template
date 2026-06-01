module time_base 
#(
    //parameter CHANNELS = 8;
    parameter BITS_WIDTH = 32,
    parameter MAX_BIT = BITS_WIDTH - 1
)
(
    input logic clk,
    input logic n_rst,
    input logic tc_en, nxt_tc_en,
    input logic tc_rst, nxt_tc_rst,
    input logic tc_irq_en, nxt_tc_irq_en,
    input logic [MAX_BIT:0] tarr,
    input logic [MAX_BIT:0] tpsc,
    output logic [MAX_BIT:0] tcnt, nxt_tcnt,
    output logic tc_irq
);
logic [MAX_BIT:0] psc_cnt, nxt_psc_cnt;
logic nxt_tc_irq, zero_init, nxt_zero_init;
/*
always_comb begin: prescaler_comb_1
    if(tc_rst == 1'b1) begin
        nxt_psc_cnt = {BITS_WIDTH{1'b0}};
    end
    else if(tc_en == 1'b1) begin
        if(psc_cnt >= tpsc) begin
            nxt_psc_cnt = {BITS_WIDTH{1'b0}};
        end
        else begin
            nxt_psc_cnt = psc_cnt + 1;
        end
    end
    else begin
        nxt_psc_cnt = psc_cnt;
    end
end

always_comb begin: prescaler_comb_2
    nxt_psc_cnt = psc_cnt;
    if(nxt_tc_rst == 1'b1) begin
        nxt_psc_cnt = {BITS_WIDTH{1'b0}};
    end
    else if(nxt_tc_en == 1'b1) begin
        if(psc_cnt >= tpsc) begin
            nxt_psc_cnt = {BITS_WIDTH{1'b0}};
        end
        else begin
            nxt_psc_cnt = psc_cnt + 1;
        end
    end
end

always_comb begin : upCounter_comb_1
    if(tc_rst == 1'b1) begin
        nxt_tcnt = {BITS_WIDTH{1'b0}};
    end
    else if(tc_en == 1'b1) begin
        if(psc_cnt >= tpsc) begin
            if(tcnt >= tarr) begin
                nxt_tcnt = {BITS_WIDTH{1'b0}};
            end
            else begin
                nxt_tcnt = tcnt + 1;
            end
        end
        else begin
            nxt_tcnt = tcnt;
        end
    end
    else begin
        nxt_tcnt = tcnt;
    end
end
*/
/*
// count initialize to 0
// when counter enabled, first cnt should be 0 
// 0 (disabled) -> 0 (enabled)
// when counter disabled and then re-enabled, it should increment
// if not rollover 50 (en) -> 50 (dis) -> 51 (en)
// 0 (en) -> 0 (dis) -> 1 (en)
// if rollover 50 (en) -> 50 (dis) -> 0 (en)

if sync reset on 50, then 50 (en) -> 0 (en, rst) -> 0 (en) -> 1 (en)
*/

always_comb begin : upCounter_comb_2
    nxt_tcnt = tcnt;
    nxt_psc_cnt = psc_cnt;
    nxt_zero_init = zero_init;
    nxt_tc_irq = tc_irq;
    //sync reset everything to 0
    if(nxt_tc_rst == 1'b1) begin
        nxt_tcnt = {BITS_WIDTH{1'b0}};
        nxt_psc_cnt = {BITS_WIDTH{1'b0}};
        nxt_zero_init = 1'b0;
        nxt_tc_irq = 1'b0;
    end
    //if counting enabled
    else if(nxt_tc_en == 1'b1) begin
        //hasn't been zero initialized yet
        if(zero_init == 1'b0) begin
            nxt_psc_cnt = {BITS_WIDTH{1'b0}};
            nxt_tcnt = {BITS_WIDTH{1'b0}};
            nxt_zero_init = 1'b1;
        end
        //prescaler at max
        else if(psc_cnt >= tpsc) begin
            nxt_psc_cnt = {BITS_WIDTH{1'b0}};
            //rollover
            if(tcnt >= tarr) begin
                nxt_tcnt = {BITS_WIDTH{1'b0}};
                //set interrupt on rollover
                if(nxt_tc_irq_en == 1'b1) begin
                    nxt_tc_irq = 1'b1;
                end
            end
            else begin
                nxt_tcnt = tcnt + 1;
            end
        end
        else begin
            nxt_psc_cnt = psc_cnt + 1;
        end
    end
end

always_ff @(posedge clk, negedge n_rst) begin : upCounter_seq
    if(n_rst == 1'b0) begin
        tcnt <= {BITS_WIDTH{1'b0}};
        psc_cnt <= {BITS_WIDTH{1'b0}};
        zero_init <= 1'b0;
        tc_irq <= 1'b0;
    end
    else begin
        tcnt <= nxt_tcnt;
        zero_init <= nxt_zero_init;
        tc_irq <= nxt_tc_irq;
        psc_cnt <= nxt_psc_cnt;
    end
end

endmodule