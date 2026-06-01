module write_control
(
    input logic clk, n_rst, 
    input logic async_reset,
    input logic fifo_empty,
    input logic hready,
    input logic [31:0] control_signals,
    input logic [65:0] data_addr_packet,
    output logic clear_fifo, ren, hwrite, hsel,
    output logic [2:0] hsize, 
    output logic [31:0] haddr, 
    output logic [31:0] hwdata, //was [8:0]
    output logic error_flag, finished,
    output logic read_pause
);

    // verilator lint_off CASEINCOMPLETE

    localparam MIN_ADDRESS = 32'b0;
    localparam MAX_ADDRESS = 32'hffffffff;

    typedef enum logic [2:0] {IDLE, FIFO_READ, WRITE, ERROR} state_type;
    state_type state, next_state;
    logic [31:0] data, next_data;
    logic [31:0] addr, next_addr;
    logic [1:0] next_psize, psize; //Using psize because its 1 bit smaller than true hsize

    always_ff @ (posedge clk, negedge n_rst) begin
        if(n_rst == '0) begin
            state <= IDLE;
            data <= '0;
            addr <= '0;
            psize <= '0;
        end
        else begin
            state <= next_state;
            data <= next_data;
            addr <= next_addr;
            psize <= next_psize;
        end
    end

    // next state logic
    always_comb begin
        next_state = state;
        case(state)
            IDLE: begin
                if(fifo_empty == '0 && async_reset == '0) begin
                    next_state = FIFO_READ;
                end
            end
            FIFO_READ: begin
                next_state = WRITE;
            end
            WRITE: begin
                if(hready == '1) begin
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
        clear_fifo = '0;
        ren = '0;
        hwrite = '0;
        hsel = '0;
        hsize = '0;
        haddr = '0;
        hwdata = '0;
        error_flag = '0;
        finished = '0;
        next_addr = addr;
        next_data = data;
        next_psize = psize;
        read_pause = 1'b0;

        case(state)
            IDLE: begin
                error_flag = '0;
                if(fifo_empty == '1) begin
                    finished = '1;
                end
                read_pause = 1'b0;
            end
            // Assuming a combinational read latency
            FIFO_READ: begin
                ren = '1;
                next_addr = data_addr_packet[63:32];
                next_data = data_addr_packet[31:0];
                next_psize = data_addr_packet[65:64];
                read_pause = 1'b1;
            end
            WRITE: begin
                hwrite = '1;
                hsize = {1'b0, psize[1:0]};
                haddr = addr;
                hwdata = data;
                hsel = '1;
                read_pause = 1'b1;
            end
            ERROR: begin
                clear_fifo = '1;
                error_flag = '1;
                read_pause = 1'b1;
            end
        endcase
    end

    // verilator lint_on CASEINCOMPLETE


endmodule