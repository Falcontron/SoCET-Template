module sram_sim #(
    parameter string MEMCHIP = "IS61WV25616BLL-10TL",
    parameter ADDR_WIDTH = 18, // for the memory chip
    parameter DATA_WIDTH = 16,
    parameter NREGS = 4096, // not true
    parameter ORDER = 0,
    parameter string INFILE = "../../meminit.bin",
    parameter string OUTFILE = "memsim.hex"
)(
    input logic n_OE,
    input logic n_CE,
    input logic n_WE,
    input logic n_LB,
    input logic n_UB,
    input logic [ADDR_WIDTH-1:0] addr,
    inout wire [DATA_WIDTH-1:0] DOUT
);
    int fd, temp;
    bit drive_z, latch, read, write;
    bit read_finish, write_finish;
    logic [DATA_WIDTH-1:0] wdata, DIN; // write data outside

    assign DOUT = drive_z ? 'bz : wdata;
    assign DIN = DOUT;

    bit write_req, read_req;
    logic [ADDR_WIDTH-1:0] addr_internal;
    assign addr_internal = addr >> 2;
    //logic [DATA_WIDTH-1:0] regs [NREGS-1:0];
    //logic [DATA_WIDTH-1:0] regs_next [NREGS-1:0];
    logic [31:0] regs [NREGS-1:0] = '{default: '0};
    logic [31:0] regs_next [NREGS-1:0];
    
    always_ff @(latch) begin
        regs <= regs_next;
    end

    always_comb begin
        regs_next = regs;
        if(write == 1) begin
            if (ORDER == 0) begin
                regs_next[addr_internal][0+:8]  = n_LB ? regs[addr_internal][0+:8] : DIN[0+:8]; //regs[addr_internal][0+:8] : DIN[0+:8]
                regs_next[addr_internal][8+:8]  = n_UB ? regs[addr_internal][8+:8] : DIN[8+:8];
            end
            else begin
                regs_next[addr_internal][16+:8]  = n_LB ? regs[addr_internal][16+:8] : DIN[0+:8]; //regs[addr_internal][0+:8] : DIN[0+:8]
                regs_next[addr_internal][24+:8]  = n_UB ? regs[addr_internal][24+:8] : DIN[8+:8];
            end
            
        end
    end

    always_comb begin
        if (ORDER == 0) begin
            // wdata = {regs[addr_internal][7:0], regs[addr_internal][15:8]};
            wdata = {regs[addr_internal][15:0]};
        end
        else begin
            // wdata = {regs[addr_internal][23:16], regs[addr_internal][31:24]};
            wdata = {regs[addr_internal][31:16]};
        end
    end


    function logic [31:0] endian_swap(logic [31:0] in);
        return {in[7:0], in[15:8], in[23:16], in[31:24]};
    endfunction


    always begin
        write = 0;
        read = 0;
        drive_z = 1;
        @(negedge n_CE);
        if (!n_WE) begin // write
            write_finish = 1'b0;
            #(5); //t_HZWE
            drive_z = 1;
            write_req = ~write_req;
            @(write_finish);
        end
        if (!n_OE) begin // read
            #(3);//t_LZCE
            drive_z = 0;
            #(4);//t_BA - t_LZCE
            read_req = ~read_req;
            @(read_finish);
        end
    end

    always begin // write event
        @(write_req);
        drive_z = 1;
        write = 1;
        #(6); // t_SD
        #(30); // Random timing for latching
        // #(1); // Random timing for latching (reduced for longer cl)
        latch = ~latch;
        @(posedge n_CE);
        //latch = ~latch;
        write_finish = ~write_finish;
        //write_req = ~write_req;
        //latch = ~latch;
    end

    always begin// read event
        @(read_req);
        read = 1;
        @(posedge n_CE);
        #(5); // t_HZCE
        drive_z = 1;
        read_finish = ~read_finish;
    end

    initial begin
        // TODO: Filename parameter or plusarg
        // regs = '{default: '0}; //vcs doesn't like this...
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
        if (ORDER == 0) begin
            fd = $fopen("memsim_0.hex", "wb");
        end
        else begin
            fd = $fopen("memsim_1.hex", "wb");
        end
        
        if(!fd) begin
            $display("Warning: Could not open %s!\n", OUTFILE);
        end else begin
            for(int i = 0; i < NREGS; i++) begin
                $fwrite(fd, "%h: %h\n", i, regs[i]);
            end
            $display("Wrote to Output file\n", OUTFILE);
            $fclose(fd);
        end
    end

endmodule