
module tb_apb_completer();

    localparam ADW = 32; // Address width
    localparam DAW = 32; // Data width

    logic PCLK = 0, PRESETn;

    apb_if apbif(PCLK, PRESETn);
    bus_protocol_if protif();

    always #(10) PCLK++;

    logic ready, WEN, REN;
    logic [31:0] offset, wdata, rdata;
    logic [3:0] write_strobe;
    int latency;
    int test_number = 0;
    int fails = 0;


    apb_completer #(
        .NWORDS(32),
        .BASE_ADDR(32'h0000_0000),
        .ADDR_WIDTH(ADW),
        .DATA_WIDTH(DAW)
    ) DUT (
        .apbif,
        .protif
    );

    simple_memory M(
        .CLK(PCLK),
        .nRST(PRESETn),
        .prif(protif),
        .hintif(protif),
        .latency
    );

    task reset();
        @(negedge PCLK);
        PRESETn = 1'b0;
        repeat(2) @(negedge PCLK);
        PRESETn = 1'b1;
    endtask

    /*
    *   Assumes APB input signals already set up
    *   (i.e. PWRITE, PADDR, etc.), then does the
    *   clocking/stall handling. Caller should
    *   do checks after this (cycle will be left at
    *   cycle after txn finishes).
    */
    task exec_apb_txn();
        @(posedge apbif.PCLK);
        #(1);
        apbif.PENABLE = 1'b1;
        // Wait for PREADY (stall case)
        while(!apbif.PREADY) begin
            @(posedge apbif.PCLK);
            #(1);
        end
    endtask

    task apb_read(
        input logic [31:0] addr,
        input logic [31:0] expected,
        input logic err_expected,
        input logic select
    );
        @(posedge apbif.PCLK);
        #(1);
        apbif.PADDR = addr;
        apbif.PSEL = select;
        apbif.PWRITE = 1'b0;
        apbif.PSTRB = '0;
        apbif.PPROT = '0;
        apbif.PWDATA = '0;

        exec_apb_txn();
        
        if(!err_expected) begin
            assert(apbif.PRDATA == expected)
            else $display("Time %t: Expected %h, got %h\n", $time, expected, apbif.PRDATA);

            assert(!apbif.PSLVERR)
            else $display("Time %t: Unexpected PSLVERR in transaction\n", $time);
        end else begin
            assert(apbif.PSLVERR)
            else $display("Time %t: Expected an error, didn't get it.\n", $time);
        end

        apbif.PENABLE = 1'b0;
        apbif.PSEL = 1'b0;
        @(posedge apbif.PCLK);
    endtask

    task apb_write(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic err_expected,
        input logic [3:0] strobe,
        input logic select
    );
        @(posedge apbif.PCLK);
        #(1);
        apbif.PADDR = addr;
        apbif.PSEL = select;
        apbif.PWRITE = 1'b1;
        apbif.PSTRB = strobe;
        apbif.PPROT = '0;
        apbif.PWDATA = data;

        exec_apb_txn();

        if(!err_expected) begin
            assert(!apbif.PSLVERR)
            else $display("Time %t: Unexpected PSLVERR in transaction\n", $time);
        end else begin
            assert(apbif.PSLVERR)
            else $display("Time %t: Expected an error, didn't get it.\n", $time);
        end
        
        apbif.PENABLE = 1'b0;
        apbif.PSEL = 1'b0;
        @(posedge apbif.PCLK);
    endtask


    initial begin
        apbif.PADDR = '0;
        apbif.PSEL = 1'b0;
        apbif.PWRITE = 1'b0;
        apbif.PWDATA = '0;
        apbif.PPROT = '0;
        apbif.PSTRB = '0;
        apbif.PENABLE = '0;
        PRESETn = 1'b1;
        latency = 0;

        reset();

        /*
        * Block 1: No wait states, test write-then-read
        */
        for(int i = 0; i < 24; i++) begin
            apb_write(i*4, i*4, 1'b0, '1, 1'b1);
            test_number++;
        end
        
        for(int i = 0; i < 24; i++) begin
            apb_read(i*4, i*4, 1'b0, 1'b1);
            test_number++;
        end

        /*
        * Block 2: Test errors
        */
        $display("Passed %0d / %0d tests!\n", test_number - fails, test_number);
        $finish();
    end

endmodule
