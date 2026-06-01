module read_control
(
    input logic clk, 
    input logic n_rst, 
    input logic [7:0] count,
    input logic rollover_flag,
    input logic [31:0] control_signals,
    input logic fifo_full,
    input logic hready,
    input logic [31:0] dest_addr, 
    input logic [31:0] src_addr,
    input logic drq,
    input logic [31:0] read_data, //Read data to 32
    input logic status_read,
    input logic async_reset, daq_write,
    input logic read_pause,
    output logic clear, count_enable, daq, 
    output logic [65:0] data_addr_packet, //Changed from 40 to 66 {2-bit size, address, data}
    output logic wen, clear_fifo, hwrite, hsel,
    output logic [2:0] hsize, 
    output logic [31:0] haddr, 
    output logic finished, error_flag
);

    // verilator lint_off WIDTH 
    // verilator lint_off UNSIGNED 
    // verilator lint_off CMPCONST
    // verilator lint_off CASEINCOMPLETE

    localparam MIN_ADDRESS = 32'b0;
    localparam MAX_ADDRESS = 32'hffffffff;
    //params for size
    /*
    localparam EIGHTBIT = 2'b00;
    localparam SIXTEENBIT = 2'b01;
    localparam THIRTYTWOBIT = 2'b10;
    */

    typedef enum logic [3:0] {IDLE, READ, ACK, ERROR, FIFO_WAIT, FIFO_WRITE, INCREMENT, NEXT_BYTE, CIRC_RESET, FINISHED} state_type;
    state_type state, next_state;
    logic [31:0] data, next_data; //Changed Data Size from 8 to 32 padded with 0s for anysize but 32

    // Control Signals Deconstructed
    logic inc_source;
    logic inc_dest;
    logic circ;
    logic en;
    logic direct_periph;
    //psize
    logic [1:0] psize;

    assign inc_source = control_signals[12];
    assign inc_dest = control_signals[11];
    assign circ = control_signals[10];
    assign en = control_signals[0];
    assign direct_periph = control_signals[8]; // was 13 -Yiyang Shui
    //psize defined
    assign psize = control_signals[7:6]; //00 - 8(bits), 01 - 16(bits), 10 - 32(bits)
    //Different documentation say diff bits for psize

    // Computation Temp Signals 
    logic [31:0] compute_address;
    logic [31:0] comp_address; 
    logic [31:0] compute_dest;
    logic [31:0] compute_src;

    always_ff @ (posedge clk, negedge n_rst) begin
        if(n_rst == '0) begin
            state <= IDLE;
            data <= '0;
        end
        else begin
            state <= next_state;
            data <= next_data;
        end
    end

    // Next state logic 
    always_comb begin
        next_state = state;
        compute_address = 0;
        comp_address = 0;
        case(state)
            IDLE: begin
                if(async_reset == '1) begin
                    next_state = IDLE;
                end
                else if(en && ~direct_periph) begin
                    next_state = READ;
                end
                else if(en && drq && direct_periph) begin
                    next_state = READ;
                end
            end
            ACK: begin
                if(daq_write == '1) begin
                    next_state = IDLE;
                end
            end
            ERROR: begin
                if(status_read) begin
                    next_state = IDLE;
                end
            end
            READ: begin
                compute_address = inc_source ? src_addr + (count << psize) : src_addr;  // should this also be changed? -Yiyang
                // compute_address = inc_source ? src_addr + (count << {psize, 1'b0}) : src_addr; // Yiyang Shui, 11/27/2022
                if(compute_address < MIN_ADDRESS || compute_address > MAX_ADDRESS) begin
                    next_state = ERROR;
                end
                else if(hready == '1) begin
                    next_state = FIFO_WAIT;
                end
            end
            FIFO_WAIT: begin
                if(!fifo_full) begin
                    next_state = FIFO_WRITE;
                end
            end
            FIFO_WRITE: begin
                comp_address = inc_dest ? dest_addr + (count << psize) : dest_addr; // should this also be changed? -Yiyang
                if(comp_address < MIN_ADDRESS || comp_address > MAX_ADDRESS) begin
                    next_state = ERROR;
                end
                else begin
                   next_state = INCREMENT; 
                end
            end
            INCREMENT: begin
                next_state = NEXT_BYTE;
            end
            NEXT_BYTE: begin
                if(rollover_flag == '0 && ~read_pause) begin
                    next_state = READ;
                end
                else if(rollover_flag == '1 && circ == '1) begin
                    next_state = CIRC_RESET;
                end
                else if(rollover_flag == '1 && circ == '0) begin
                    next_state = FINISHED;
                end
            end
            CIRC_RESET: begin
                next_state = READ;
            end
            FINISHED: begin
                if(direct_periph) begin
                    next_state = ACK;
                end
                else if(status_read) begin
                    next_state = IDLE;
                end
            end
        endcase
        if(async_reset) begin
            next_state = IDLE;
        end
    end

    // Output Logic 
    always_comb begin
        clear = '0;
        count_enable = '0;
        daq = '0;
        data_addr_packet = '0;
        wen = '0;
        clear_fifo = '0;
        hwrite = '0;
        hsize = '0;
        haddr = '0;
        hsel = '0;
        finished = '0;
        error_flag = '0;
        next_data = data;
        compute_src = 0;
        compute_dest = 0;

        case(state)
            IDLE: begin
                clear = '1;
            end
            ACK: begin
                daq = daq_write;
            end
            ERROR: begin
                error_flag = '1;
                clear_fifo = '1;
            end
            READ: begin
                compute_src = inc_source ? src_addr + ((count << psize) << 1) : src_addr; // 11/27/2022 Yiyang Shui
                if(compute_src < MIN_ADDRESS || compute_src > MAX_ADDRESS) begin
                    haddr = '0;
                    hsel = '0;
                end
                else begin
                    haddr = compute_src;
                    hsize = {1'b0, psize[1:0]}; 
                    hwrite = '0;
                    hsel = '1;
                    next_data = read_data;
                end
            end
            FIFO_WAIT: begin
                hsel = '0;
            end
            FIFO_WRITE: begin
                compute_dest = inc_dest ? dest_addr + ((count << psize) << 1) : dest_addr;// 11/27/2022 Yiyang Shui
                if(compute_dest < MIN_ADDRESS || compute_dest > MAX_ADDRESS) begin
                    wen = '0;
                    data_addr_packet = '0;
                end
                else begin
                    wen = '1;
                    data_addr_packet = {psize[1:0], compute_dest[31:0], data[31:0]};
                end
            end
            INCREMENT: begin
                count_enable = '1;
            end
            NEXT_BYTE: begin
                count_enable = '0;
            end
            CIRC_RESET: begin
                clear = '1;
            end
            FINISHED: begin
                clear = '1;
                finished = '1;
            end
        endcase
    end

    // verilator lint_on WIDTH 
    // verilator lint_on UNSIGNED 
    // verilator lint_on CMPCONST
    // verilator lint_on CASEINCOMPLETE

endmodule
