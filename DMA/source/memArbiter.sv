
 `include "memArb_if.vh"
// `include "ahb_if.vh"

// currently strobe only works for one work

module memArbiter 
(
    input logic CLK,
    input logic nRST,
    memArb_if.arb memA,
    ahb_if.manager ahb_m
);

localparam WORD_W = 32;

//request and requester
logic sel_arb; //0 - read, 1 - write
logic next_sel_arb;

//hready for controller logic
logic next_sel_r; //via r_hsel and arb state
logic sel_mux_r;
logic next_sel_w; 
logic sel_mux_w;
logic prev_w_hsel;

// debug logic
logic test_r_hready;

always_ff @ (posedge CLK, negedge nRST) begin
  if(~nRST) begin
    sel_arb <= 'b0;
    prev_w_hsel <= '0;
  end
  else begin
    if(ahb_m.HREADY) begin
      prev_w_hsel <= memA.w_hsel;
      sel_mux_r <= next_sel_r;
      sel_mux_w <= next_sel_w;
    end
    else begin
      prev_w_hsel <= prev_w_hsel;
      sel_mux_r <= sel_mux_r;
      sel_mux_w <= sel_mux_w;
    end
    if((memA.r_hsel || memA.w_hsel) & ahb_m.HREADY) begin
      sel_arb <= next_sel_arb;
    end
    else begin
      sel_arb <= sel_arb;
    end
  end
end

// logic [3:0] next_HWSTRB;

// always_ff @ (posedge CLK, negedge nRST) begin
//   if(~nRST) begin
//     ahb_m.HWSTRB = '0;
//   end
//   else begin
//     ahb_m.HWSTRB = next_HWSTRB;
//   end
// end

// new ad hoc strobe logic
assign ahb_m.HWSTRB = (|ahb_m.HWDATA) ? 4'hf : 4'h0;

assign next_sel_r = memA.r_hsel & (~memA.w_hsel || ~sel_arb);
assign memA.r_hready = sel_mux_r & ahb_m.HREADY & ~memA.w_hwrite; // Not enough to just reference HREADY, but to also look out for if the memory is currently being written
// assign test_r_hready = sel_mux_r & ahb_m.HREADY;
// assign memA.r_hready = sel_mux_r;
assign next_sel_w = memA.w_hsel & (~memA.r_hsel || sel_arb);
// assign memA.w_hready = sel_mux_w ? ahb_m.HREADY : 0;
assign memA.w_hready = sel_mux_w & ahb_m.HREADY & memA.w_hwrite; // prev:Yiyang Shui 11/20/2022

always_comb begin
    //default 
    ahb_m.HTRANS = 'b00; //idle
    ahb_m.HWRITE = 'b0;
    ahb_m.HADDR = 'b0;
    ahb_m.HWDATA = memA.w_hwdata; //assuming HWDATA would be fine regardless because previous we wrote to memory we had ahb_m.HWDATA padded w/ 0's and now that is also done when reading.
    ahb_m.HSIZE = 'h0;
    // ahb_m.HPROT = '0;
    ahb_m.HMASTLOCK = '0;
    ahb_m.HBURST = '0;
    // next_HWSTRB = '0;
    //memA.r_hready = 'b0;
    //memA.w_hready = 'b0;
    memA.hrdata = ahb_m.HRDATA; //change 1/25
    memA.error = (ahb_m.HRESP != 'b00); // 'b00 is OKAY-state
    next_sel_arb = sel_arb;

    if(memA.r_hsel & ~sel_arb) begin
        ahb_m.HTRANS = 'b10; //non-seq
        ahb_m.HWRITE = 'b0;
        ahb_m.HADDR = memA.r_haddr;
        ahb_m.HSIZE = memA.r_hsize; //ununcommented
        //if the ahb bus isn't stupid we don't need this -
        /*if (memA.r_hsize == 'b00) begin
          memA.hrdata = {24'b0, ahb_m.HRDATA[7:0]};
        end
        else if (memA.r_hsize == 'b01) begin
          memA.hrdata = {16'b0, ahb_m.HRDATA[15:0]};
        end
        else if (memA.r_hsize == 'b10) begin
          memA.hrdata = ahb_m.HRDATA;
        end*/
        memA.hrdata = ahb_m.HRDATA;
        memA.error = ahb_m.HRESP != 'b00;
        next_sel_arb = 'b1;
    end
    else if(memA.w_hsel & sel_arb & ~prev_w_hsel) begin
        ahb_m.HTRANS = 'b10; //non-seq
        ahb_m.HWRITE = 'b1;
        // next_HWSTRB = '1;
        ahb_m.HADDR = memA.w_haddr;
        ahb_m.HSIZE = memA.w_hsize; //ununcommented
        memA.error = ahb_m.HRESP != 'b00;
        next_sel_arb = 'b0;
    end
    else if(memA.r_hsel) begin
        ahb_m.HTRANS = 'b10; //non-seq
        ahb_m.HWRITE = 'b0;
        ahb_m.HADDR = memA.r_haddr;
        ahb_m.HSIZE = memA.r_hsize; //ununcommented
        //if the ahb bus isn't stupid we don't need this -
        /*if (memA.r_hsize == 'b00) begin
          memA.hrdata = {24'b0, ahb_m.HRDATA[7:0]};
        end
        else if (memA.r_hsize == 'b01) begin
          memA.hrdata = {16'b0, ahb_m.HRDATA[15:0]};
        end
        else if (memA.r_hsize == 'b10) begin
          memA.hrdata = ahb_m.HRDATA;
        end*/
        memA.hrdata = ahb_m.HRDATA;
        memA.error = ahb_m.HRESP != 'b00;
        next_sel_arb = 'b1;
    end
    else if(memA.w_hsel & ~prev_w_hsel) begin
        ahb_m.HTRANS = 'b10; //non-seq
        ahb_m.HWRITE = 'b1;
        ahb_m.HADDR = memA.w_haddr;
        ahb_m.HSIZE = memA.w_hsize; //ununcommented
        memA.error = ahb_m.HRESP != 'b00;
        next_sel_arb = 'b0;
        // next_HWSTRB = '1;
    end
end
endmodule