// `timescale 1ns / 10ps
//`include "timer_pkg.svh"
//`include "timer_if.sv"
import timer_pkg::*;

module tb_timer
#(
    parameter BITS_WIDTH = 32,
    parameter CHANNELS = 8,
    parameter PERIOD = 20
)

();
/*
module tb_timer();
    localparam BITS_WIDTH = 32;
    localparam MAX_BIT = BITS_WIDTH - 1;
    localparam PERIOD = 20;
    localparam NUM_REGISTERS = 6;
    localparam CHANNELS = 8;
    localparam MAX_CHNNL = CHANNELS - 1;
    */
    localparam MAX_CHNNL = CHANNELS - 1;

    //timer Register indicies
    localparam int TCNT_IND = 0;  //32'hXXXXX000
    localparam int TCR_IND = 1;  //32'hXXXXX004
    localparam int TPSC_IND = 2;  //32'hXXXXX008
    localparam int TARR_IND = 3;  //32'hXXXXX00C
    int TCCMR_IND[];
    int TCCR_IND[]; 
    
    logic tb_clk, tb_n_rst;
    logic [MAX_CHNNL:0] tb_t_in;
    logic [MAX_CHNNL:0] tb_t_out;
    logic [MAX_CHNNL:0] tb_t_irq;
    logic tb_tc_irq;
    logic tb_check;
    logic tb_mismatch;

    bus_protocol_if tb_busif();
    timer_if timerif();

    string   tb_test_case;
    integer  tb_test_case_num;
    always begin
        tb_clk = 1'b0;
        #(PERIOD/2);
        tb_clk = 1'b1;
        #(PERIOD/2);
    end

    advanced_timer #(.CHANNELS(CHANNELS),.BITS_WIDTH(BITS_WIDTH)) DUT(
        .clk(tb_clk),
        .n_rst(tb_n_rst),
        .timerif(timerif),
        .busif(tb_busif)
    );

//*****************************************************************************
// DUT Related TB Tasks
//*****************************************************************************
// Task for standard DUT reset procedure
    task reset_dut;
        begin
        // Activate the reset
        tb_n_rst = 1'b0;

        // Maintain the reset for more than one cycle
        @(posedge tb_clk);
        @(posedge tb_clk);

        // Wait until safely away from rising edge of the clock before releasing
        @(negedge tb_clk);
        tb_n_rst = 1'b1;

        // Leave out of reset for a couple cycles before allowing other stimulus
        // Wait for negative clock edges, 
        // since inputs to DUT should normally be applied away from rising clock edges
        @(negedge tb_clk);
        @(negedge tb_clk);
        end
    endtask
    /*
    task check_outputs;
        input string check_tag;
        begin
        tb_mismatch = 1'b0;
        tb_check    = 1'b1;
        if(tb_expected_tcnt == tb_tcnt) begin // Check passed
            $info("Correct 'tcnt' output %s during %s test case", check_tag, tb_test_case);
        end
        else begin // Check failed
            tb_mismatch = 1'b1;
            $error("Incorrect 'tcnt' output %s during %s test case", check_tag, tb_test_case);
        end

        if(tb_expected_nxt_tcnt == tb_nxt_tcnt) begin // Check passed
            $info("Correct 'nxt_tcnt' output %s during %s test case", check_tag, tb_test_case);
        end
        else begin // Check failed
            tb_mismatch = 1'b1;
            $error("Incorrect 'nxt_tcnt' output %s during %s test case", check_tag, tb_test_case);
        end
        // Wait some small amount of time so check pulse timing is visible on waves
        #(0.1);
        tb_check =1'b0;
        end
    endtask
    */

    initial begin
        TCCMR_IND = new[CHANNELS];
        TCCR_IND = new[CHANNELS]; 
        foreach(TCCMR_IND[i]) begin
            TCCMR_IND[i] = TARR_IND + i + 1; //may need to check cast of int to logic in SV
            TCCR_IND[i] = TARR_IND + CHANNELS + i + 1;
        end
        /*
        foreach(TCCMR_IND[i]) begin
            $display("\tTCCMR_IND[%0d] = %0d",i, TCCMR_IND[i]);
            $display("\tTCCR_IND[%0d] = %0d",i, TCCR_IND[i]);
        end
        */
        tb_test_case       = "Initilization";
        tb_test_case_num   = -1;
        tb_check           = 1'b0;
        tb_mismatch        = 1'b0;
        tb_n_rst           = 1'b1;
        tb_t_in            = 8'd0;
        tb_busif.wen          = 1'b0;
        tb_busif.ren          = 1'b0;
        tb_busif.addr         = '0;
        tb_busif.wdata        = '0;
        tb_busif.strobe       = '1;

        #(0.1);

        tb_test_case     = "Power-on-Reset";
        tb_test_case_num = tb_test_case_num + 1;

        // Setup counter provided signals with 'active' values for reset check
        reset_dut();

        tb_test_case     = "Turn on counter";
        tb_test_case_num++;
        tb_busif.wen        = 1'b1;
        tb_busif.addr = TCCMR_IND[7] << 2;
        tb_busif.wdata = {tb_busif.rdata[31:9],ENABLED,FROZEN,OUTPUT,RISING,ENABLED};
        #(PERIOD);
        tb_busif.addr = TCCR_IND[7] << 2;
        tb_busif.wdata = 32'd50;
        #(PERIOD);
        tb_busif.addr = TCR_IND << 2;
        tb_busif.wdata[7] = 1'b1;
        #(PERIOD);
        tb_busif.wen        = 1'b0;
        for(int i = 0; i < 50; i++) begin
            #(PERIOD);
        end
        #(PERIOD);
        #(PERIOD);

        reset_dut();

        tb_test_case     = "prescale 3 clks, match hi out";
        tb_test_case_num++;
        tb_busif.wen        = 1'b1;
        tb_busif.addr = TCCMR_IND[7] << 2;
        tb_busif.wdata = {tb_busif.rdata[31:9],ENABLED,MATCH_HI,OUTPUT,RISING,ENABLED};
        #(PERIOD);
        tb_busif.addr = TCCR_IND[7] << 2;
        tb_busif.wdata = 32'd30;
        #(PERIOD);
        tb_busif.addr = TPSC_IND << 2;
        tb_busif.wdata = 32'd2;
        #(PERIOD);
        tb_busif.addr = TARR_IND << 2;
        tb_busif.wdata = 32'd50;
        #(PERIOD);
        tb_busif.addr = TCR_IND << 2;
        tb_busif.wdata[7] = 1'b1;
        #(PERIOD);
        tb_busif.wen        = 1'b0;
        for(int i = 0; i < 150; i++) begin
            #(PERIOD);
        end
        #(PERIOD);
        #(PERIOD);
/*
        tb_test_case     = "Output Frozen, tccr = 50"; //do we want interrupt to generate at beginning?
        tb_test_case_num++;
        reset_dut();
        busif.wen        = 1'b1;
        tb_tarr = 32'd100;
        tb_reg_select[tb_TCCMR_IND] = 1'b1;
        busif.wdata[8:0]      = {ENABLED,FROZEN,OUTPUT,RISING,ENABLED};
        @(posedge tb_clk);
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        tb_reg_select[tb_TCCR_IND] = 1'b1;
        busif.wdata                = 32'd50;
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end
        #(PERIOD);
        #(PERIOD);

        tb_test_case     = "Output force hi, tccr = 50"; //should t_out combinationally depend on force_hi and force_lo?
        tb_test_case_num++;
        @(negedge tb_clk);
        busif.wen        = 1'b1;
        tb_reg_select[tb_TCCR_IND] = 1'b0;
        tb_reg_select[tb_TCCMR_IND] = 1'b1;
        busif.wdata     = {tb_tccmr[31:9],ENABLED,FORCE_HI,OUTPUT,RISING,ENABLED};
        @(posedge tb_clk);
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end
        #(PERIOD);
        #(PERIOD);
        
        tb_test_case     = "Output force lo, tccr = 50"; //do we want interrupt to generate at beginning?
        tb_test_case_num++;
        @(negedge tb_clk);
        busif.wen        = 1'b1;
        tb_reg_select[tb_TCCR_IND] = 1'b0;
        tb_reg_select[tb_TCCMR_IND] = 1'b1;
        busif.wdata[8:0]      = {ENABLED,FORCE_LO,OUTPUT,RISING,ENABLED};
        @(posedge tb_clk);
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end
        #(PERIOD);
        #(PERIOD);

        tb_test_case     = "Output match hi, tccr = 50";
        tb_test_case_num++;
        reset_dut();
        @(negedge tb_clk);
        busif.wen        = 1'b1;
        tb_reg_select[tb_TCCR_IND] = 1'b0;
        tb_reg_select[tb_TCCMR_IND] = 1'b1;
        busif.wdata      = {23'd0,ENABLED,MATCH_HI,OUTPUT,RISING,ENABLED};
        @(posedge tb_clk);
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        tb_reg_select[tb_TCCR_IND] = 1'b1;
        busif.wdata                = 32'd50;
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end
        #(PERIOD);
        #(PERIOD);

        tb_test_case     = "Output match lo, tccr = 50";
        tb_test_case_num++;
        @(negedge tb_clk);
        busif.wen        = 1'b1;
        tb_reg_select[tb_TCCR_IND] = 1'b0;
        tb_reg_select[tb_TCCMR_IND] = 1'b1;
        busif.wdata     = {tb_tccmr[31:9],ENABLED,MATCH_LO,OUTPUT,RISING,ENABLED};
        @(posedge tb_clk);
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end
        #(PERIOD);
        #(PERIOD);

        tb_test_case     = "Output toggle, tccr = 50";
        tb_test_case_num++;
        @(negedge tb_clk);
        busif.wen        = 1'b1;
        tb_reg_select[tb_TCCR_IND] = 1'b0;
        tb_reg_select[tb_TCCMR_IND] = 1'b1;
        busif.wdata     = {tb_tccmr[31:9],ENABLED,TOGGLE,OUTPUT,RISING,ENABLED};
        @(posedge tb_clk);
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end
        #(PERIOD);
        #(PERIOD);
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end

        tb_test_case     = "Output PWM1, tccr = 30";
        tb_test_case_num++;
        tb_reg_select[tb_TCCR_IND] = 1'b1;
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        busif.wdata                = 32'd30;
        @(posedge tb_clk);
        tb_nxt_tcr[0] = 1;
        @(posedge tb_clk);
        tb_tcr[0] = 1;
        @(negedge tb_clk);
        busif.wen        = 1'b1;
        tb_reg_select[tb_TCCR_IND] = 1'b0;
        tb_reg_select[tb_TCCMR_IND] = 1'b1;
        busif.wdata      = {23'd0,ENABLED,PWM1,OUTPUT,RISING,ENABLED};
        tb_nxt_tcr[0] = 0;
        @(posedge tb_clk);
        tb_tcr[0] = 0;
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end
        #(PERIOD);
        #(PERIOD);
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end
        #(PERIOD);

        tb_test_case     = "Output PWM2, tccr = 30";
        tb_test_case_num++;
        @(posedge tb_clk);
        tb_tcr[0] = 1;
        @(negedge tb_clk);
        busif.wen        = 1'b1;
        tb_reg_select[tb_TCCR_IND] = 1'b0;
        tb_reg_select[tb_TCCMR_IND] = 1'b1;
        busif.wdata      = {23'd0,ENABLED,PWM2,OUTPUT,RISING,ENABLED};
        @(posedge tb_clk);
        tb_tcr[0] = 0;
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end
        #(PERIOD);
        #(PERIOD);
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end

        tb_test_case     = "Input rising";
        tb_test_case_num++;
        tb_tcr[0] = 1'b1;
        reset_dut();
        tb_nxt_tcr[0] = 1'b0;
        busif.wen        = 1'b1;
        tb_reg_select[tb_TCCR_IND] = 1'b0;
        tb_reg_select[tb_TCCMR_IND] = 1'b1;
        busif.wdata      = {23'd0,ENABLED,FROZEN,TI1_IN,RISING,ENABLED};
        @(posedge tb_clk);
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        tb_tcr[0] = 1'b0;
        while(!(tb_tcnt == 32'd30)) begin
            #(PERIOD);
        end
        @(negedge tb_clk);
        tb_t_in = 1'b1;
        @(negedge tb_clk);
        tb_t_in = 1'b0;
        #(PERIOD);
        #(PERIOD);
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end

        tb_test_case     = "Input falling";
        tb_test_case_num++;
        tb_tcr[0] = 1'b1;
        reset_dut();
        tb_nxt_tcr[0] = 1'b0;
        busif.wen        = 1'b1;
        tb_reg_select[tb_TCCR_IND] = 1'b0;
        tb_reg_select[tb_TCCMR_IND] = 1'b1;
        busif.wdata      = {23'd0,ENABLED,FROZEN,TI1_IN,FALLING,ENABLED};
        @(posedge tb_clk);
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        tb_tcr[0] = 1'b0;
        while(!(tb_tcnt == 32'd30)) begin
            #(PERIOD);
        end
        @(negedge tb_clk);
        tb_t_in = 1'b1;
        @(negedge tb_clk);
        tb_t_in = 1'b0;
        #(PERIOD);
        #(PERIOD);
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end

        tb_test_case     = "Input rising and falling";
        tb_test_case_num++;
        tb_tcr[0] = 1'b1;
        reset_dut();
        tb_nxt_tcr[0] = 1'b0;
        busif.wen        = 1'b1;
        tb_reg_select[tb_TCCR_IND] = 1'b0;
        tb_reg_select[tb_TCCMR_IND] = 1'b1;
        busif.wdata      = {23'd0,ENABLED,FROZEN,TI1_IN,BOTH,ENABLED};
        @(posedge tb_clk);
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        tb_tcr[0] = 1'b0;
        while(!(tb_tcnt == 32'd30)) begin
            #(PERIOD);
        end
        @(negedge tb_clk);
        tb_t_in = 1'b1;
        @(negedge tb_clk);
        tb_t_in = 1'b0;
        #(PERIOD);
        #(PERIOD);
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end

        tb_test_case     = "Input rise and fall within one period";
        tb_test_case_num++;
        tb_tcr[0] = 1'b1;
        reset_dut();
        tb_nxt_tcr[0] = 1'b0;
        busif.wen        = 1'b1;
        tb_reg_select[tb_TCCR_IND] = 1'b0;
        tb_reg_select[tb_TCCMR_IND] = 1'b1;
        busif.wdata      = {23'd0,ENABLED,FROZEN,TI1_IN,BOTH,ENABLED};
        @(posedge tb_clk);
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        tb_tcr[0] = 1'b0;
        while(!(tb_tcnt == 32'd30)) begin
            #(PERIOD);
        end
        @(negedge tb_clk);
        tb_t_in = 1'b1;
        #(5);
        tb_t_in = 1'b0;
        #(PERIOD);
        #(PERIOD);
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end

        tb_test_case     = "Input TCCR write error";
        tb_test_case_num++;
        reset_dut();
        busif.wen        = 1'b1;
        tb_reg_select[tb_TCCR_IND] = 1'b0;
        tb_reg_select[tb_TCCMR_IND] = 1'b1;
        busif.wdata      = {23'd0,ENABLED,FROZEN,TI1_IN,BOTH,ENABLED};
        @(posedge tb_clk);
        tb_reg_select[tb_TCCMR_IND] = 1'b0;
        @(negedge tb_clk);
        tb_reg_select[tb_TCCR_IND] = 1'b1;
        busif.wdata = 32'd40;
        while(!(tb_tcnt == 32'd30)) begin
            #(PERIOD);
        end
        @(negedge tb_clk);
        tb_t_in = 1'b1;
        @(negedge tb_clk);
        tb_t_in = 1'b0;
        #(PERIOD);
        #(PERIOD);
        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end
        */
        #(PERIOD);
        #(PERIOD);
        #(PERIOD);
        $finish(); //use finish for Verilator
        // $stop(); //use stop for Modelsim
    end

endmodule
