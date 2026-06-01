// designed for little endian

module sram_controller #(
    parameter NUM_CHIP = 2,
    parameter ADDR_WIDTH = 18, // for the memory chip
    parameter DATA_WIDTH = 16,
    parameter CLK_DELAY = 2 // Need to clean up this, This is not used anymore, CLK delay set using counter
)(
    input logic CLK,
    input logic n_RST,
    bus_protocol_if.peripheral_vital prif,
    bus_protocol_if.peripheral_hint hintif,
    output logic n_OE [NUM_CHIP-1:0],
    output logic n_CE [NUM_CHIP-1:0],
    output logic n_WE [NUM_CHIP-1:0],
    output logic n_LB [NUM_CHIP-1:0],
    output logic n_UB [NUM_CHIP-1:0],
    output logic iopad_n_oe, //share one n_oe signal for all io pads for data pins
    output logic [ADDR_WIDTH-1:0] addr,     // to SRAM chip
    output logic [DATA_WIDTH-1:0] wdata,    // to SRAM chip
    input logic [DATA_WIDTH-1:0] rdata_in      // from SRAM chip
);
    parameter COUNTER_BIT_WIDTH = 3;
    typedef enum logic[3:0] {IDLE, READ_WAIT, READ_DATA_0, READ_DATA_1
                            , WRITE_DATA_0, WRITE_WAIT, WRITE_DATA_1, FINISH} MemState_t;
    MemState_t curr_state, nxt_state;
    // logic for latched controll signals
    logic nxt_nOE [NUM_CHIP-1:0];
    logic nxt_nCE [NUM_CHIP-1:0];
    logic nxt_nWE [NUM_CHIP-1:0];
    logic nxt_nLB [NUM_CHIP-1:0];
    logic nxt_nUB [NUM_CHIP-1:0];
    logic nxt_iopad_n_oe;

    logic [ADDR_WIDTH-1:0] nxt_addr;

    logic [DATA_WIDTH-1:0] nxt_wdata;                 
    logic [DATA_WIDTH-1:0] rdata_reg [NUM_CHIP-1:0];
    logic [DATA_WIDTH-1:0] nxt_rdata [NUM_CHIP-1:0];

    logic write;

    // Socet digital Lib counter
    logic counter_clear, counter_enable, counter_overflow_flag;
    logic [COUNTER_BIT_WIDTH-1:0] counter_overflow_val, counter_out;
    assign counter_overflow_val = 3'd3;     // realistic setting assuming AFTx07 runs at 33MHz (30 ns cycle time),
                                            //      and off-chip SRAM with 25 ns access time for read & write

    always_ff @( posedge CLK, negedge n_RST ) begin 
        if (~n_RST) begin
            curr_state <= IDLE;
            n_OE <= '{NUM_CHIP{1'b1}};
            n_CE <= '{NUM_CHIP{1'b1}};
            n_WE <= '{NUM_CHIP{1'b1}};
            n_LB <= '{NUM_CHIP{1'b1}};
            n_UB <= '{NUM_CHIP{1'b1}};
            rdata_reg <= '{NUM_CHIP{'0}};
            addr <= '0;
            wdata <= '0;
            iopad_n_oe <= '1;
        end
        else begin
            curr_state <= nxt_state;
            n_OE <= nxt_nOE;
            n_CE <= nxt_nCE;
            n_WE <= nxt_nWE;
            n_LB <= nxt_nLB;
            n_UB <= nxt_nUB;
            rdata_reg <= nxt_rdata;
            addr <= nxt_addr;
            wdata <= nxt_wdata;
            iopad_n_oe <= nxt_iopad_n_oe;
        end
    end

    assign write = (curr_state == WRITE_DATA_0 || curr_state == WRITE_DATA_1 || curr_state == WRITE_WAIT); // Not used anymore act as debugging signal
    assign prif.request_stall = (curr_state != FINISH) && (prif.ren || prif.wen); //(curr_state != IDLE)
    assign prif.rdata = ((curr_state == IDLE) || (curr_state == FINISH)) ? {rdata_reg[0], rdata_reg[1]} : '0; // Only output rdata during final stage
    assign prif.error = 0;

    always_comb begin : STATE_TRANS
        //Default
        nxt_state = curr_state;
        nxt_iopad_n_oe = iopad_n_oe;
        casez (curr_state)
            IDLE : begin
                if (prif.ren) begin 
                    nxt_state = READ_DATA_0;
                    nxt_iopad_n_oe = 1'b1;
                end
                else if (prif.wen) begin
                    nxt_state = WRITE_DATA_0;
                    nxt_iopad_n_oe = 1'b0;
                end
            end
            READ_DATA_0 : begin
                if (counter_overflow_flag == 1'b1) begin
                    nxt_state = READ_WAIT;
                end
            end
            READ_WAIT : begin
                nxt_state = READ_DATA_1;
            end
            READ_DATA_1 : begin
                if (counter_overflow_flag == 1'b1) begin
                    nxt_state = FINISH;
                end
            end
            WRITE_DATA_0 : begin
                if (counter_overflow_flag == 1'b1) begin
                    nxt_state = WRITE_WAIT;
                end
            end
            WRITE_WAIT : begin
                nxt_state = WRITE_DATA_1;
            end
            WRITE_DATA_1 : begin
                if (counter_overflow_flag == 1'b1) begin
                    nxt_state = FINISH;
                end
            end
            FINISH: nxt_state = IDLE;
        endcase
    end

   

    always_comb begin : OUTPUTLOGIC
        // default SRAM off
        nxt_nOE[0] = 1'b1;
        nxt_nOE[1] = 1'b1;

        nxt_nCE[0] = 1'b1;
        nxt_nCE[1] = 1'b1;

        nxt_nWE[0] = 1'b1;
        nxt_nWE[1] = 1'b1;

        nxt_nLB[0] = 1'b1;
        nxt_nLB[1] = 1'b1;

        nxt_nUB[0] = 1'b1;
        nxt_nUB[1] = 1'b1;

        nxt_addr = addr;
        nxt_wdata = '0;
        nxt_rdata = rdata_reg;
        casez (curr_state)
            IDLE : begin
                nxt_rdata[0] = '0;
                nxt_rdata[1] = '0;
                if (prif.ren) begin 
                    nxt_nCE[0] = 1'b0;
                    nxt_nOE[0] = 1'b0;
                    nxt_addr = prif.addr[ADDR_WIDTH-1:0];
                    nxt_nLB[0] = ~prif.strobe[0];
                    nxt_nUB[0] = ~prif.strobe[1];
                end
                else if (prif.wen) begin
                    nxt_nCE[0] = 1'b0;
                    nxt_nWE[0] = 1'b0;
                    nxt_addr = prif.addr[ADDR_WIDTH-1:0];
                    nxt_nLB[0] = ~prif.strobe[0];
                    nxt_nUB[0] = ~prif.strobe[1];
                end
            end
            READ_DATA_0 : begin
                nxt_rdata[0] = {rdata_in[7:0], rdata_in[15:8]};
                nxt_rdata[1] = rdata_reg[1];          
                nxt_nOE = n_OE;
                nxt_nCE = n_CE;
                nxt_nWE = n_WE;
                nxt_nLB = n_LB;
                nxt_nUB = n_UB;
                // if (counter_overflow_flag == 1'b1) begin
                //     nxt_nOE = {1'b1, 1'b1};
                //     nxt_nCE = {1'b1, 1'b1};
                // end
            end
            READ_WAIT : begin
                nxt_nOE[1] = 1'b0;
                nxt_nCE[1] = 1'b0;
                nxt_nLB[1] = ~prif.strobe[2];
                nxt_nUB[1] = ~prif.strobe[3];
            end
            READ_DATA_1 : begin
                nxt_rdata[0] = rdata_reg[0];       
                nxt_rdata[1] = {rdata_in[7:0], rdata_in[15:8]};
                nxt_nOE = n_OE;
                nxt_nCE = n_CE;
                nxt_nWE = n_WE;
                nxt_nLB = n_LB;
                nxt_nUB = n_UB;
                // if (counter_overflow_flag == 1'b1) begin
                //     nxt_nOE = {1'b1, 1'b1};
                //     nxt_nCE = {1'b1, 1'b1};
                // end
            end

            FINISH : begin
                // nxt_nCE = {1'b1, 1'b1};
                // nxt_nWE = {1'b1, 1'b1};
                // nxt_nOE = {1'b1, 1'b1};
                // nxt_nLB = {1'b1, 1'b1};
                // nxt_nUB = {1'b1, 1'b1};
                nxt_addr = '0;
                nxt_wdata = '0;
            end
            WRITE_DATA_0 : begin
                // nxt_wdata = prif.wdata[DATA_WIDTH-1:0];
                // nxt_wdata = {prif.wdata[7:0], prif.wdata[15:8]};
                nxt_wdata = {prif.wdata[23:16], prif.wdata[31:24]};
                // if (counter_out <= counter_overflow_val) begin
                nxt_nOE = n_OE;
                nxt_nCE = n_CE;
                nxt_nWE = n_WE;
                nxt_nLB = n_LB;
                nxt_nUB = n_UB;
                    // nxt_nCE = {1'b1, 1'b1};
                    // nxt_nWE = {1'b1, 1'b1};
                    // nxt_wdata = '0;
                    // nxt_nLB = {1'b1, 1'b1};
                    // nxt_nUB = {1'b1, 1'b1};
                // end
            end
            WRITE_WAIT : begin
                nxt_nCE[1] = 1'b0;
                nxt_nWE[1] = 1'b0;
                nxt_nLB[1] = ~prif.strobe[2];
                nxt_nUB[1] = ~prif.strobe[3];
            end
            WRITE_DATA_1 : begin
                // nxt_wdata = prif.wdata[31:16];
                nxt_wdata = {prif.wdata[7:0], prif.wdata[15:8]};
                nxt_nOE = n_OE;
                nxt_nCE = n_CE;
                nxt_nWE = n_WE;
                nxt_nLB = n_LB;
                nxt_nUB = n_UB;
                // if (counter_overflow_flag == 1'b1) begin
                //     nxt_nCE = {1'b1, 1'b1};
                //     nxt_nWE = {1'b1, 1'b1};
                //     // nxt_wdata = '0;
                //     nxt_nLB = {1'b1, 1'b1};
                //     nxt_nUB = {1'b1, 1'b1};
                // end
            end
        endcase
    end

    assign counter_enable = ((curr_state == IDLE) || (curr_state == FINISH)) ? '0 : '1;
    assign counter_clear = ((curr_state == IDLE) || (curr_state == FINISH) || (curr_state == WRITE_WAIT) || (curr_state == READ_WAIT)) ? '1 : '0;
    socetlib_counter #(.NBITS(COUNTER_BIT_WIDTH)) counter (.CLK(CLK), .nRST(n_RST), .clear(counter_clear), .count_enable(counter_enable)
    , .overflow_val(counter_overflow_val), .count_out(counter_out), .overflow_flag(counter_overflow_flag));

endmodule

