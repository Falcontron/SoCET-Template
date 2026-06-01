`timescale 1ns/1ps

module tb_ahb2apb;

    // -------------------------------------------------------------------------
    // Clock generation
    // -------------------------------------------------------------------------
    logic ahb_clk = 0;
    logic apb_clk = 0;

    always #10 ahb_clk = ~ahb_clk;  // 50 MHz AHB
    always #20 apb_clk = ~apb_clk;  // 25 MHz APB

    logic nRST;
    //FIFO Depth configuration (should be a power of 2, expected weirdness otherwise)
    localparam FIFO_DEPTH = 16;

    // -------------------------------------------------------------------------
    // Bus interfaces
    // -------------------------------------------------------------------------
    bus_protocol_if bus_in();
    bus_protocol_if to_mem();

    ahb_if ahbif(ahb_clk, nRST);
    apb_if apbif(apb_clk, nRST);

    // -------------------------------------------------------------------------
    // AHB Manager drives requests
    // -------------------------------------------------------------------------
    ahb_manager AHBM(
        .busif(bus_in),
        .ahbif(ahbif)
    );

    // -------------------------------------------------------------------------
    // DUT: AHB -> APB bridge
    // -------------------------------------------------------------------------
    ahb2apb #(
        .NWORDS(32),
        .FIFO_DEPTH(FIFO_DEPTH),
        .BASE_ADDR(32'h8000_0000)
    ) DUT(
        .ahbif(ahbif),
        .apbif(apbif)
    );

    // -------------------------------------------------------------------------
    // APB Completer
    // -------------------------------------------------------------------------
    apb_completer #(
        .NWORDS(6),
        .BASE_ADDR(32'h0000_0000)
    ) APBC(
        .apbif(apbif),
        .protif(to_mem)
    );

    // -------------------------------------------------------------------------
    // Simple memory
    // -------------------------------------------------------------------------
    simple_memory #(
        .NREGS(32)
    ) MEM(
        .CLK(apb_clk),  // APB side memory runs on APB clock
        .latency(0),
        .prif(to_mem),
        .hintif(to_mem)
    );

    // -------------------------------------------------------------------------
    // Reset task
    // -------------------------------------------------------------------------
    task reset();
        nRST = 1'b0;
        repeat(2) @(negedge ahb_clk);
        nRST = 1'b1;
        @(posedge ahb_clk);
    endtask

    // -------------------------------------------------------------------------
    // Bus transactions
    // -------------------------------------------------------------------------
    task send_request(
        input [31:0] addr,
        input ren,
        input wen,
        input [3:0] strobe,
        input [31:0] wdata
    );
        bus_in.addr   = addr;
        bus_in.ren    = ren;
        bus_in.wen    = wen;
        bus_in.strobe = strobe;
        bus_in.wdata  = wdata;
    endtask

    task readback; 
        input logic [31:0] addr;
        input logic [31:0] expected_read;
    begin
        if (expected_read !== ahbif.HRDATA) begin
            $display("Incorrect HRDATA for readback at %0h at time %0t", addr, $time);
        end
        else $display("Correct HRDATA for readback at %0h at time %0t", addr, $time);
    end
    endtask

    task do_write(input [31:0] addr, input [31:0] wdata, input [3:0] strobe);
        send_request(addr, 1'b0, 1'b1, strobe, wdata);
    endtask

    task do_read(input [31:0] addr);
        send_request(addr, 1'b1, 1'b0, 4'b0, '0);
    endtask

    // -------------------------------------------------------------------------
    // Simulation
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("test.vcd");
        $dumpvars;

        nRST = 1;
        bus_in.ren    = 0;
        bus_in.wen    = 0;
        bus_in.addr   = 0;
        bus_in.wdata  = 0;
        bus_in.strobe = 0;

        reset();

        // ------------------ ERROR TESTS ---------------------------
        do_write(32'h8000_0020, 32'hFFFFFFFF, 4'hF); //PSLVERR will go high with this request
        @(apbif.PSLVERR); #1; assert(apbif.PSLVERR === 1'b1) $display("PSLVERR high at %0t", $time);
        else $display("PSLVERR not raised properly");
        @(ahbif.HRESP); #1; //HRESP raises in response to PSLVERR
        assert(ahbif.HRESP === 1'b1) $display("error response received from APB at %0t", $time);
        else $display("error response not received from APB");
        //RANGE ERROR
        do_write(32'h0000_0000, 32'hBAD1BAD1, 4'h3); 
        @(ahbif.HRESP); #1;//HRESP goes high, address is out of range
        assert(ahbif.HRESP === 1'b1) $display("HRESP raised for range error at %0t", $time);
        else $display("HRESP not raised for range error");

        repeat (3) @(posedge ahb_clk); //delay so that error responses can be distinguished
        //ALIGN ERROR 
        do_write(32'h8000_0003, 32'hBAD1BAD1, 4'h3); //HRESP goes high, address is not aligned
        @(ahbif.HRESP); #1; 
        assert(ahbif.HRESP === 1'b1) $display("HRESP raised for alignment error at %0t", $time);
        else $display("HRESP not raised for alignment error");

        @(posedge ahb_clk); //delay for two cycle alignment error response
        reset();

        // Clear bus signals
        bus_in.ren    = 0;
        bus_in.wen    = 0;
        bus_in.addr   = 0;
        bus_in.wdata  = 0;
        bus_in.strobe = 0;
        // -------------------- READ AND WRITE TRANSACTIONS --------------------
        do_write(32'h8000_0004, 32'hBAD1BAD1, 4'hF);
        wait(ahbif.HWDATA === 32'hBAD1BAD1);
        @(negedge apbif.PSEL);
        do_read(32'h8000_0004); 
        @(negedge apbif.PSEL);
        #1; 
        readback(32'h8000_0004, 32'hBAD1_BAD1); 
        repeat (2) @(posedge ahb_clk); //delay to prevent duplicate reads

        do_write(32'h8000_0008, 32'hCAFECAFE, 4'h3);
        wait(ahbif.HWDATA === 32'hCAFECAFE);
        @(negedge apbif.PSEL);
        do_read(32'h8000_0008); 
        @(negedge apbif.PSEL);
        #1; 
        readback(32'h8000_0008, 32'h0000CAFE);
        repeat (2) @(posedge ahb_clk); //delay to prevent duplicate reads

        do_write(32'h8000_000C, 32'hFFFFFFFF, 4'hF); 
        wait(ahbif.HWDATA === 32'hFFFFFFFF)
        @(negedge apbif.PSEL);
        do_read(32'h8000_000C);
        @(negedge apbif.PSEL);
        #1; 
        readback(32'h8000_000C, 32'hFFFFFFFF);
        @(posedge ahb_clk); //delay to prevent duplicate reads

        do_write(32'h8000_0010, 32'hBDBD_BDBD, 4'hF);
        wait(ahbif.HWDATA === 32'hBDBDBDBD);
        @(negedge apbif.PSEL);
        do_read(32'h8000_0010); 
        @(negedge apbif.PSEL);
        #1; 
        readback(32'h8000_0010, 32'hBDBDBDBD);
        @(posedge ahb_clk); //delay to prevent duplicate reads

        do_write(32'h8000_0014, 32'hBEEFBEEF, 4'hF); 
        wait(ahbif.HWDATA === 32'hBEEFBEEF);
        @(negedge apbif.PSEL);
        do_read(32'h8000_0014); 
        @(negedge apbif.PSEL); 
        #1; 
        readback(32'h8000_0014, 32'hBEEFBEEF);

         #(1000ns); //arbitrary time to extend waveforms


        $display("[%0t] Simulation finished", $time);
        $finish;
    end

endmodule
