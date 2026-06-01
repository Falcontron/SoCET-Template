/*
*   Copyright 2016 Purdue University
*
*   Licensed under the Apache License, Version 2.0 (the "License");
*   you may not use this file except in compliance with the License.
*   You may obtain a copy of the License at
*
*       http://www.apache.org/licenses/LICENSE-2.0
*
*   Unless required by applicable law or agreed to in writing, software
*   distributed under the License is distributed on an "AS IS" BASIS,
*   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*   See the License for the specific language governing permissions and
*   limitations under the License.
*
*
*   Filename:     local_internal_controller.sv
*
*   Created by:   Enes Shaltami
*   Email:        ashaltam@purdue.edu
*   Date Created: 06/20/2020
*   Description:  Internal Interrupt Implementation for software and timer interrupts
*/
module clint #(
    parameter NUM_HARTS = 1
) (
    input CLK,
    input nRST,
    bus_protocol_if.peripheral_vital busif,
    clint_if.clint clif
);

    // TODO: Should interrupt requests be pulses? Might make more sense to have steady signals.
    // Simplifies handling of set/clear AND would allow for back-to-back interrupts
    // (e.g.: RISC-V spec says mtime can be virtualized by writing different mtimecmp values, but if new mtimecmp
    // value is still < mtime when written in, no new interrupt will happen)
    localparam logic [31:0] MSWI_BASE_ADDR    = 32'h0,
                            MTIMER_BASE_ADDR  = MSWI_BASE_ADDR + 32'h4000,
                            MTIMER_TIME_ADDR  = MTIMER_BASE_ADDR + 32'h7FF8,
                            MTIMER_TIMEH_ADDR = MTIMER_TIME_ADDR + 32'h4;
    localparam logic [NUM_HARTS-1:0] [31:0] MSWI_MSIP_ADDR = mswi_msip_addr_init();
    localparam logic [NUM_HARTS-1:0] [31:0] MTIMER_CMP_ADDR = mtimer_cmp_addr_init();
    localparam logic [NUM_HARTS-1:0] [31:0] MTIMER_CMPH_ADDR = mtimer_cmph_addr_init();

    function logic [NUM_HARTS-1:0] [31:0] mswi_msip_addr_init();
        mswi_msip_addr_init[0] = MSWI_BASE_ADDR + 32'h0;
        for (int i = 1; i < NUM_HARTS; i = i + 1)
            mswi_msip_addr_init[i] = mswi_msip_addr_init[i - 1] + 32'h4;
    endfunction

    function logic [NUM_HARTS-1:0] [31:0] mtimer_cmp_addr_init();
        mtimer_cmp_addr_init[0] = MTIMER_BASE_ADDR + 32'h0;
        for (int i = 1; i < NUM_HARTS; i = i + 1)
            mtimer_cmp_addr_init[i] = mtimer_cmp_addr_init[i - 1] + 32'h8;
    endfunction

    function logic [NUM_HARTS-1:0] [31:0] mtimer_cmph_addr_init();
        mtimer_cmph_addr_init[0] = MTIMER_BASE_ADDR + 32'h4;
        for (int i = 1; i < NUM_HARTS; i = i + 1)
            mtimer_cmph_addr_init[i] = mtimer_cmph_addr_init[i - 1] + 32'h8;
    endfunction

    logic [31:0] mtime, mtime_next, mtimeh, mtimeh_next;
    logic [NUM_HARTS-1:0] [31:0] mtimecmp, mtimecmp_next, mtimecmph, mtimecmph_next;
    logic [NUM_HARTS-1:0] msip, msip_next, msip_last;
    logic [63:0] mtimefull, mtimefull_next;
    logic [NUM_HARTS-1:0] [63:0] mtimecmpfull, mtimecmpfull_next;
    logic [NUM_HARTS-1:0] timer_int, prev_timer_int;

    // bus signals
    assign busif.request_stall = 1'b0;

    // assignments for partial registers
    assign mtime = mtimefull[31:0];
    assign mtimeh = mtimefull[63:32];
    assign clif.mtime = mtimefull;

    genvar i;
    generate
        for (i = 0; i < NUM_HARTS; i = i + 1) begin : g_hart_assign
            // Partial register assignment
            assign mtimecmp[i] = mtimecmpfull[i][31:0];
            assign mtimecmph[i] = mtimecmpfull[i][63:32];
            // Interrupt generation
            assign timer_int[i] = (mtimefull >= mtimecmpfull[i]);
            // only get the first cycle of the interrupt since this interrupt is set high continuously
            assign clif.timer_int[i] = timer_int[i];
            //assign clif.clear_timer_int = busif.wen & (clif.mtimecmp_sel | clif.mtimecmph_sel); // clear the pending interrupt if writing to one of the mtimecmp registers
            // clear when mtimecmph > mtime
            assign clif.clear_timer_int[i] = !timer_int[i] && prev_timer_int[i];

            assign clif.soft_int[i] = msip[i];//busif.wen && busif.wdata[0] & busif.addr == MSIP_ADDR;
            assign clif.clear_soft_int[i] = ~msip[i] && msip_last[i];//busif.wen && !busif.wdata[0] && busif.addr == MSIP_ADDR;
        end
    endgenerate

    always_ff @(posedge CLK, negedge nRST) begin
        if (!nRST) begin
            mtimefull <= '0;
            mtimecmpfull <= '0;
            msip <= '0;
            msip_last <= '0;
            prev_timer_int <= '0;
        end else begin
            mtimefull <= mtimefull_next;
            mtimecmpfull <= mtimecmpfull_next;
            msip <= msip_next;
            msip_last <= msip;
            prev_timer_int <= timer_int;
        end
    end

    // TODO: byte enable?
    // MTIME
    always_comb begin
        mtimefull_next = mtimefull + 1; // increment the mtimefull register
        if (busif.wen && busif.addr == MTIMER_TIME_ADDR) begin
            mtimefull_next = {mtimefull[63:32], busif.wdata};
        end else if (busif.wen && busif.addr == MTIMER_TIMEH_ADDR) begin
            mtimefull_next = {busif.wdata, mtimefull[31:0]};
        end
    end

    // MTIMECMP
    generate
        for (i = 0; i < NUM_HARTS; i = i + 1) begin : g_bus_mtime
            always_comb begin
                mtimecmpfull_next[i] = mtimecmpfull[i];
                if (busif.wen && busif.addr == MTIMER_CMP_ADDR[i]) begin
                    mtimecmpfull_next[i] = {mtimecmpfull[i][63:32], busif.wdata};
                end else if (busif.wen && busif.addr == MTIMER_CMPH_ADDR[i]) begin
                    mtimecmpfull_next[i] = {busif.wdata, mtimecmpfull[i][31:0]};
                end
            end
        end
    endgenerate

    // MSIP
    generate
        for (i = 0; i < NUM_HARTS; i = i + 1) begin : g_msip_next
            assign msip_next[i] = (busif.addr == MSWI_MSIP_ADDR[i] && busif.wen) ? busif.wdata[0] : msip[i];
        end
    endgenerate

    // busif signals
    always_comb begin
        {busif.error, busif.rdata} = {1'b1, 32'hBAD1BAD1};
        if (busif.addr == MTIMER_TIME_ADDR) {busif.error, busif.rdata} = {1'b0, mtime};
        else if (busif.addr == MTIMER_TIMEH_ADDR) {busif.error, busif.rdata} = {1'b0, mtimeh};
        for (int i = 0; i < NUM_HARTS; i = i + 1) begin
            if (busif.addr == MSWI_MSIP_ADDR[i]) {busif.error, busif.rdata} = {1'b0, 31'h0, msip[i]};
            else if (busif.addr == MTIMER_CMP_ADDR[i]) {busif.error, busif.rdata} = {1'b0, mtimecmp[i]};
            else if (busif.addr == MTIMER_CMPH_ADDR[i]) {busif.error, busif.rdata} = {1'b0, mtimecmph[i]};
        end
    end
endmodule
