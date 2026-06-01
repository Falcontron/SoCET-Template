
// `include "ahb_if.vh"

module registers
(
    input logic CLK,
    input logic nRST,
    input logic error,
    input logic finished,
    ahb_if.subordinate ahb_s,
    output logic [31:0] status_reg,
    output logic [31:0] control_reg,
    output logic [31:0] transfer_reg,
    output logic [31:0] source_reg,
    output logic [31:0] dest_reg,
    output logic status_read_flag
);

localparam WORD_W = 32;

// localparam SAR = 'h80050004; //Source Address Register
// localparam DAR = 'h80050008; //Destination Address Register
// localparam TSR = 'h8005000C; //Transfer Size Register
// localparam CR = 'h80050010; //Control Register
// localparam SR = 'h80050014; //Status Register

localparam SAR = 'h90001004; //Source Address Register
localparam DAR = 'h90001008; //Destination Address Register
localparam TSR = 'h9000100C; //Transfer Size Register
localparam CR = 'h90001010; //Control Register
localparam SR = 'h90001014; //Status Register

//htrans
localparam IDLE = 'b00;
localparam NON_SEQ = 'b10;
localparam SEQ = 'b11;

//hwrite needs to be high
logic write_req, prev_write_req;
logic [WORD_W-1:0] wreq_addr; //write request address

//logic [WORD_W-1:0] status_r;
logic [WORD_W-1:0] control_r;
logic [WORD_W-1:0] transfer_r;
logic [WORD_W-1:0] source_r;
logic [WORD_W-1:0] dest_r;
logic [WORD_W-1:0] status_r;

logic [WORD_W-1:0] next_control_r;
logic [WORD_W-1:0] next_transfer_r;
logic [WORD_W-1:0] next_source_r;
logic [WORD_W-1:0] next_dest_r;
logic [WORD_W-1:0] next_status_r;

//logic for read
logic [WORD_W-1:0] read_data;
logic [WORD_W-1:0] next_read_data;

// AHB pipelined write fix
logic [WORD_W-1:0] wreq_addr_ff;
logic write_req_ff;
logic read_req_ff;

logic resp;
logic next_resp;
logic ready;
logic next_ready;
logic read_req;

always_ff @ (posedge CLK, negedge nRST) begin
    if (nRST == 1'b0) begin
        control_r <= 'h0;
        transfer_r <= 'h0;
        source_r <= 'h0;
        dest_r <= 'h0;
        status_r <= 'h0;
        // read_data <= 'h0;
        prev_write_req <= '0;

        wreq_addr_ff <= '0;
        write_req_ff <= '0;
        read_req_ff <= '0;
    end
    else begin
        control_r <= next_control_r;
        transfer_r <= next_transfer_r;
        source_r <= next_source_r;
        dest_r <= next_dest_r;
        status_r <= next_status_r;
        // if(read_req) begin
        // read_data <= next_read_data;
        // end
        resp <= next_resp;
        ready <= next_ready;
        prev_write_req <= write_req;

        wreq_addr_ff <= wreq_addr;
        write_req_ff <= write_req;
        read_req_ff <= read_req;
    end
end

assign wreq_addr = ahb_s.HADDR;
assign write_req = ahb_s.HSEL & ahb_s.HWRITE & (ahb_s.HTRANS == NON_SEQ);
assign read_req = ahb_s.HSEL & ~ahb_s.HWRITE & (ahb_s.HTRANS == NON_SEQ);
//Just going to assume HSIZE will be 1 word for now -- will change. 
always_comb begin 
    next_control_r = control_r;
    next_transfer_r = transfer_r;
    next_source_r = source_r;
    next_dest_r = dest_r;
    next_status_r = status_r;
    next_resp = 'b01; //if no write == invalid addr (TODO fix)
    next_ready = 'b1;  //FIX REQUIRED (hard code fix)
    status_read_flag = '0;

    ahb_s.HRDATA = 'b0;
    ahb_s.HRESP = 'b1; 
    ahb_s.HREADYOUT = 'b1;

    case(wreq_addr_ff)
    SAR: 
    begin
        if(write_req_ff) begin
            next_source_r = ahb_s.HWDATA;
            ahb_s.HRESP = 'b0; 
            ahb_s.HREADYOUT = 'b1;
        end
    end
    DAR: 
    begin
        if(write_req_ff) begin
            next_dest_r = ahb_s.HWDATA;
            ahb_s.HRESP = 'b0; 
            ahb_s.HREADYOUT = 'b1;
        end
    end
    TSR: 
    begin
        if(write_req_ff) begin
            next_transfer_r = ahb_s.HWDATA;
            ahb_s.HRESP = 'b0; 
            ahb_s.HREADYOUT = 'b1;
        end
    end
    CR: 
    begin
        if(write_req_ff) begin
            next_control_r = ahb_s.HWDATA;
            ahb_s.HRESP = 'b0; 
            ahb_s.HREADYOUT = 'b1;
        end
    end
    endcase

    //using wreq_addr bc same as HADDR
    case(wreq_addr_ff)
    SAR: 
    begin
        if(read_req_ff) begin
            ahb_s.HRDATA = source_r;
            ahb_s.HRESP = 'b0; 
            ahb_s.HREADYOUT = 'b1;
        end
    end
    DAR: 
    begin
        if(read_req_ff) begin
            ahb_s.HRDATA = dest_r;
            ahb_s.HRESP = 'b0; 
            ahb_s.HREADYOUT = 'b1;
        end
    end
    TSR: 
    begin
        if(read_req_ff) begin
            ahb_s.HRDATA = transfer_r;
            ahb_s.HRESP = 'b0; 
            ahb_s.HREADYOUT = 'b1;
        end
    end
    CR: 
    begin
        if(read_req_ff) begin
            ahb_s.HRDATA = control_r;
            ahb_s.HRESP = 'b0; 
            ahb_s.HREADYOUT = 'b1;
        end
    end
    SR:
    begin
        if(read_req_ff) begin
            ahb_s.HRDATA = status_r;
            ahb_s.HRESP = 'b0; 
            ahb_s.HREADYOUT = 'b1;
            next_control_r = {next_control_r[31:1], 1'b0};
            next_status_r = '0;
            status_read_flag = '1;
        end
    end
    endcase

    if((finished == '1 && status_read_flag == '0) || error == '1) begin
        next_status_r = {30'd0, error, finished};
    end
end

assign control_reg = control_r;
assign dest_reg = dest_r;
assign transfer_reg = transfer_r;
assign source_reg = source_r;
assign status_reg = status_r;
// assign ahb_s.HRDATA = read_data; //can add "read_req? read_data: 'h0;" if needed 
// assign ahb_s.HREADY = ready; //Was HREADYOUT previously idk why
// assign ahb_s.HREADYOUT = ready;
// assign ahb_s.HRESP = resp;

endmodule