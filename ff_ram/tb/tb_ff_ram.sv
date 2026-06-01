/*
 *  Maxwell Michalec
 *
 *  06/01/2023
 *
 *  Testbench for FF RAM
*/

`timescale 1ns / 10ps

module tb_ff_ram();
    // Define parameters
    localparam CLK_PERIOD = 10;

    localparam NBYTES = 4096;

    localparam ADDR_WIDTH   = 32;
    localparam DATA_WIDTH   = 32;
    localparam STROBE_WIDTH =  4;

    // tb signals
    logic CLK, nRST;
    int test_num;
    string test_name;
    logic [DATA_WIDTH-1:0] test_data;
    logic [ADDR_WIDTH-1:0] test_addr;

    // Bus interface
    bus_protocol_if busif();

    // DUT
    ff_ram #(
        .NBYTES(NBYTES)
    )
    DUT (
        .CLK(CLK),
        .nRST(nRST),
        .busif(busif.peripheral_vital)
    );

    // Clock gen
    always begin
        CLK = 1'b0;
        #(CLK_PERIOD / 2);
        CLK = 1'b1;
        #(CLK_PERIOD / 2);
    end

    task reset_dut;
    begin
        nRST = 1'b0;

        @(posedge CLK);
        @(posedge CLK);

        @(negedge CLK);
        nRST = 1'b1;

        @(negedge CLK);
        @(negedge CLK);
    end
    endtask

    task write_word;
        input logic [31:0] addr;
        input logic [31:0] data;
    begin
        @(posedge CLK);
        busif.addr = addr;
        busif.wen = 1'b1;
        busif.ren = 1'b0;
        busif.wdata = data;
        @(posedge CLK);
        busif.wen = 1'b0;
    end
    endtask

    task read_word;
        input logic [31:0] addr;
        input logic [31:0] exp_data;
    begin
        @(posedge CLK);
        busif.addr = addr;
        busif.wen = 1'b0;
        busif.ren = 1'b1;
        @(negedge CLK);

        // Check that correct data was read/stored
        if (busif.rdata == exp_data) begin
            $info("Read 0x%x from address 0x%x as expected", busif.rdata, addr);
        end else begin
            $error("Read 0x%x from address 0x%x -- incorrect value", busif.rdata, addr);
        end

        @(posedge CLK);
        busif.ren = 1'b0;
    end
    endtask

//*****************************************************************************
// Main testbench process
//*****************************************************************************
initial begin
    // Initialize values
    test_name = "Initialization";
    test_num = -1;
    test_data = '0;
    busif.addr = '0;
    busif.wen = 1'b0;
    busif.ren = 1'b0;
    busif.wdata = '0;
    busif.strobe = '1;

    #(0.1);
    reset_dut();

    // Write and read data
    test_name = "write then read";
    test_num = test_num + 1;

    test_data = 32'hffffffff;
    test_addr = 32'h00000001;

    reset_dut();

    write_word(test_addr, test_data);
    read_word(test_addr, test_data);

    write_word(32'h0, 32'h23451234);
    write_word(32'h10, 32'h1000);

    read_word(32'h10, 32'h1000);
    read_word(32'h0, 32'h23451234);

    #(CLK_PERIOD * 3);

    // Write with byte-select strobe
    test_name = "write with byte-select strobe";
    test_num = test_num + 1;

    reset_dut();

    busif.strobe = 4'b0110;
    for (int i = 100; i < 500; i = i + 12) begin
        write_word(i, 32'hffffffff & i);
    end
    busif.strobe = 4'b1111;
    for (int i = 100; i < 500; i = i + 12) begin
        read_word(i, 32'h00ffff00 & i);
    end

    #(CLK_PERIOD * 3);

    // Write-read entire address space
    test_name = "write-read entire address space";
    test_num = test_num + 1;

    reset_dut();

    for (int i = 0; i < NBYTES; i = i + 4) begin
        write_word(i, 32'hffffffff ^ i);
    end
    for (int i = 0; i < NBYTES; i = i + 4) begin
        read_word(i, 32'hffffffff ^ i);
    end

    #(CLK_PERIOD * 3);


    #5ns;
    $finish;

end

endmodule
