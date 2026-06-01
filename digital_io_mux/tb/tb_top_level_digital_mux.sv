//`timescale 1ns / 10ps

module tb_top_level_digital_mux();

// parameter for digital mux
localparam NUM_PINS = 20; // max:32
localparam NUM_FUNC = 2; // max:4
localparam NUM_BITS = 1; // max:2
localparam NUM_REGS = 1; // max:2

// parameter for clock
localparam CLK_PERIOD = 10;

// parameters for control task execute_transactions
localparam NUM_TRANS = 16;
int index;

// signals for system signals
logic tb_clk;
logic tb_n_rst;

// signal for apb slave interface
logic tb_psel, tb_penable, tb_pwrite, tb_pslverr,tb_pready;
logic [3:0] tb_pstrb;
logic [31:0] tb_paddr, tb_pwdata, tb_prdata;
logic [31:0] tb_expected_prdata;
logic [NUM_PINS * NUM_FUNC - 1:0] tb_from_module;
logic [NUM_PINS * NUM_FUNC - 1:0] tb_output_enable;
logic [NUM_PINS * NUM_FUNC - 1:0] tb_to_module;
logic [NUM_PINS - 1:0] tb_to_module_iopad;
logic [NUM_PINS - 1:0] tb_from_module_ff;
logic [NUM_PINS - 1:0] tb_output_en_ff;
logic [NUM_PINS - 1:0] expected_tb_output_en_ff;

int testcase_num = 0;


// signals/parameters for simulating signals from physical pin or peripheral
logic dataline_input;     // dataline_input simulates input data.
                          // e.g. assign from_module[0][0] = dataline_input, this can simulate data from peripheral from module
localparam SIGNAL_P = 20 * CLK_PERIOD;      // the period of data on datalin in terms of clock cycles
logic [31:0] data, monitored_data, monitored_data_2;        // data that will actually be sent on data line
logic monitored_dataline;


// structure for simulating the apb bus
typedef struct {
    logic [31:0] PADDR;
    logic [31:0] PDATA; // when write, PDATA as PWDATA, when read, as expected
                        // value of PRDATA
    logic [3:0] PSTRB;
    logic PWRITE;
    logic ex_pslverr;
} APB_TRANS;

//*****************************************************************************
// Clock Generation Block
//*****************************************************************************
always begin
  // Start with clock low to avoid false rising edge events at t=0
  tb_clk = 1'b0;
  // Wait half of the clock period before toggling clock value (maintain 50% duty cycle)
  #(CLK_PERIOD/2.0);
  tb_clk = 1'b1;
  // Wait half of the clock period before toggling clock value via rerunning the block (maintain 50% duty cycle)
  #(CLK_PERIOD/2.0);
end

//*****************************************************************************
// tasks
//*****************************************************************************

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

task reset_bus;
begin
    @(posedge tb_clk);
    #(CLK_PERIOD / 10);
    tb_psel = 1'b0;
    tb_penable = 1'b0;
    tb_pwrite = 1'b0;  // default as reading
    tb_paddr = 32'b0;
    tb_pwdata = 32'b0;
    tb_pstrb = 4'b0;
    tb_from_module = '0;
    tb_output_enable = '0;
    tb_to_module_iopad = '0;
    @(negedge tb_clk);
end
endtask

task execute_transactions;
    input APB_TRANS trans;
    int i;
begin
    reset_bus();
    @(posedge tb_clk);
    #(CLK_PERIOD / 10); // in order to pass the hold time, not sure
                        // if 1 ns is too long or too short
    tb_psel = 1'b1;

    for(i = 0; i < 1; i++)
    begin
        // address phase
        tb_penable = 1'b0;
        tb_paddr = trans.PADDR;
        tb_pwrite = trans.PWRITE;
        tb_pstrb = trans.PSTRB;
        if(trans.PWRITE == 1) begin // write into
            tb_pwdata = trans.PDATA;
        end
        else begin
            //tb_pstrb = 4'b0;
            tb_pwdata = 32'b0;
            tb_expected_prdata = trans.PDATA;
        end
    
        @(posedge tb_clk)
        #(CLK_PERIOD / 10);
        // access phase/data phase
        tb_penable = 1'b1;
        if(tb_pslverr != trans.ex_pslverr)
            $error("Incorrect |pslverr| during testcase #%d", testcase_num);
        else
            $info("Correct |pslverr| during testcase #%d", testcase_num);
        
	    if(tb_pwrite == 1'b0 && tb_pslverr != 1'b1) begin
            if(tb_expected_prdata != tb_prdata)
                $error("Incorrect |prdata| during testcase #%d", testcase_num);
            else
                $info("Correct |prdata| during testcase #%d", testcase_num);
        end
    end

    reset_bus();

end
endtask 

// the first and second argument are useless now
// dataline_input take value directly from "data" signal
// if_sync input determine which line to monitor
// if_sync == 1 monitor tb_from_module_ff
// else mointor tb_to_module
task send_and_monitor;
    //send_and_monitor(data, tb_from_module_ff[index],1,3);
    // data will be sent to dataline signal;
    input logic [31:0] data_array;
    input logic monitored_dataline_fake; // the port to be checked
    input logic if_sync;
    input integer offset;
begin
    int i,j;
    logic monitored_value, monitored_value_2;

    fork
        // thread 1: sending data
        begin
            if(if_sync == 1)
                @(negedge tb_clk);

            for(i = 0; i < 32; i++)
            begin
                dataline_input = data[i];
                if(if_sync == 0)
                    tb_to_module_iopad[index] = dataline_input;
                else begin
                    tb_from_module[index * NUM_FUNC + offset] = dataline_input;
                    tb_output_enable[index * NUM_FUNC + offset] = dataline_input;
                end
                #(SIGNAL_P);
            end
        end

        // thread 2: monitoring data
        begin
            #(SIGNAL_P / 2 + 1);
            
            for(j = 0;j < 32; j++)
            begin
                // collect data
                if(if_sync == 1) begin
			        monitored_value = tb_from_module_ff[index];

                    monitored_value_2 = tb_output_en_ff[index];
                    monitored_data_2[j] = monitored_value_2;
                end
		        else begin
			        monitored_value = tb_to_module[index * NUM_FUNC + offset];
                end
		
		        monitored_data[j] = monitored_value;
                
                // verify data
                if(if_sync == 1) begin
                    if(monitored_data[j] != data_array[j])
                    begin
                        $error("Error: {if_sync == 1, from_module}Bits {%d} should be {%d} but it is {%d}",j,data_array[j],monitored_data[j]);
                        //j = 32;
                    end

                    if(monitored_data_2[j] != data_array[j]) 
                    begin
                        $error("Error: {if_sync == 1, enable_output}Bits {%d} should be {%d} but it is {%d}",j,data_array[j],monitored_data_2[j]);
                    end
                end
                else begin
                    if(monitored_data[j] != data_array[j])
                    begin
                        $error("Error: {Direction: if_sync == 0}Bits {%d} should be {%d} but it is {%d}",j,data_array[j],monitored_data[j]);
                        //j = 32;
                    end
                end
                
                #(SIGNAL_P);
            end
        end
    join

end
endtask

//*****************************************************************************
// DUT
//*****************************************************************************
/*
#(
    parameter NUM_PINS = 10; // max:32
    parameter NUM_FUNC = 4; // max:4
    parameter NUM_BITS = 2; // max:2
    parameter NUM_REGS = 1; // max:2
)
*/
top_level_digital_mux DUT
(
    .CLK(tb_clk),
    .RESETn(tb_n_rst),
    .PSEL(tb_psel),
    .PENABLE(tb_penable),
    .PWRITE(tb_pwrite),
    .PSLVERR(tb_pslverr),
    .PREADY(tb_pready),
    // input logic PWAKEUP,
    // input logic [2:0] PPROT,
    .PSTRB(tb_pstrb),
    .PADDR(tb_paddr),
    .PWDATA(tb_pwdata),
    .PRDATA(tb_prdata),

    .from_module(tb_from_module),       // from pepherial, input
    .output_enable(tb_output_enable),   // from pepherial,      input
    .to_module(tb_to_module),           // to perpherial,  output

    .to_module_iopad(tb_to_module_iopad), // to io pad,    input
    .from_module_ff(tb_from_module_ff),   // to io pad,    output
    .output_en_ff(tb_output_en_ff)        // to io pad,    output
);
defparam DUT.NUM_PINS = NUM_PINS;
defparam DUT.NUM_FUNC = NUM_FUNC;
defparam DUT.NUM_BITS = NUM_BITS;
defparam DUT.NUM_REGS = NUM_REGS;

//*****************************************************************************
// Test cases begin here
//*****************************************************************************
APB_TRANS transactions[];

initial begin    
    transactions = new[NUM_TRANS];

    transactions[0].PADDR = 32'h80050000;
    transactions[0].PDATA = 32'h00000000;
    transactions[0].PSTRB = 4'b1111;
    transactions[0].PWRITE = 1'b1;
    transactions[0].ex_pslverr = 1'b0;

    transactions[1].PADDR = 32'h80050000;
    transactions[1].PDATA = 32'h00000000;
    transactions[1].PSTRB = 4'b0;
    transactions[1].PWRITE = 1'b0;
    transactions[1].ex_pslverr = 1'b0;

    transactions[2].PADDR = 32'h80050000;
    transactions[2].PDATA = 32'h000FFFFF;
    transactions[2].PSTRB = 4'b1111;
    transactions[2].PWRITE = 1'b1;
    transactions[2].ex_pslverr = 1'b0;

    transactions[3].PADDR = 32'h80050000;
    transactions[3].PDATA = 32'h000FFFFF;
    transactions[3].PSTRB = 4'b0;
    transactions[3].PWRITE = 1'b0;
    transactions[3].ex_pslverr = 1'b0;

    transactions[4].PADDR = 32'h80050008;   // changed to 08 so when testing 2 regs, it's still an error
    transactions[4].PDATA = 32'h000FFFFF;
    transactions[4].PSTRB = 4'b1111;
    transactions[4].PWRITE = 1'b1;
    transactions[4].ex_pslverr = 1'b1;

    transactions[5].PADDR = 32'h80050000;
    transactions[5].PDATA = 32'h000FFFFF;
    transactions[5].PSTRB = 4'b1111;
    transactions[5].PWRITE = 1'b0;
    transactions[5].ex_pslverr = 1'b1;      // PSTRB is 1 when reading

    transactions[6].PADDR = 32'h80050000;
    transactions[6].PDATA = 32'hFFFFFFFF;
    transactions[6].PSTRB = 4'b0110;
    transactions[6].PWRITE = 1'b1;
    transactions[6].ex_pslverr = 1'b0;

    transactions[7].PADDR = 32'h80050000;
    transactions[7].PDATA = 32'h00FFFF00;
    transactions[7].PSTRB = 4'b0000;
    transactions[7].PWRITE = 1'b0;
    transactions[7].ex_pslverr = 1'b0;

    // testcases when NUM_PINS = 20
    // NUM_REG2 = 2

    // Test case 5
    // wrote into first register
    transactions[8].PADDR = 32'h80050000;
    transactions[8].PDATA = 32'h55555555;   // each fsel is set to 2'b01
    transactions[8].PSTRB = 4'b1111;
    transactions[8].PWRITE = 1'b1;
    transactions[8].ex_pslverr = 1'b0;

    // wrote into second register
    transactions[9].PADDR = 32'h80050004;
    transactions[9].PDATA = 32'h55555555;   // each fsel is set to 2'b01
    transactions[9].PSTRB = 4'b0001;
    transactions[9].PWRITE = 1'b1;
    transactions[9].ex_pslverr = 1'b0;

    // read
    transactions[10].PADDR = 32'h80050000;
    transactions[10].PDATA = 32'h55555555;
    transactions[10].PSTRB = 4'b0;
    transactions[10].PWRITE = 1'b0;
    transactions[10].ex_pslverr = 1'b0;

    transactions[11].PADDR = 32'h80050004;
    transactions[11].PDATA = 32'h00000055;
    transactions[11].PSTRB = 4'b0;
    transactions[11].PWRITE = 1'b0;
    transactions[11].ex_pslverr = 1'b0;

    // Test case 6
    // wrote into reg 1
    transactions[12].PADDR = 32'h80050000;
    transactions[12].PDATA = 32'haaaaaaaa;   // each fsel is set to 2'b10
    transactions[12].PSTRB = 4'b1111;
    transactions[12].PWRITE = 1'b1;
    transactions[12].ex_pslverr = 1'b0;

    // wrote into reg 2
    transactions[13].PADDR = 32'h80050004;
    transactions[13].PDATA = 32'haaaaaaaa;   // each fsel is set to 2'b10
    transactions[13].PSTRB = 4'b0001;
    transactions[13].PWRITE = 1'b1;
    transactions[13].ex_pslverr = 1'b0;

    // read 
    transactions[14].PADDR = 32'h80050000;
    transactions[14].PDATA = 32'haaaaaaaa;
    transactions[14].PSTRB = 4'b0;
    transactions[14].PWRITE = 1'b0;
    transactions[14].ex_pslverr = 1'b0;

    transactions[15].PADDR = 32'h80050004;
    transactions[15].PDATA = 32'h000000aa;
    transactions[15].PSTRB = 4'b0;
    transactions[15].PWRITE = 1'b0;
    transactions[15].ex_pslverr = 1'b0;



end


initial begin
    tb_n_rst = 1'b1;
    reset_bus();
    dataline_input = 0;
    monitored_data = '0;
    /*
    logic [NUM_PINS * NUM_FUNC - 1:0] tb_from_module;       //
    logic [NUM_PINS * NUM_FUNC - 1:0] tb_output_enable;
    logic [NUM_PINS * NUM_FUNC - 1:0] tb_to_module;
    logic tb_to_module_iopad;
    logic tb_from_module_ff;
    logic tb_output_en_ff;
    */
    #(0.1);

    if(NUM_REGS == 1) begin /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // begin of testcases when NUM_REGS == 1, NUM_PIN = 20

    //*****************************************************************************
    // Test cases 1; normal write/read
    //*****************************************************************************
    testcase_num = 1;
    reset_dut();

    execute_transactions(transactions[0]);
    execute_transactions(transactions[1]);

    // dataline_input to from module, monitor from_module_ff signal
    data = 32'haaaaaaaa;

    for(index = 0;index < NUM_PINS;index = index + 1) begin
        send_and_monitor(data, tb_from_module_ff[index],1,0);
        //#(SIGNAL_P);
    end

    data = 32'h8c37afb0;
    for(index = 0;index < NUM_PINS;index = index + 1) begin
        
        send_and_monitor(data, tb_to_module[index * NUM_FUNC],0,0);
        //#(SIGNAL_P);
    end

    #(SIGNAL_P);

    //*****************************************************************************
    // Test cases 2; normal write/read
    //*****************************************************************************
    testcase_num = 2;
    reset_dut();

    execute_transactions(transactions[2]);
    execute_transactions(transactions[3]);

    // dataline_input to from module, monitor from_module_ff signal
    data = 32'haaaaaaaa;

    for(index = 0;index < NUM_PINS;index = index + 1) begin
        
        send_and_monitor(data, tb_from_module_ff[index],1,1);
        //#(SIGNAL_P);
    end

    data = 32'h8c37afb0;
    for(index = 0;index < NUM_PINS;index = index + 1) begin
        
        send_and_monitor(data, tb_to_module[index * NUM_FUNC + 1],0,1);
        //#(SIGNAL_P);
    end

    //*****************************************************************************
    // Test cases 3; pslverr test
    //*****************************************************************************
    testcase_num = 3;
    reset_dut();

    execute_transactions(transactions[4]);
    execute_transactions(transactions[5]);

    //*****************************************************************************
    // Test cases 4; PSTRB test
    //*****************************************************************************
    testcase_num = 4;
    reset_dut();

    execute_transactions(transactions[6]);
    execute_transactions(transactions[7]);
    
    // end of testcases when NUM_REGS == 1
    end ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



    if(NUM_REGS == 2) begin /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // begin of testcases when NUM_REGS == 2

    //*****************************************************************************
    // Test cases 5; change parameters test fsel be set to 2'b01
    //*****************************************************************************
    testcase_num = 5;
    reset_dut();

    // write
    execute_transactions(transactions[8]);
    execute_transactions(transactions[9]);
    // read
    execute_transactions(transactions[10]);
    execute_transactions(transactions[11]);

    // dataline_input to from module, monitor from_module_ff signal
    data = 32'haaaaaaaa;

    for(index = 0;index < NUM_PINS;index = index + 1) begin
        
        send_and_monitor(data, tb_from_module_ff[index],1,1);
        //#(SIGNAL_P);
    end

    data = 32'h8c37afb0;
    for(index = 0;index < NUM_PINS;index = index + 1) begin
        
        send_and_monitor(data, tb_to_module[index * NUM_FUNC + 1],0,1);
        //#(SIGNAL_P);
    end

    //*****************************************************************************
    // Test cases 6; change parameters test fsel set to 2'b10
    //*****************************************************************************
    testcase_num = 6;
    reset_dut();

    // write
    execute_transactions(transactions[12]);
    execute_transactions(transactions[13]);
    // read
    execute_transactions(transactions[14]);
    execute_transactions(transactions[15]);

    // dataline_input to from module, monitor from_module_ff signal
    data = 32'haaaaaaaa;

    for(index = 0;index < NUM_PINS;index = index + 1) begin
        
        send_and_monitor(data, tb_from_module_ff[index],1,2);
        //#(SIGNAL_P);
    end

    data = 32'h8c37afb0;
    for(index = 0;index < NUM_PINS;index = index + 1) begin
        
        send_and_monitor(data, tb_to_module[index * NUM_FUNC + 2],0,2);
        //#(SIGNAL_P);
    end
    
    // end of testcases when NUM_REGS == 2
    end ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    $stop();



end

endmodule
