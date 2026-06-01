`timescale 1ns / 10ps

module tb_fifo();

localparam CLK_PERIOD = 10;
localparam DATA_SIZE = 40;
integer tb_test_num;
string  tb_test_case;

//input tb signals
logic tb_clk;
logic tb_n_rst;
logic [(DATA_SIZE-1):0] tb_datain;
logic tb_wn;
logic tb_rn;
logic tb_clear;
//output tb signals
logic [(DATA_SIZE-1):0] tb_dataout;
logic tb_full;
logic tb_empty;

//TB Test Signals
logic [(DATA_SIZE-1):0] tb_test_data;
logic [(DATA_SIZE-1):0] tb_out_data;
logic [(DATA_SIZE-1):0] tb_test_arr [7:0];

logic [3:0] v;
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

// Clock generation block
always begin
  // Start with clock low to avoid false rising edge events at t=0
  tb_clk = 1'b0;
  // Wait half of the clock period before toggling clock value (maintain 50% duty cycle)
  #(CLK_PERIOD/2.0);
  tb_clk = 1'b1;
  // Wait half of the clock period before toggling clock value via rerunning the block (maintain 50% duty cycle)
  #(CLK_PERIOD/2.0);
end

task fifo_write;
    input logic [(DATA_SIZE-1):0] datain;
begin
    @(negedge tb_clk)
    tb_datain = datain;
    tb_wn = 1'b1;
    @(negedge tb_clk)
    tb_wn = 1'b0;
    @(negedge tb_clk)
    @(posedge tb_clk);
end
endtask

task fifo_read;
    output logic [(DATA_SIZE-1):0] dataout;
begin
    @(negedge tb_clk)
    tb_rn = 1'b1;
    dataout = tb_dataout;
    @(negedge tb_clk)
    tb_rn = 1'b0;
    @(negedge tb_clk)
    @(posedge tb_clk);
end
endtask
fifo_new DUT
(
    .clock(tb_clk),
    .n_rst(tb_n_rst),
    .DATAIN(tb_datain),
    .DATAOUT(tb_dataout),
    .wn(tb_wn),
    .rn(tb_rn),
    .clear(tb_clear),
    .full(tb_full),
    .empty(tb_empty)
);

initial begin
    tb_test_data = 40'h0;
    tb_out_data = 40'h0;
    tb_n_rst            = 1'b1; 
    tb_test_num         = 0;    
    tb_test_case        = "Test bench initializaton";
    $info("Test case %x, %x", tb_test_num, tb_test_case);
    @(negedge tb_clk)

    reset_dut();
    tb_test_num  = tb_test_num + 1;
    tb_test_case = "Fifo write";
    $info("Test case %x, %x", tb_test_num, tb_test_case);
    tb_test_data = 'h12B00BBAAD;
    fifo_write(tb_test_data);
    @(negedge tb_clk);

    tb_test_num  = tb_test_num + 1;
    tb_test_case = "Fifo read";
    $info("Test case %x, %x", tb_test_num, tb_test_case);
    
    fifo_read(tb_out_data);
    @(negedge tb_clk);

    tb_test_num  = tb_test_num + 1;
    tb_test_case = "Cont. Writes";
    $info("Test case %x, %x", tb_test_num, tb_test_case);
    @(negedge tb_clk)
    tb_test_arr[0] = 'hBAAADF00D1;
    tb_datain = tb_test_arr[0];
    tb_wn = 1'b1;
    @(negedge tb_clk)
    tb_test_arr[1] = 'hBAAADF00D2;
    tb_datain = tb_test_arr[1];
    @(negedge tb_clk)
    tb_test_arr[2] = 'hBAAADF0033;
    tb_datain = tb_test_arr[2];
    @(negedge tb_clk)
    tb_wn = 1'b0;
    @(negedge tb_clk);

    tb_test_num  = tb_test_num + 1;
    tb_test_case = "Cont. Reads";
    $info("Test case %x, %x", tb_test_num, tb_test_case);
    @(negedge tb_clk);
    v = '0;
    while(tb_empty == 'b0) begin
        tb_rn = 1'b1;
        tb_out_data = tb_dataout;
        @(negedge tb_clk);
        assert(tb_out_data == tb_test_arr[v]) begin
            $info("correct output");
        end
        else begin
            $error("incorrect output %x vs %x",tb_out_data, tb_test_arr[v]);
        end
        v++;
    end
    tb_rn = 1'b0;
    @(negedge tb_clk);

    
    tb_test_num  = tb_test_num + 1;
    tb_test_case = "Fill it up";
    $info("Test case %x, %x", tb_test_num, tb_test_case);
    tb_test_data = 'hFFFFFFFFF0;
    while (tb_full != 'b1) begin
        tb_wn = 1'b1;
        tb_datain = tb_test_data;
        @(negedge tb_clk);
        tb_test_data++;
    end
    tb_wn = 1'b0;
    @(negedge tb_clk);
    reset_dut();
    //Write Prioritize over read so this resulted a 1 cycle delay for read ptr increment
    tb_test_num  = tb_test_num + 1;
    tb_test_case = "Read and Write";
    $info("Test case %x, %x", tb_test_num, tb_test_case);
    tb_test_data = 'hFFFFFFFFF0;
    tb_wn = 1'b1;
    tb_datain = tb_test_data;
    @(negedge tb_clk);
    tb_test_data = 'hFFFFFFFFF1;
    tb_datain = tb_test_data;
    tb_rn = 1'b1;
    tb_out_data = tb_dataout;
    @(negedge tb_clk);
    tb_test_data = 'hFFFFFFFFF2;
    tb_datain = tb_test_data;
    tb_out_data = tb_dataout; 
    @(negedge tb_clk);
    tb_wn = 1'b0;
    tb_rn = 1'b0;

    @(negedge tb_clk);
    tb_test_num  = tb_test_num + 1;
    tb_test_case = "Clear";
    $info("Test case %x, %x", tb_test_num, tb_test_case);
    @(negedge tb_clk);
    tb_clear = 1'b1;
    @(negedge tb_clk);
    tb_clear = 1'b0;
    @(negedge tb_clk);
    @(negedge tb_clk);


end
endmodule