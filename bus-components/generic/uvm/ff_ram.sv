/*
 *  Maxwell Michalec
 *  michalem@purdue.edu
 *
 *  05/31/2023
 *
 *  Parameterizable scratchpad flip-flop RAM 
 *
*/

module ff_ram #(
    parameter NBYTES = 4096,
    parameter int LATENCY = 4
) (
    input CLK, nRST,
    bus_protocol_if.peripheral_vital busif
);

    localparam int NWORDS = NBYTES / 4;

    reg   [31:0] data [NWORDS-1:0];
    logic [31:0] word_addr;
    logic [31:0] latency_count;
	logic latency_done;

    assign word_addr = busif.addr[$clog2(NWORDS)+1:0] >> 2;

    always @(posedge CLK, negedge nRST) begin
        if (~nRST) begin
            data <= '{NWORDS{'0}};
        end else begin
            if (busif.wen & (word_addr < NWORDS)) begin
                data[word_addr][0+:8]  <= busif.strobe[3] ? busif.wdata[24+:8] : data[word_addr][0+:8];
                data[word_addr][8+:8]  <= busif.strobe[2] ? busif.wdata[16+:8] : data[word_addr][8+:8];
                data[word_addr][16+:8] <= busif.strobe[1] ? busif.wdata[8+:8]  : data[word_addr][16+:8];
                data[word_addr][24+:8] <= busif.strobe[0] ? busif.wdata[0+:8]  : data[word_addr][24+:8];
            end
        end
    end

    assign busif.rdata = { data[word_addr][0+:8],
                           data[word_addr][8+:8],
                           data[word_addr][16+:8],
                           data[word_addr][24+:8] };

    always @(posedge CLK, negedge nRST) begin
        if (~nRST) begin
            latency_count <= '0;
        end else begin
            if ((latency_count < LATENCY) && (busif.ren || busif.wen)) begin
                latency_count <= latency_count + 1;
            end else begin
                latency_count <= '0;
            end
        end
	end

	assign busif.error = (busif.wen | busif.ren) & (word_addr >= NWORDS);
    assign latency_done = (latency_count == LATENCY);
    assign busif.request_stall = !latency_done && (busif.ren || busif.wen);

endmodule : ff_ram
