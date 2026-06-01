`timescale 1ns/1ps

module tb_socetlib_cdc_fifo;
    localparam DATA_WIDTH = 65; // addr + data + wen
    localparam ADDR_WIDTH = 4;
    
    localparam WPERIOD = 20; // write clock period
    localparam RPERIOD = 10; // read clock period

    // Clock signals
    logic tb_wclk = 0;
    logic tb_rclk = 0;
    always #(WPERIOD/2) tb_wclk = ~tb_wclk;
    always #(RPERIOD/2) tb_rclk = ~tb_rclk;

    // DUT interface signals
    logic [DATA_WIDTH-1:0] tb_wdata;
    logic tb_wfull, tb_winc, tb_wnrst;
    logic [DATA_WIDTH-1:0] tb_rdata;
    logic tb_rinc, tb_rempty, tb_rnrst;

    // Counters
    int write_count = 0;
    int read_count = 0;

    // Randomize class
    class rand_data_array;
        rand logic [DATA_WIDTH-1:0] data_array [2**ADDR_WIDTH];

        function void randomize_array();
            if (!(this.randomize() == 1)) begin
                $display("Failed to randomize data_array");
            end
        endfunction

        function void print_array();
            foreach (data_array[i]) begin
                $display("data_array[%0d] = %0h", i, data_array[i]);
            end
        endfunction
    endclass

    rand_data_array fifo_data;

    // DUT
    socetlib_cdc_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) DUT (
        .wdata(tb_wdata),
        .wfull(tb_wfull),
        .winc(tb_winc),
        .wclk(tb_wclk),
        .wnrst(tb_wnrst),
        .rdata(tb_rdata),
        .rinc(tb_rinc),
        .rempty(tb_rempty),
        .rclk(tb_rclk),
        .rnrst(tb_rnrst)
    );

    // Waveform dump
    initial begin
        $dumpfile("cdc_tb.fst");
        $dumpvars(0, tb_socetlib_cdc_fifo);
    end

    // Reset task
    task reset_dut();
        begin
            @(posedge tb_wclk);
            @(posedge tb_rclk);
            tb_winc = 0; tb_rinc = 0;
            tb_wnrst = 0; tb_rnrst = 0;
            tb_wdata = 0;
            repeat(5) begin
                @(negedge tb_wclk);
                @(negedge tb_rclk);
            end
            tb_wnrst = 1;
            tb_rnrst = 1;
            @(posedge tb_wclk);
            @(posedge tb_rclk);
            write_count = 0;
            read_count = 0;
            $display("DUT reset complete");
        end
    endtask

    // Write data task
    task write_data(input logic [DATA_WIDTH-1:0] data);
        begin
            @(posedge tb_wclk);
            if(tb_wfull) begin
                $error("Attempt to write when FIFO is FULL at time %0t", $time);
            end else begin
                tb_wdata = data;
                tb_winc = 1;
                write_count++;
                $display("[WRITE] Data %0h written successfully at time %0t", data, $time);
            end
            @(posedge tb_wclk);
            tb_winc = 0;
        end
    endtask

    // Read data task
    task read_data(input logic [DATA_WIDTH-1:0] expected_data);
        begin
            @(posedge tb_rclk);
            if(tb_rempty) begin
                $error("Attempt to read when FIFO is EMPTY at time %0t", $time);
            end else if (tb_rdata != expected_data) begin
                tb_rinc = 1;
                $error("Incorrect data was read, expected %0h, received %0h at time %0t", expected_data, tb_rdata, $time);
            end else begin
                tb_rinc = 1;
                read_count++;
                $display("[READ] Data %0h read successfully at time %0t", tb_rdata, $time);
            end
            @(posedge tb_rclk);
            tb_rinc = 0;
        end
    endtask

    // Assertions
    property no_full_and_empty_simultaneous;
        @(posedge tb_wclk)
        !(tb_wfull && tb_rempty);
    endproperty
    assert property (no_full_and_empty_simultaneous)
        else $error("FIFO wfull and rempty both asserted simultaneously at time %0t", $time);

    property reset_clears_flags;
        @(posedge tb_wclk)
        tb_wnrst == 0 |-> (tb_wfull == 0);
    endproperty
    assert property (reset_clears_flags)
        else $error("FIFO wfull should be 0 during reset at time %0t", $time);

    property reset_clears_rflags;
        @(posedge tb_rclk)
        tb_rnrst == 0 |-> (tb_rempty == 1);
    endproperty
    assert property (reset_clears_rflags)
        else $error("FIFO rempty should be 1 during reset at time %0t", $time);

    initial begin

        reset_dut();

        fifo_data = new();
        fifo_data.randomize_array();
        fifo_data.print_array();

        //*****************************************************
        // Test 1: Write max entries to fill FIFO
        //*****************************************************

        for (int i = 0; i < 2**ADDR_WIDTH; i++) begin
            write_data(fifo_data.data_array[i]);
        end

        //*****************************************************
        // Test 2: Check if FIFO correctly outputs full flag
        //*****************************************************

        if (!tb_wfull) begin
            $error("FIFO is not correctly raising wfull flag at %0t", $time);
        end

        //*****************************************************
        // Test 3: Read all entries
        //*****************************************************

        for (int i = 0; i < 2**ADDR_WIDTH; i++) begin
            read_data(fifo_data.data_array[i]);
        end

        //*****************************************************
        // Test 4: Check if FIFO correctly outputs empty flag
        //*****************************************************

        @(posedge tb_rclk);
        if(!tb_rempty) begin
            $error("FIFO is not correctly raising rempty flag at %0t", $time);
        end

        //*****************************************************
        // Test 5: Write and read simultaneously
        //*****************************************************

        fifo_data.randomize_array();

        // pre-load some data
        write_data(fifo_data.data_array[0]);
        write_data(fifo_data.data_array[1]);

        fork
            begin : write
                for (int i = 2; i < 2**ADDR_WIDTH; i++) begin
                    write_data(fifo_data.data_array[i]);
                end
            end
            begin : read
                for (int i = 0; i < 2**ADDR_WIDTH; i++) begin
                    wait (!tb_rempty); // rclk is faster than wclk so this is required otherwise it will read empty
                    read_data(fifo_data.data_array[i]);
                end
            end
        join
        
        $display("Test complete: Writes=%0d, Reads=%0d", write_count, read_count);
        $finish;
    end
endmodule
