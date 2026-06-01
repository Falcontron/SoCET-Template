`timescale 1ns / 10ps

module tb_time_base();
    localparam BITS_WIDTH = 32;
    localparam MAX_BIT = BITS_WIDTH - 1;
    localparam PERIOD = 20;

    logic tb_clk, tb_n_rst;
    logic tb_tc_en;
    logic tb_tc_rst;
    logic [MAX_BIT:0] tb_tarr;
    logic [MAX_BIT:0] tb_tpsc;
    logic [MAX_BIT:0] tb_tcnt, tb_nxt_tcnt;
    logic [MAX_BIT:0] tb_expected_tcnt, tb_expected_nxt_tcnt;
    logic tb_check;
    logic tb_mismatch;

    string   tb_test_case;
    integer  tb_test_case_num;
    always begin
        tb_clk = 1'b0;
        #(PERIOD/2);
        tb_clk = 1'b1;
        #(PERIOD/2);
    end

    time_base #(.BITS_WIDTH(BITS_WIDTH)) DUT(
        .clk(tb_clk),
        .n_rst(tb_n_rst),
        .tc_en(tb_tc_en),
        .tc_rst(tb_tc_rst),
        .tarr(tb_tarr),
        .tpsc(tb_tpsc),
        .tcnt(tb_tcnt),
        .nxt_tcnt(tb_nxt_tcnt)
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
    // Clock
    

    initial begin
        tb_test_case       = "Initilization";
        tb_test_case_num   = -1;
        tb_check           = 1'b0;
        tb_mismatch        = 1'b0;
        tb_n_rst           = 1'b1;
        tb_tc_en           = 1'b0;
        tb_tc_rst          = 1'b0;
        tb_tarr            = 32'd0;
        tb_tpsc            = 32'd0;

        #(0.1);

        tb_test_case     = "Power-on-Reset";
        tb_test_case_num = tb_test_case_num + 1;

        // Setup counter provided signals with 'active' values for reset check
        tb_tc_en           = 1'b1;
        tb_tc_rst          = 1'b0;
        tb_tarr            = '1;
        @(posedge tb_clk);
        @(posedge tb_clk);
        reset_dut();
        @(posedge tb_clk);
        @(posedge tb_clk);

        tb_test_case     = "Sync Reset and timer disable";
        tb_test_case_num++;

        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end
        @(negedge tb_clk);
        tb_tc_rst          = 1'b1;
        #(PERIOD);
        #(PERIOD);
        tb_tc_rst          = 1'b0;
        #(PERIOD);
        #(PERIOD);
        tb_tc_en           = 1'b0;
        #(PERIOD);
        #(PERIOD);
        tb_tc_en           = 1'b1;
        

        tb_test_case     = "Timer disable";
        tb_test_case_num++;

        while(!(tb_tcnt == 32'd100)) begin
            #(PERIOD);
        end
        @(negedge tb_clk);
        tb_tc_en          = 1'b0;
        #(PERIOD);
        #(PERIOD);
        tb_tc_en          = 1'b1;
        
        tb_test_case     = "Smaller rollover";
        tb_test_case_num++;
        reset_dut();
        tb_tarr = 32'd50;
        while(!(tb_tcnt == 32'd50)) begin
            #(PERIOD);
        end
        #(PERIOD);
        #(PERIOD);

        tb_test_case     = "Smaller rollover, prescale by 2";
        tb_test_case_num++;
        reset_dut();
        tb_tarr = 32'd50;
        tb_tpsc = 32'd1;
        while(!(tb_tcnt == 32'd50)) begin
            #(PERIOD);
        end

        // tb_test_case     = "Max rollover, no prescale";
        // tb_test_case_num++;
        //TEST CASE TOO LONG TO RUN
        // while(!(tb_tcnt == '1)) begin
        //     #(PERIOD);
        // end
        #(PERIOD);
        #(PERIOD);
        #(PERIOD);
        // Check outputs for reset state
        // tb_expected_tcnt  = '0;
        // tb_expected_nxt_tcnt = 32'd1;
        // check_outputs("after DUT reset");
        $stop();
    end

endmodule
