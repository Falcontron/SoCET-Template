`timescale 1ns/1ps

module socetlib_cdc_fifo
#(
	parameter int DATA_WIDTH = 4,
	parameter int FIFO_DEPTH = 16 // number of entries in FIFO
)
(
	input  logic [DATA_WIDTH-1:0] wdata,
	input  logic winc, wclk, wnrst,
	output logic wfull,

	output logic [DATA_WIDTH-1:0] rdata,
	input  logic rinc, rclk, rnrst,
	output logic rempty
);

	generate
	// ***********************************
	// 1-Deep CDC FIFO
	// ***********************************
	if (FIFO_DEPTH == 1) begin

		logic [DATA_WIDTH-1:0] mem;
		
		logic write_toggle, write_toggle_sync1, write_toggle_sync2;
		logic read_toggle, read_toggle_sync1, read_toggle_sync2;
		
		// Write side
		always_ff @(posedge wclk or negedge wnrst) begin
			if (!wnrst) begin
				write_toggle <= 1'b0;
				mem <= '0;
			end else if (winc && !wfull) begin
				mem <= wdata;
				write_toggle <= ~write_toggle;
			end
		end
		
		// Synchronize read_toggle to write clock domain
		always_ff @(posedge wclk or negedge wnrst) begin
			if (!wnrst) begin
				read_toggle_sync1 <= 1'b0;
				read_toggle_sync2 <= 1'b0;
			end else begin
				read_toggle_sync1 <= read_toggle;
				read_toggle_sync2 <= read_toggle_sync1;
			end
		end
		
		// Full when write has toggled but read hasn't caught up
		assign wfull = (write_toggle != read_toggle_sync2);
		
		// Read side
		always_ff @(posedge rclk or negedge rnrst) begin
			if (!rnrst) begin
				read_toggle <= 1'b0;
			end else if (rinc && !rempty) begin
				read_toggle <= ~read_toggle;
			end
		end
		
		// Synchronize write_toggle to read clock domain
		always_ff @(posedge rclk or negedge rnrst) begin
			if (!rnrst) begin
				write_toggle_sync1 <= 1'b0;
				write_toggle_sync2 <= 1'b0;
			end else begin
				write_toggle_sync1 <= write_toggle;
				write_toggle_sync2 <= write_toggle_sync1;
			end
		end
		
		// Empty when read has caught up to write
		assign rempty = (write_toggle_sync2 == read_toggle);
		
		// Output data
		assign rdata = mem;

	// ***********************************
	// Large CDC FIFO
	// ***********************************
	end else begin

		localparam int ADDR_WIDTH = $clog2(FIFO_DEPTH);

		logic [ADDR_WIDTH:0] wptr_bin, wptr_gray, wptr_bin_next, wptr_gray_next;
		logic [ADDR_WIDTH:0] rptr_bin, rptr_gray, rptr_bin_next, rptr_gray_next;

		logic [ADDR_WIDTH:0] rptr_gray_sync1, rptr_gray_sync2;
		logic [ADDR_WIDTH:0] wptr_gray_sync1, wptr_gray_sync2; 

		logic wfull_next, rempty_next;

		logic wclken;

		// Write side
		assign wptr_bin_next = wptr_bin + (winc && !wfull);

		flex_bin2gray #(.BIN2GRAY(1), .WIDTH(ADDR_WIDTH+1)) w_bin2gray (.cinput(wptr_bin_next), .coutput(wptr_gray_next));
		
		always_ff @(posedge wclk, negedge wnrst) begin
			if (!wnrst) begin
				wptr_bin <= '0;
				wptr_gray <= '0;
				wfull <= '0;
			end else begin
				wptr_bin <= wptr_bin_next;
				wptr_gray <= wptr_gray_next;
				wfull <= wfull_next;
			end
		end

		// Read side
		assign rptr_bin_next = rptr_bin + (rinc && !rempty);

		flex_bin2gray #(.BIN2GRAY(1), .WIDTH(ADDR_WIDTH+1)) r_bin2gray (.cinput(rptr_bin_next), .coutput(rptr_gray_next));

		always_ff @(posedge rclk, negedge rnrst) begin
			if (!rnrst) begin
				rptr_bin <= '0;
				rptr_gray <= '0;
				rempty <= 1'b1;
			end else begin
				rptr_bin <= rptr_bin_next;
				rptr_gray <= rptr_gray_next;
				rempty <= rempty_next;
			end
		end

		// Cross-domain pointer synchronization
		always_ff @(posedge wclk, negedge wnrst) begin
			if (!wnrst) begin
				rptr_gray_sync1 <= '0;
				rptr_gray_sync2 <= '0;
			end else begin
				rptr_gray_sync1 <= rptr_gray;
				rptr_gray_sync2 <= rptr_gray_sync1;
			end
		end

		always_ff @(posedge rclk, negedge rnrst) begin
			if (!rnrst) begin
				wptr_gray_sync1 <= '0;
				wptr_gray_sync2 <= '0;
			end else begin
				wptr_gray_sync1 <= wptr_gray;
				wptr_gray_sync2 <= wptr_gray_sync1;
			end
		end
		
		// Empty & Full detection
		assign rempty_next = (rptr_gray_next == wptr_gray_sync2);
		assign wfull_next  = (wptr_gray_next == {~rptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1], rptr_gray_sync2[ADDR_WIDTH-2:0]});

		// FIFO memory connection
		assign wclken = !wfull & winc;
		
		flex_fifo_mem #(
			.DATA_WIDTH(DATA_WIDTH), 
			.FIFO_DEPTH(FIFO_DEPTH)
		) FIFO (
			.clk(wclk),
			.waddr(wptr_bin[ADDR_WIDTH-1:0]),
			.wen(wclken),
			.raddr(rptr_bin[ADDR_WIDTH-1:0]),
			.wdata(wdata),
			.rdata(rdata)
		);
	
	end
	endgenerate

endmodule
