/*
John Skubic

11/5/14

Test bench for gpio

Edited 8/14/22 Cole Nelson

*/


`define DISP_ERROR(msg) \
    $display("Time %4t [FAILED]: Test %s (%2d) %s\n", \
        $time, test_name, test_number, msg);

`define DISP_ERROR_EXP(exp, act) \
    $display("Time %4t [FAILED]: Test %s (%2d)\n\tExpected %x, Actual %x\n", \
        $time, test_name, test_number, exp, act);

`define SELF_CHECK(exp, act) \
    if(exp != act) begin \
        `DISP_ERROR_EXP(exp, act); \
        fail++; \
    end

module tb_gpio #(
    parameter int NUM_PINS = 8
) ();

    localparam int DELAY = 1;
    localparam int PERIOD = 20;

    localparam logic [31:0] DATA_ADDR = 32'h0;
    localparam logic [31:0] DIR_ADDR = 32'h4;
    localparam logic [31:0] INTR_EN_ADDR = 32'h8;
    localparam logic [31:0] POS_EN_ADDR = 32'hC;
    localparam logic [31:0] NEG_EN_ADDR = 32'h10;
    localparam logic [31:0] INTR_CLR_ADDR = 32'h14;
    localparam logic [31:0] INTR_STAT_ADDR = 32'h18;

    localparam logic [31:0] PIN_MASK = ('1) >> (32 - NUM_PINS);


    gpio_if #(.NUM_PINS(NUM_PINS)) gpioif ();
    bus_protocol_if busif ();


    logic CLK, nRST;
    string test_name;
    int test_number;
    int fail;
    logic [31:0] test_data;

    gpio_wrapper
    `ifndef SYNTHESIS
    #(
        .NUM_PINS(NUM_PINS)
    )
    `endif
    DUT (
        // top-level inputs
        .CLK(CLK),
        .nRST(nRST),
        // gpioif
        .in_data(gpioif.in_data),
        .oe_data(gpioif.oe_data),
        .out_data(gpioif.out_data),
        .irq(gpioif.irq),
        // busif
        .wen(busif.wen),
        .ren(busif.ren),
        .addr(busif.addr),
        .wdata(busif.wdata),
        .strobe(busif.strobe),
        .request_stall(busif.request_stall),
        .error(busif.error),
        .rdata(busif.rdata)
    );

    //clock generation
    always begin
        CLK = 1'b0;
        #(PERIOD / 2);
        CLK = 1'b1;
        #(PERIOD / 2);
    end


    task reset();
        begin
            nRST = 1'b0;
            repeat (2) @(negedge CLK);
            nRST = 1'b1;
            @(posedge CLK);
            #(1);
        end
    endtask


    task reg_read(input logic [31:0] offset, input logic [31:0] expected);
        @(negedge CLK);
        busif.ren = 1;
        busif.wen = 0;
        busif.addr = offset;
        busif.wdata = 0;
        busif.strobe = 0;

        @(posedge CLK);
        #(1);

        `SELF_CHECK(expected, busif.rdata);

        busif.ren  = 0;
        busif.addr = 0;
    endtask

    task reg_write(input logic [31:0] offset, input logic [31:0] wdata);
        @(negedge CLK);
        busif.ren = 0;
        busif.wen = 1;
        busif.addr = offset;
        busif.wdata = wdata;
        busif.strobe = 4'hF;

        @(posedge CLK);
        #(1);

        busif.wen = 0;
        busif.addr = 0;
        busif.wdata = 0;
        busif.strobe = 0;
    endtask

    initial begin
        $display("----------------------------------");
        $display(" Running TB with NUM_PINS = %0d", NUM_PINS);
        $display("----------------------------------");

        busif.ren = 0;
        busif.wen = 0;
        busif.addr = 0;
        busif.wdata = 0;
        busif.strobe = 0;

        //setup tb variables
        nRST = 1;
        gpioif.in_data = 32'b0;
        test_name = "Reset";
        test_number = 1;
        fail = 0;

        reset();
        if (gpioif.oe_data != 'b0) begin
            `DISP_ERROR("Incorrect reset value for DIR register");
            fail++;
        end

        test_number++;
        if (gpioif.out_data != 'b0) begin
            `DISP_ERROR("Incorrect reset value for DATA register");
            fail++;
        end

        test_number++;
        if (gpioif.irq != 'b0) begin
            `DISP_ERROR("Incorrect reset value for INTR_STAT register");
            fail++;
        end


        // Test block 2: Basic input
        test_name = "Basic input";
        test_number++;
        test_data = 32'h3A3A3A3A;
        gpioif.in_data = test_data;
        @(posedge CLK);
        reg_read(DATA_ADDR, test_data & PIN_MASK);

        // Ensure that interrupt did not fire since interrupts are disabled
        test_number++;
        `SELF_CHECK('0, gpioif.irq);

        // Test block 2: Configure to output mode
        test_name = "Output";
        test_number++;
        gpioif.in_data = 'b0;
        test_data = '1 & PIN_MASK;
        reg_write(DIR_ADDR, '1);
        reg_write(DATA_ADDR, test_data);
        @(posedge CLK);
        #(1);
        `SELF_CHECK(test_data[NUM_PINS-1:0], gpioif.out_data);

        test_number++;
        test_data = '0 & PIN_MASK;
        reg_write(DATA_ADDR, test_data);
        @(posedge CLK);
        #(1);
        `SELF_CHECK(test_data[NUM_PINS-1:0], gpioif.out_data);


        // Test block 3: Configure to mixed input/output mode w/interrupts
        test_name = "I/O + Interrupt";
        test_number++;
        reg_write(DIR_ADDR, 32'h0F);  // Lower 4 output, upper 4 input
        reg_write(INTR_EN_ADDR, 32'hF0);
        reg_write(POS_EN_ADDR, 32'h30);
        reg_write(NEG_EN_ADDR, 32'hC0);
        reg_write(DATA_ADDR, 32'h0A);

        @(posedge CLK);
        #(1);
        test_data = 32'h0A & PIN_MASK;
        `SELF_CHECK(test_data[NUM_PINS-1:0], gpioif.out_data);

        test_number++;
        gpioif.in_data = 32'hF0;
        @(posedge CLK);
        #(1);
        test_data = 32'h30 & PIN_MASK;
        `SELF_CHECK(test_data[NUM_PINS-1:0], gpioif.irq);

        test_number++;
        reg_read(INTR_STAT_ADDR, gpioif.irq);

        // Check partial interrupt clears: CLear unset bits, see that
        // interrupt is unaffected
        test_number++;
        reg_write(INTR_CLR_ADDR, 32'h0F);
        @(posedge CLK);  // Allow time for clear to take effect
        #(1);
        test_data = 32'h30 & PIN_MASK;
        `SELF_CHECK(test_data[NUM_PINS-1:0], gpioif.irq);

        // Actually clear interrupt
        test_number++;
        reg_write(INTR_CLR_ADDR, 32'hF0);
        @(posedge CLK);
        #(1);
        `SELF_CHECK('0, gpioif.irq);

        test_number++;
        gpioif.in_data = 32'h00;
        @(posedge CLK);
        #(1);
        test_data = 32'hC0 & PIN_MASK;
        `SELF_CHECK(test_data[NUM_PINS-1:0], gpioif.irq);

        test_number++;
        reg_read(INTR_STAT_ADDR, gpioif.irq);

        test_number++;
        reg_write(INTR_CLR_ADDR, 32'hFF);
        @(posedge CLK);
        #(1);
        `SELF_CHECK('0, gpioif.irq);

        test_number++;
        reg_write(INTR_EN_ADDR, 32'h00);
        gpioif.in_data = 32'hFF;
        @(posedge CLK);
        #(1);
        `SELF_CHECK('0, gpioif.irq);

        // Block 4: Test write strobe
        // The low byte shouldn't be set after this write
        test_name = "write strobe";
        reg_write(DIR_ADDR, '1);
        @(negedge CLK);
        busif.ren = 0;
        busif.wen = 1;
        busif.addr = DATA_ADDR;
        busif.wdata = '1;
        busif.strobe = 4'b1110;

        @(posedge CLK);
        #(1);
        busif.ren = 0;
        busif.wen = 0;
        busif.addr = 0;
        busif.wdata = 0;
        busif.strobe = 0;

        // Check output data is correct
        test_data = ~(32'hFF) & PIN_MASK;
        `SELF_CHECK(test_data[NUM_PINS-1:0], gpioif.out_data);

        $display("Passed %2d / %2d tests\n", test_number - fail, test_number);
        $finish();
    end

endmodule
