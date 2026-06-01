module fifo # (parameter NUM_BITS = 32,buffer_size = 10, addr_bits = 4, WATER_DIR = 0)
    (
        input logic CLK, nRST,

        input logic WEN,REN,
        input logic [(NUM_BITS-1):0] wdata,
        input logic [4:0] watermark,
        output logic [(NUM_BITS-1):0] rdata,
        output logic [addr_bits-1:0] numdata,
        output logic empty, full, half
    );

    // Watermark interpretations.
    localparam GREATER_EQUAL = 0, LESS_EQUAL = 1;

    logic empty_nxt, full_nxt, half_nxt;
    logic [addr_bits-1:0] wr_ptr, rd_ptr, wr_ptr_nxt, rd_ptr_nxt, numdata_nxt;
    logic [(NUM_BITS-1):0] regs [buffer_size-1:0];

    assign rdata = (REN && ~empty) ? regs[rd_ptr]:'0;
    //assign rdata = regs[rd_ptr];

    always_ff @ (posedge CLK, negedge nRST)
    begin
        if (!nRST)
        begin

            empty <= 0;
            full <= 0;
            half <= 0;
            rd_ptr <= '0;
            wr_ptr <= '0;
            numdata <= '0;
            //rdata <= '0;
        end
        else
        begin
            empty <= empty_nxt;
            full <= full_nxt;
            half <= half_nxt;
            rd_ptr <= rd_ptr_nxt;
            //if(REN)
            //	rdata <= regs[rd_ptr];
            wr_ptr <= wr_ptr_nxt;
            numdata <= numdata_nxt;
        end
    end

    always_ff @ (posedge CLK, negedge nRST)
    begin
        if (!nRST)
        begin
            regs <= '{default:'0};

        end
        else
        begin

            if (WEN == 1 && full == 0)
            begin
                regs[wr_ptr] <= wdata;
            end
        end
    end

    generate
        if(WATER_DIR == LESS_EQUAL) begin
            assign half_nxt = (numdata <= watermark);
        end else begin
            assign half_nxt = (numdata >= watermark);
        end
    endgenerate

    //in out pointer control
    always_comb
    begin
        wr_ptr_nxt = wr_ptr;
        rd_ptr_nxt = rd_ptr;
        empty_nxt = empty;
        full_nxt = full;
        numdata_nxt = numdata;
        if (WEN == 1 && REN == 0)
        begin
            if (full == 0)
            begin
                if (wr_ptr < buffer_size - 1)
                    wr_ptr_nxt = wr_ptr + 1;
                else
                    wr_ptr_nxt = '0;
                numdata_nxt = numdata + 1;
                empty_nxt = 0;
                if ((wr_ptr + 1 == rd_ptr) || (wr_ptr == buffer_size - 1 && rd_ptr == '0))
                    full_nxt = 1;
                else
                    full_nxt = 0;
            end
        end

        else if(WEN == 0 && REN == 1 && numdata != 0)
        begin
            if(empty == 0)
            begin
                if (rd_ptr < buffer_size -1)
                begin
                    rd_ptr_nxt = rd_ptr + 1;
                end
                else
                    rd_ptr_nxt = '0;
                numdata_nxt = numdata - 1;
                full_nxt = 0;
                if ((rd_ptr + 1 == wr_ptr) || (rd_ptr == buffer_size - 1 && wr_ptr == '0))
                    empty_nxt = 1;
                else
                    empty_nxt = 0;
            end
        end

        else if(WEN == 1 && REN == 1)
        begin
            if (wr_ptr < buffer_size - 1)
                wr_ptr_nxt = wr_ptr + 1;
            else
                wr_ptr_nxt = '0;

            if (rd_ptr < buffer_size -1)
            begin
                rd_ptr_nxt = rd_ptr + 1;
            end
            else
                rd_ptr_nxt = '0;
        end
    end
endmodule
