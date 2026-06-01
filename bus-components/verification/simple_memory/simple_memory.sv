
/*
*
*   Model of a 'memory' with configurable latency
*
*/

module simple_memory #(
    parameter int NREGS = 32,
    parameter int WIDTH = 32,
    parameter string ENDIANNESS = "big",
    parameter string INFILE = "meminit.bin",
    parameter string OUTFILE = "memsim.hex"
)(
    input CLK,
    input int latency,
    bus_protocol_if.peripheral_vital prif,
    bus_protocol_if.peripheral_hint hintif
);

    int fd, temp;

    logic [WIDTH-1:0] regs [NREGS-1:0], regs_next [NREGS-1:0];
    int lat_cnt, lat_cnt_next;
    logic ready;
    
    logic [31:0] addr_internal;
    logic [31:0] wdata_swapped;
    logic [3:0] strobe_swapped;

    assign addr_internal = prif.addr >> 2;

    always_ff @(posedge CLK) begin
        regs <= regs_next;
        lat_cnt <= lat_cnt_next;
    end


    always_comb begin
        regs_next = regs;

        if(lat_cnt < latency && (prif.ren || prif.wen)) begin
            lat_cnt_next = lat_cnt + 1;
        end else begin
            lat_cnt_next = 0;
        end

        if(prif.wen && ready) begin
            regs_next[addr_internal][0+:8]  = strobe_swapped[0] ? wdata_swapped[0+:8] : regs_next[addr_internal][0+:8];
            regs_next[addr_internal][8+:8]  = strobe_swapped[1] ? wdata_swapped[8+:8] : regs_next[addr_internal][8+:8];
            regs_next[addr_internal][16+:8] = strobe_swapped[2] ? wdata_swapped[16+:8] : regs_next[addr_internal][16+:8];
            regs_next[addr_internal][24+:8] = strobe_swapped[3] ? wdata_swapped[24+:8] : regs_next[addr_internal][24+:8];
        end
    end

    assign ready = (lat_cnt == latency);
    generate
        if(ENDIANNESS == "big") begin
            assign prif.rdata = regs[addr_internal];
            assign wdata_swapped = prif.wdata;
            assign strobe_swapped = prif.strobe;
        end else if(ENDIANNESS == "little") begin
            assign prif.rdata = endian_swap(regs[addr_internal]);
            assign wdata_swapped = endian_swap(prif.wdata);
            assign strobe_swapped = {prif.strobe[0], prif.strobe[1], prif.strobe[2], prif.strobe[3]};
        end
    endgenerate

    assign prif.request_stall = !ready && (prif.ren || prif.wen);

    assign prif.error = 0;

    function logic [31:0] endian_swap(logic [31:0] in);
        return {in[7:0], in[15:8], in[23:16], in[31:24]};
    endfunction

    initial begin
        // TODO: Filename parameter or plusarg
        regs = '{default: '0};
        fd = $fopen(INFILE, "rb");
        if (!fd) begin
            $display("Warning: Could not open %s!\n", INFILE);
        end else begin
            temp = $fread(regs, fd);
            $display("Read %d bytes from %s\n", temp, INFILE); 
            $fclose(fd);
        end
    end

    final begin
        fd = $fopen(OUTFILE, "wb");
        if(!fd) begin
            $display("Warning: Could not open %s!\n", OUTFILE);
        end else begin
            for(int i = 0; i < NREGS; i++) begin
                $fwrite(fd, "%h: %h\n", i, regs[i]);
            end
            $display("Wrote to %s\n", OUTFILE);
            $fclose(fd);
        end
    end

endmodule
