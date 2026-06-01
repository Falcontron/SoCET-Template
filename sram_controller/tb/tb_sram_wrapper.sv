`timescale 1ns / 100ps
module tb_sram_wrapper();
    parameter ADDR_WIDTH = 18; // for the memory chip
    parameter DATA_WIDTH = 16;
    parameter PERIOD = 10;
    string TEST_CASE = "None";

    logic CLK = 0, nRST;
    logic tb_mismatch;
    always #(16) CLK++;
    bus_protocol_if memory_protif();

    SRAM_wrapper #(
        .NUM_CHIP(2),
        .ADDR_WIDTH(ADDR_WIDTH), // for the memory chip
        .DATA_WIDTH(DATA_WIDTH)
    ) top_SRAM (
        .CLK(CLK),
        .n_RST(nRST),
        .prif(memory_protif),
        .hintif(memory_protif)
    );

    task reset_dut();
    begin //Reset design
        memory_protif.wen = '0;
        memory_protif.ren = '0;
        memory_protif.addr = '0;
        memory_protif.wdata = '0;
        memory_protif.strobe = '0;
        nRST = 1'b0;
        #(PERIOD * 2);
        nRST = 1'b1;
    end
    endtask

    task mem_write(
        input logic [31:0] addr, wdata
    );
        @(posedge CLK);
        #(1); // Delay
        // Addr Phase
        memory_protif.wen = '1;
        memory_protif.addr = addr;
        memory_protif.wdata = wdata;
        memory_protif.strobe = '1;

        @(negedge memory_protif.request_stall);
        memory_protif.wen = '0;
        memory_protif.addr = '0;
        memory_protif.wdata = '0;
        memory_protif.strobe = '0;
    endtask

    task mem_read(
        input logic [31:0] addr, rdata  // rdata is the target output
    );
        @(posedge CLK);
        #(1); // Delay
        // Addr Phase
        memory_protif.ren = '1;
        memory_protif.addr = addr;
        memory_protif.strobe = '1;

        @(negedge memory_protif.request_stall);

        if(memory_protif.rdata == rdata) begin // Check passed
            $display("Correct rdata during %s", TEST_CASE);
            tb_mismatch = 1'b0;
        end else begin // Check failed
            $display("Incorrect rdata during %s!!!", TEST_CASE);
            tb_mismatch = 1'b1;
        end

        memory_protif.ren = '0;
        memory_protif.addr = '0;
        memory_protif.strobe = '0;
    endtask

    initial begin
        tb_mismatch = 1'b0;
        $display("Test bench for memory Controller");
        TEST_CASE = "Reset DUT";
        reset_dut();
        //tb_data = 'bz; // Need to pull high in testbench?

        #(PERIOD);
        $display("Test bench for Simple Write to memory");
        TEST_CASE = "Write to memory";
        mem_write(32'hF, 32'h12345678);

        #(PERIOD * 2);
        $display("Test bench for Simple Read from memory");
        TEST_CASE = "Read from memory";
        mem_read(32'hF, 32'h12345678);

        #(PERIOD * 2);
        TEST_CASE = "Write after read from memory";
        mem_write(32'hA, 32'hABCDEF01);
    
        #(PERIOD * 2);
        $display("Checking read for write after read from memory");
        TEST_CASE = "Read from memory 2";
        mem_read(32'hA, 32'hABCDEF01);

        #(PERIOD * 2);
        $finish();
    end

endmodule