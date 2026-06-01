`timescale 1ns / 100ps
module tb_sram_controller();
    parameter ADDR_WIDTH = 18; // for the memory chip
    parameter DATA_WIDTH = 16;
    parameter PERIOD = 10;
    string TEST_CASE = "None";

    logic CLK = 0, nRST;
    always #(15) CLK++;
    bus_protocol_if memory_protif();
    logic tb_n_OE [1:0];
    logic tb_n_CE [1:0];
    logic tb_n_WE [1:0];
    logic tb_n_LB [1:0];
    logic tb_n_UB [1:0];
    logic [DATA_WIDTH-1:0] tb_data;
    logic [DATA_WIDTH-1:0] tb_rdata;
    logic [DATA_WIDTH-1:0] tb_wdata;
    logic [ADDR_WIDTH-1:0] tb_addr;
    logic tb_n_oe;

    wire [DATA_WIDTH-1:0] wire_data;
    assign wire_data = tb_data;

    sram_controller #(
        .MEMCHIP("IS61WV25616BLL-10TL"),
        .NUM_CHIP(2),
        .ADDR_WIDTH(ADDR_WIDTH), // for the memory chip
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_DELAY(2)
    ) controller_DUT (
        .CLK(CLK),
        .n_RST(nRST),
        .prif(memory_protif),
        .hintif(memory_protif),
        .n_OE(tb_n_OE),
        .n_CE(tb_n_CE),
        .n_WE(tb_n_WE),
        .n_LB(tb_n_LB),
        .n_UB(tb_n_UB),
        .iopad_n_oe(tb_n_oe),
        .addr(tb_addr),
        .wdata(tb_wdata),
        .rdata(tb_rdata)
    );

    io_pad io_pad_DUT (
        .oe_n(tb_n_oe),
        .wdata(tb_wdata),
        .rdata(tb_rdata),
        .data(wire_data)
    );

    sram_sim #(
        .MEMCHIP("IS61C25616AL"),
        .ADDR_WIDTH(ADDR_WIDTH), // for the memory chip
        .DATA_WIDTH(DATA_WIDTH),
        .NREGS(262144)
    ) SRAM_chip_1 (
        .n_OE(tb_n_OE[0]),
        .n_CE(tb_n_CE[0]),
        .n_WE(tb_n_WE[0]),
        .n_LB(tb_n_LB[0]),
        .n_UB(tb_n_UB[0]),
        .addr(tb_addr),
        .DOUT(wire_data)
    );

    sram_sim #(
        .MEMCHIP("IS61C25616AL"),
        .ADDR_WIDTH(ADDR_WIDTH), // for the memory chip
        .DATA_WIDTH(DATA_WIDTH),
        .NREGS(262144)
    ) SRAM_chip_2 (
        .n_OE(tb_n_OE[1]),
        .n_CE(tb_n_CE[1]),
        .n_WE(tb_n_WE[1]),
        .n_LB(tb_n_LB[1]),
        .n_UB(tb_n_UB[1]),
        .addr(tb_addr),
        .DOUT(wire_data)
    );

    task reset_dut();
    begin //Reset design
        nRST = 1'b1;
        #(PERIOD);
        memory_protif.wen = '0;
        memory_protif.ren = '0;
        memory_protif.addr = '0;
        memory_protif.wdata = '0;
        memory_protif.strobe = '0;
        nRST = 1'b0;
        #(PERIOD);
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
        input logic [31:0] addr, rdata
    );
        @(posedge CLK);
        #(1); // Delay
        // Addr Phase
        memory_protif.ren = '1;
        memory_protif.addr = addr;
        memory_protif.strobe = '1;

        @(negedge memory_protif.request_stall);
        memory_protif.ren = '0;
        memory_protif.addr = '0;
        memory_protif.strobe = '0;
    endtask

    initial begin
        $display("Test bench for memory Controller");
        TEST_CASE = "Reset DUT";
        reset_dut();
        tb_data = 'bz; // Need to pull high in testbench?

        #(PERIOD);
        $display("Test bench for Simple Write to Memory");
        TEST_CASE = "Write to memory";
        mem_write(32'hF, 32'hBADBAD);

        #(PERIOD * 2);
        $display("Test bench for Simple Read from Memory");
        TEST_CASE = "Read from memory";
        mem_read(32'hF, 32'hCAFEDAAA);

        #(PERIOD * 2);
        TEST_CASE = "Write after read from memory";
        mem_write(32'hA, 32'hABCDEFAB);
    
        #(PERIOD * 2);
        $finish();
    end
endmodule