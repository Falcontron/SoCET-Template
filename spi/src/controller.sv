module controller
(
    input logic CLK, nRST,
    input logic mode, //1'b1 = Master, 1'b0 = Slave
    input logic EN,
    input logic op_complete, w_done,
    input logic SS_IN,
    output logic SS_OUT,
    output logic shifter_en, shifter_load,
    output logic counter_en,
    output logic shifter_rst, counter_rst,
    output logic TX_REN, RX_WEN //Transmit FIFO Read Enable and Recieve FIFO Write Enable
);

    typedef enum {
        IDLE,
        SLAVE_WAIT,
        SLAVE_TXN,
        SLAVE_BUFFER,
        MASTER_TXN,
        MASTER_BUFFER
    } state_t;

    localparam MASTER = 1'b1;
    localparam SLAVE = 1'b0;

    state_t state, state_n;

    // State update
    always_ff @(posedge CLK, negedge nRST) begin
        if (!nRST) begin
            state <= IDLE;
        end else begin
            state <= state_n;
        end
    end

    // Next State Logic
    always_comb begin : NEXT_STATE
        state_n = state;
        
        casez(state)
            IDLE: begin
                if(EN && mode == MASTER) begin
                    state_n = MASTER_TXN;
                end else if(EN && mode == SLAVE) begin
                    state_n = SLAVE_WAIT;
                end
            end
            
            SLAVE_WAIT: begin
                if(~SS_IN) begin
                    state_n = SLAVE_TXN;
                end
            end

            SLAVE_TXN: begin
                if(w_done) begin
                    state_n = SLAVE_BUFFER; // Full word shifted, dump data & get new data
                end else if(SS_IN) begin
                    state_n = SLAVE_BUFFER; // Deselected, return to IDLE TODO: Should this go to buffer first to dump the present data?
                end
            end

            SLAVE_BUFFER: begin
                if(SS_IN) begin
                    state_n = IDLE; // Deselected, return to IDLE
                end else begin
                    state_n = SLAVE_TXN; // Continue transaction with new data
                end
            end

            MASTER_TXN: begin
                if(w_done) begin
                    state_n = MASTER_BUFFER;
                end else if(op_complete) begin
                    state_n = IDLE; // TODO: Same as above, does this need to pass through buffer?
                end
            end

            MASTER_BUFFER: begin
                if(op_complete) begin
                    state_n = IDLE;
                end else begin
                    state_n = MASTER_TXN;
                end
            end
        endcase
    end : NEXT_STATE

    // Output logic
    assign SS_OUT = !(state == MASTER_TXN || state == MASTER_BUFFER); // SS_OUT low whenever Master is mid-transaction TODO: Do we want to pulse SS high between frames?
    
    always_comb begin : OUTPUT_LOGIC
        shifter_en = '0; // Only one shift register needed
        shifter_load = '0;
        counter_en = '0;
        shifter_rst = '0;
        counter_rst = '0;
        //SS_OUT = '1;
        TX_REN = '0;
        RX_WEN = '0;

        casez(state)
            IDLE: begin
                if(EN) begin // Unfortunate Mealy machine, but alternative is much worse on Slave side (due to unknown # of wait cycles), so this makes the most sense for now
                    TX_REN = 1;
                    shifter_load = 1;
                end else begin
                    shifter_rst = 1;
                    counter_rst = 1;
                end
            end

            // SLAVE_WAIT: Does nothing
            SLAVE_TXN,
            MASTER_TXN: begin
                shifter_en = 1;
                counter_en = 1;
            end

            SLAVE_BUFFER,
            MASTER_BUFFER: begin
                TX_REN = 1;
                RX_WEN = 1;
                shifter_load = 1;
                shifter_en = 0;
                counter_en = 0;
            end

        endcase

    end : OUTPUT_LOGIC

endmodule
