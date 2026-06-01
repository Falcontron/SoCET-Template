module tb_spi();


    import spi_type_pkg::*;

    spi_if spiif();
    apb_if apbif();

    logic CLK = 0, nRST;
    string test_block = "Initializing...";
    int test_num = -1;
    spi_cr_t cr;
    logic [31:0] dummy_var;
    logic tb_sck, tb_enable, tb_polarity;
    spi_status_t streg; //status registers

    always #(10) CLK++;

    localparam CR_ADDR = 32'h0, BL_ADDR = 32'h4, BR_ADDR = 32'h8, TX_ADDR = 32'hC, RX_ADDR = 32'h10, SR_ADDR = 32'h14;
    localparam READ = 0, WRITE = 1;
    localparam NO_CHECK = 0, CHECK = 1;
    localparam SLAVE = 0, MASTER = 1;

    `ifdef MAPPED
        spi DUT(
            .CLK,
            .nRST,
            .apbif_PADDR(apbif.PADDR),
            .apbif_PSEL(apbif.PSEL),
            .apbif_PENABLE(apbif.PENABLE),
            .apbif_PWRITE(apbif.PWRITE),
            .apbif_PWDATA(apbif.PWDATA),
            .apbif_PRDATA(apbif.PRDATA),
            .spiif_MISO_IN(spiif.MISO_IN),
            .spiif_MOSI_IN(spiif.MOSI_IN),
            .spiif_SCK_IN(spiif.SCK_IN),
            .spiif_SS_IN(spiif.SS_IN),
            .spiif_MISO_OUT(spiif.MISO_OUT),
            .spiif_MOSI_OUT(spiif.MOSI_OUT),
            .spiif_SCK_OUT(spiif.SCK_OUT),
            .spiif_SS_OUT(spiif.SS_OUT),
            .spiif_mode(spiif.mode),
            .spiif_interrupts(spiif.interrupts)
        );
    `else
        spi DUT(
            .*
        );
    `endif

    // Signal generation for TB SCK for testing slave mode
    sg SG(
        .CLK,
        .nRST,
        .enable(tb_enable),
        .polarity(tb_polarity),
        .tb_sck
    );

    assign spiif.SCK_IN = tb_sck;

    task reset();
        begin
            nRST = '0;
            repeat(2) @(negedge CLK);
            nRST = '1;
        end
    endtask

    task apb_txn(
        input logic [31:0] addr, wdata, expected,
        input logic write, check,
        output logic [31:0] return_value
    );
        @(posedge CLK);
        #(1); // Delay
        // Addr Phase
        apbif.PADDR = addr;
        apbif.PSEL = 1;
        apbif.PWRITE = write;
        apbif.PWDATA = wdata;
        apbif.PENABLE = 0;
        @(posedge CLK);
        #(1);
        // Data Phase
        apbif.PENABLE = 1;
        return_value = apbif.PRDATA;
        // Check PRDATA if needed
        if(!write && check) begin
            assert(apbif.PRDATA == expected)
            else $display("In block %s, test %d:\n\tIncorrect Transaction, expected %h, received %h", test_block, test_num, expected, apbif.PRDATA);
        end
        @(posedge CLK);
        #(1);
        apbif.PENABLE = 0;
        apbif.PSEL = 0;

    endtask

    task exchange_bit(
        input logic mode,
        input logic master_bit,
        input logic slave_bit,
        input logic neg_edge
    );
        // Mode refers to DUTs mode
        if(mode == MASTER) begin
            if(neg_edge) begin
                @(posedge spiif.SCK_OUT);
                spiif.MISO_IN = slave_bit;
                @(negedge spiif.SCK_OUT);
                #(1);
                assert(spiif.MOSI_OUT == master_bit);
            end else begin
                @(negedge spiif.SCK_OUT);
                spiif.MISO_IN = slave_bit;
                @(posedge spiif.SCK_OUT);
                #(1);
                assert(spiif.MOSI_OUT == master_bit);
            end
        end else if (mode == SLAVE) begin
            if(neg_edge) begin
                @(posedge spiif.SCK_IN);
                spiif.MOSI_IN = master_bit;
                @(negedge spiif.SCK_IN);
                #(1);
                assert(spiif.MISO_OUT == slave_bit);
            end else begin
                @(negedge spiif.SCK_IN);
                spiif.MOSI_IN = master_bit;
                @(posedge spiif.SCK_IN);
                #(1);
                assert(spiif.MISO_OUT == slave_bit);
            end
        end
    endtask

    /*
    task spi_master_long_txn(
        input logic [1023:0] master_data, // Data for master
        input logic [1023:0] slave_data, // Data for slave
        input int byte_num //number of bytes of the data
        //for loop or extend bits or master/slave data
    );
        begin
            
            logic [31:0] rdata;
            spi_cr_t cr_prev;
            logic done;
            int left = byte_num - 32;

            // Setup module for master transaction
            // Write in initial data
            for(int i = 0; i < byte_num && i < 32; i++) begin
                apb_txn(TX_ADDR, {24'b0, master_data[8*i +: 8]}, '0, WRITE, NO_CHECK, rdata);
            end


            // Set byte length register
            apb_txn(BL_ADDR, byte_num, '0, WRITE, NO_CHECK, rdata);
            // Read back
            apb_txn(BL_ADDR, '0, byte_num, READ, CHECK, rdata);

            apb_txn(CR_ADDR, '0, '0, READ, NO_CHECK, rdata);
            cr_prev = spi_cr_t'(rdata);
            cr_prev.mode = MASTER; //1 master mode, 0 slave mode
            cr_prev.start_transaction = 1'b1;
            apb_txn(CR_ADDR, cr_prev, '0, WRITE, NO_CHECK, rdata);
                
            @(negedge spiif.SS_OUT); // Wait for SS to go low
            // Transaction started, start swapping bits
            if(~cr_prev.clock_phase) begin
                spiif.MISO_IN = slave_data[0];
            end

            for(int j = 0; j < byte_num; j++) begin
                for(int i = 0; i < 8; i++) begin
                    if(!(i == 0 && j == 0 && ~cr_prev.clock_phase)) begin
                        exchange_bit(MASTER, master_data[8*j+i], slave_data[8*j+i], cr_prev.clock_polarity ^ cr_prev.clock_phase);
                    end

                    if(spiif.interrupts[2] && left > 0) begin
                        apb_txn(TX_ADDR, {24'b0, master_data[8*(byte_num-left) +: 8]}, '0, WRITE, NO_CHECK, rdata);
                        apb_txn(RX_ADDR, '0, {24'b0, slave_data[8*(byte_num-left) +: 8]}, READ, CHECK, rdata);
                        apb_txn(SR_ADDR, {26'b0, 6'b111111}, '0, WRITE, NO_CHECK, rdata);
                    end

                    left--;
                end
            end

            while(!spiif.SS_OUT) begin
                @(posedge CLK);
            end
            // Transaction over
            for(int i = 0; i < byte_num; i++) begin
                apb_txn(RX_ADDR, '0, {24'b0, slave_data[8*i +: 8]}, READ, CHECK, rdata);
            end


        end
    endtask
    */

    task spi_master_txn(
        input logic [255:0] master_data, // Data for master
        input logic [255:0] slave_data, // Data for slave
        input int byte_num //number of bytes of the data
        //for loop or extend bits or master/slave data
    );
        begin

            logic [31:0] rdata;
            spi_cr_t cr_prev;

            // Setup module for master transaction
            // Write in initial data
            for(int i = 0; i < byte_num; i++) begin
                apb_txn(TX_ADDR, {24'b0, master_data[8*i +: 8]}, '0, WRITE, NO_CHECK, rdata);
            end

            // Set byte length register
            apb_txn(BL_ADDR, byte_num, '0, WRITE, NO_CHECK, rdata);
            // Read back
            apb_txn(BL_ADDR, '0, byte_num, READ, CHECK, rdata);

            apb_txn(CR_ADDR, '0, '0, READ, NO_CHECK, rdata);
            cr_prev = spi_cr_t'(rdata);
            cr_prev.mode = MASTER; //1 master mode, 0 slave mode
            cr_prev.start_transaction = 1'b1;
            apb_txn(CR_ADDR, cr_prev, '0, WRITE, NO_CHECK, rdata);

            // Transaction started, start swapping bits
            @(negedge spiif.SS_OUT); // Wait for SS to go low
            if(~cr_prev.clock_phase) begin
                spiif.MISO_IN = slave_data[0];
            end

            for(int j = 0; j < byte_num; j++) begin
                for(int i = 0; i < 8; i++) begin
                    if(!(i == 0 && j == 0 && ~cr_prev.clock_phase)) begin
                        exchange_bit(MASTER, master_data[8*j+i], slave_data[8*j+i], cr_prev.clock_polarity ^ cr_prev.clock_phase);
                    end
                end
            end

            while(!spiif.SS_OUT) begin
                @(posedge CLK);
            end
            // Transaction over
            for(int i = 0; i < byte_num; i++) begin
                apb_txn(RX_ADDR, '0, {24'b0, slave_data[8*i +: 8]}, READ, CHECK, rdata);
            end
        end
    endtask

    task spi_slave_txn(
        input logic [255:0] master_data, // Data for master
        input logic [255:0] slave_data, // Data for slave
        input int byte_num    //number of bytes of the data
        //for loop or extend bits or master/slave data
    );
        begin

            logic [31:0] rdata;
            spi_cr_t cr_prev;

            // Setup module for master transaction
            // Write in data
            for(int i = 0; i < byte_num; i++) begin
                apb_txn(TX_ADDR, {24'b0, slave_data[8*i +: 8]}, '0, WRITE, NO_CHECK, rdata);
            end

            apb_txn(CR_ADDR, '0, '0, READ, NO_CHECK, rdata);
            cr_prev = spi_cr_t'(rdata);
            cr_prev.mode = SLAVE; //1 master mode, 0 slave mode
            cr_prev.start_transaction = 1'b1;
            apb_txn(CR_ADDR, cr_prev, '0, WRITE, NO_CHECK, rdata);
            tb_polarity = cr_prev.clock_polarity;
            repeat(4) @(posedge CLK); // Let SG set up, FSM transition
            #(1);
            spiif.SS_IN = '0;
            // Enable the TB's SCK
            tb_enable = '1;
            if(~cr_prev.clock_phase) begin
                spiif.MOSI_IN = master_data[0];
            end

            //@(posedge CLK); // slave transitions to TXN state
            // Transaction started, start swapping bits
            for(int j = 0; j < byte_num; j++) begin
                for(int i = 0; i < 8; i++) begin
                    if(!(i == 0 && j == 0 && ~cr_prev.clock_phase)) begin
                        exchange_bit(SLAVE, master_data[8*j+i], slave_data[8*j+i], cr_prev.clock_polarity ^ cr_prev.clock_phase);
                    end
                end
            end

            // Get last clock edge
            if(cr_prev.clock_phase ^ cr_prev.clock_polarity) begin
                @(posedge spiif.SCK_IN);
            end else begin
                @(negedge spiif.SCK_IN);
            end

            spiif.SS_IN = '1;
            tb_enable = '0;
            
            repeat(3) @(posedge CLK);

            for(int i = 0; i < byte_num; i++) begin
                apb_txn(RX_ADDR, '0, {24'b0, master_data[8*i +: 8]}, READ, CHECK, rdata);
            end
        end
    endtask

    initial begin

        $display("Size of CR struct: %d bits", $bits(spi_cr_t));
        $display("Size of status struct: %d bits", $bits(spi_status_t));

        tb_enable = '0;
        tb_polarity = '0;
        nRST = 1'b1;
        spiif.MISO_IN = '0;
        //spiif.SCK_IN = '0;
        spiif.MOSI_IN = '0;
        spiif.SS_IN = '1;

        apbif.PADDR = '0;
        apbif.PWDATA = '0;
        apbif.PENABLE = '0;
        apbif.PWRITE = '0;
        apbif.PSEL = '0;

        reset();
        // test1. Single Word Transfer Master Mode
        test_block = "Single Word Transfer Master Mode";
        test_num = 1;

        cr = '0;
        //cr.mode = 1; //not working
        cr.ssoe = '1;
        //cr.water_mark = 'd5;
        cr.clock_phase = 1;
        cr.clock_polarity = 1;
        apb_txn(CR_ADDR, cr,'0 , WRITE, NO_CHECK, dummy_var); //ignored as not check
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);

        spi_master_txn(32'hAA, 32'hBB, 1);
        reset();

        //test2. Single Word Transfer Slave Mode
        test_block = "Single Word Transfer Slave Mode";
        test_num++;

        cr = '0;
        cr.mode = 0; //slave mode
        cr.ssoe = 0; //slave out disabled
        //cr.water_mark = 'd5;
        cr.clock_phase = 1;
        cr.clock_polarity = 1;
        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        //apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd1, '0, WRITE, NO_CHECK, dummy_var);

        spi_slave_txn(32'hAA, 32'hBB, 1);
        reset();

        //test3. Multi Word Transfer Master Mode
        test_block = "Multi Word Transfer Master Mode";
        test_num++;

        cr = '0;
        cr.ssoe = '1;
        //water mark 
        cr.clock_phase = 1;
        cr.clock_polarity = 1;

        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd4, '0, WRITE, NO_CHECK, dummy_var);
        // Send 4 bytes
        spi_master_txn(64'hAABBCCDD, 64'h11223344, 4);

        reset();

        // test4. Multi Word Transfer Slave Mode
        test_block = "test2. Multi Word Transfer Slave Mode";
        test_num++;

        cr = '0;
        cr.mode = 0;
        cr.ssoe = '0;
        //water mark 
        cr.clock_phase = 1;
        cr.clock_polarity = 1;

        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd2, '0, WRITE, NO_CHECK, dummy_var);


        spi_slave_txn(64'hAABB, 64'hDDBB,2);

        reset();

        /*
        // test3.Interrupt transfer complete, master code
        test_block = "Interrupt transfer complete";
        test_num++;

        cr = '0;
        cr.ssoe = '1;
        //water mark 
        cr.clock_phase = '1;
        cr.clock_polarity = '1;

        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd2, '0, WRITE, NO_CHECK, dummy_var);

        spi_master_txn(32'hAA, 32'hBB);
        reset();
        */

        // test5: SPI Modes, Phase master
        test_block = "SPI Modes, Phase 0 Polarity 1 master";
        test_num++;

        cr = '0;
        cr.ssoe = '1;
        //water mark 
        cr.clock_phase = 0;
        cr.clock_polarity = 1;

        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd2, '0, WRITE, NO_CHECK, dummy_var);

        spi_master_txn(32'hAA, 32'hBB,1);
        reset();
        // test6: SPI Modes, Phase slave
        test_block = "SPI Modes, Phase 0 Polarity 1 slave";
        test_num++;

        cr = '0;
        cr.mode = 0;
        cr.ssoe = '0;
        //water mark 
        cr.clock_phase = 0;
        cr.clock_polarity = 1;

        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd2, '0, WRITE, NO_CHECK, dummy_var);

        spi_slave_txn(32'hAA, 32'hBB,1);
        reset();

        //test7: SPI Modes, Polarity master
        test_block = "SPI Modes, Phase 1 Polarity 0 master";
        test_num++;

        cr = '0;
        cr.ssoe = '1;
        //water mark 
        cr.clock_phase = 1;
        cr.clock_polarity = 0;

        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd2, '0, WRITE, NO_CHECK, dummy_var);

        spi_master_txn(32'hAA, 32'hBB,1);
        reset();
    

        //test8: SPI Modes, Polarity slave
        test_block = "SPI Modes, Phase 1 Polarity 0 slave";
        test_num++;

        cr = '0;
        cr.mode = 0;
        cr.ssoe = '0;
        //water mark 
        cr.clock_phase = 1;
        cr.clock_polarity = 0;

        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd2, '0, WRITE, NO_CHECK, dummy_var);

        spi_slave_txn(32'hAA, 32'hBB,1);
        reset();

        //test9: SPI Modes, Phase Polarity 00 master
        test_block = "SPI Modes, phase 0 Polarity 0 master";
        test_num++;

        cr = '0;
        //cr.mode = 0;
        cr.ssoe = '1;
        //water mark 
        cr.clock_phase = 0;
        cr.clock_polarity = 0;

        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd2, '0, WRITE, NO_CHECK, dummy_var);

        spi_master_txn(32'hAA, 32'hBB,1);
        reset();
        //test6-2: SPI Modes, Phase Polarity 00 slave
        test_block = "SPI Modes, phase 0 Polarity 0 slave";
        test_num++;

        cr = '0;
        cr.mode = 0;
        cr.ssoe = '0;
        //water mark 
        cr.clock_phase = 0;
        cr.clock_polarity = 0;

        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd2, '0, WRITE, NO_CHECK, dummy_var);

        spi_slave_txn(32'hAA, 32'hBB,1);
        reset();
        

        //test10: MSB First master
        test_block = "MSB First master";
        test_num++;

        cr = 32'h00000020;
        cr.ssoe = '1;
        //water mark 
        cr.clock_phase = 1;
        cr.clock_polarity = 1;
        //cr.msb_first = 1; Test works, but task does not accommodate MSB First yet

        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd2, '0, WRITE, NO_CHECK, dummy_var);

        spi_master_txn(32'hAA, 32'hBB,1);
        reset();
        //test11: MSB First slave
        test_block = "MSB First slave";
        test_num++;

        cr = '0;
        cr.mode = 0;
        cr.ssoe = '0;
        //water mark 
        cr.clock_phase = 1;
        cr.clock_polarity = 1;

        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd2, '0, WRITE, NO_CHECK, dummy_var);

        spi_slave_txn(32'hAA, 32'hBB,1);
        reset();

        //test11: SSOE
        /*test_block = "SSOE";
        test_num++;

        cr = '0;
        cr.ssoe = '0;
        //water mark 
        cr.clock_phase = 0;
        cr.clock_polarity = 1;

        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd2, '0, WRITE, NO_CHECK, dummy_var);

        spi_master_txn(32'hAA, 32'hBB,1);
        reset();
        $finish();
        */
        //test12:Dift_block = Different Baud rates;
        test_block = "Different Baud rates";
        test_num++;

        cr = '0;
        cr.ssoe = '1;
        //cr.water_mark = 'd5;
        cr.clock_phase = 1;
        cr.clock_polarity = 1;
        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(32'h15, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd1, '0, WRITE, NO_CHECK, dummy_var);

        spi_master_txn(32'hAA, 32'hBB,1);

        reset();

        //test13:Different byte lengths
        test_block = "Different byte rates";
        test_num++;

        cr = '0;
        cr.ssoe = '1;
        //cr.water_mark = 'd5;
        cr.clock_phase = 1;
        cr.clock_polarity = 1;
        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(32'h16, 'd1, '0, WRITE, NO_CHECK, dummy_var);

        spi_master_txn(32'hAA, 32'hBB,1);
        reset();

        //test14:Dift_block = Different Baud rates, master mode
        test_block = "Different Baud rates, master mode";
        test_num++;

        cr = 32'h00000002;
        cr.ssoe = '1;
        //cr.water_mark = 'd5;
        cr.clock_phase = 1;
        cr.clock_polarity = 1;
        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(32'h15, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd1, '0, WRITE, NO_CHECK, dummy_var);

        spi_master_txn(32'hAA, 32'hBB,1);

        reset();

        //test15:status registers
        test_block = "status registers";
        test_num ++;
        cr = 32'h00000002;
        cr.ssoe = '1;
        cr.clock_phase = 1;
        cr.clock_polarity = 1;
        streg = 32'hffffffff;
        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(32'h16, 'd1, '0, WRITE, NO_CHECK, dummy_var);

        spi_master_txn(32'hAA, 32'hBB,1);
        reset();


        // Consecutive transfers - Master
        test_block = "Master - Consecutive";
        test_num++;
        cr = '0;
        cr.ssoe = '1;
        cr.clock_phase = 0;
        cr.mode = 1;
        cr.clock_polarity = 0;
        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(32'h16, 'd4, '0, WRITE, NO_CHECK, dummy_var);


        spi_master_txn(32'hAABBCCDD, 32'h11223344, 4);
        spi_master_txn(32'hCCDDEEFF, 32'h55667788, 4);
        spi_master_txn(32'h00110011, 32'hDEADBEEF, 4);
        
        // Consecutive transfers - Slave
        test_block = "Slave - Consecutive";
        test_num++;
        cr = '0;
        cr.ssoe = '1;
        cr.clock_phase = 0;
        cr.clock_polarity = 0;
        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(32'h16, 'd4, '0, WRITE, NO_CHECK, dummy_var);


        spi_master_txn(32'hAABBCCDD, 32'h11223344, 4);
        spi_master_txn(32'hCCDDEEFF, 32'h55667788, 4);
        spi_master_txn(32'h00110011, 32'hDEADBEEF, 4);


        reset();
        // interrupts
        test_block = "Interrupts";
        test_num++;

        cr = '0;
        cr.ssoe = '1;
        cr.clock_phase = 0;
        cr.clock_polarity = 0;
        cr.interrupt_enable = '1;
        apb_txn(CR_ADDR, cr, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BR_ADDR, 'd16, '0, WRITE, NO_CHECK, dummy_var);
        apb_txn(BL_ADDR, 'd32, '0, WRITE, NO_CHECK, dummy_var);
        
        spi_master_txn($random, $random, 32);

        apb_txn(SR_ADDR, 32'b111111, '0, WRITE, NO_CHECK, dummy_var);
        //apb_txn(SR_ADDR, '0, '0, READ, CHECK, dummy_var);

        $finish();

        //
        //                                                                      */
        //test11 transfer longer than 32 bits. refill
        //receiving while sending not-care data. 
    end

endmodule
