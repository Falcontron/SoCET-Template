`include "ahb_if.vh"
`timescale 1ns / 10ps

module tb_dma_controller();

localparam CLK_PERIOD = 10;
localparam BUS_DELAY  = 800ps; // Based on FF propagation delay

// Sizing related constants
localparam DATA_WIDTH      = 1;
localparam ADDR_WIDTH      = 32;
localparam DATA_WIDTH_BITS = DATA_WIDTH * 8;
localparam DATA_MAX_BIT    = DATA_WIDTH_BITS - 1;
localparam ADDR_MAX_BIT    = ADDR_WIDTH - 1;

// Define our address mapping scheme via constants
localparam ADDR_STATUS      = 4'd0;
localparam ADDR_STATUS_BUSY = 4'd0;
localparam ADDR_STATUS_ERR  = 4'd1;
localparam ADDR_RESULT      = 4'd2;
localparam ADDR_SAMPLE      = 4'd4;
localparam ADDR_COEF_START  = 4'd6;  // F0
localparam ADDR_COEF_SET    = 4'd14; // Coeff Set Confirmation

localparam IDLE = 'b00;
localparam NON_SEQ = 'b10;
localparam SEQ = 'b11;

localparam SAR = 'h7FFF0004; //Source Address Register
localparam DAR = 'h7FFF0008; //Destination Address Register
localparam TSR = 'h7FFF000C; //Transfer Size Register
localparam CR = 'h7FFF0010; //Control Register

//*****************************************************************************
// General System signals
//*****************************************************************************
logic tb_clk;
logic tb_n_rst;

//*****************************************************************************
// AHB-Lite-Slave side signals
//*****************************************************************************
logic                  tb_hsel;
logic [1:0]            tb_htrans;
logic [ADDR_MAX_BIT:0] tb_haddr;
logic [2:0]            tb_hsize;
logic                  tb_hwrite;
logic [DATA_MAX_BIT:0] tb_hwdata;
logic [DATA_MAX_BIT:0] tb_hrdata;
logic                  tb_hready;
logic                  tb_hresp;
logic [31:0]           temp_word, temp_data;

logic tb_drq, tb_daq, tb_dma_interrupt;

ahb_if slave();
ahb_if master();



//*****************************************************************************
// Clock Generation Block
//*****************************************************************************
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

initial begin
    temp_data = '0;
end

always begin
    #(CLK_PERIOD);
    temp_data = temp_data + 1;
    master.HRDATA = temp_data;
end


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

task ahb_write;
    input logic [31:0] address;
    input logic [31:0] data;
begin
    // Provide Initial Data
    @(negedge tb_clk)
    slave.HSEL = '1;
    slave.HTRANS = NON_SEQ; //check this
    slave.HADDR = address;
    slave.HSIZE = '0;
    slave.HWRITE = '1;
    while(slave.HREADY == '0) begin
        @(posedge tb_clk);
        @(negedge tb_clk);
    end

    // Advance the clock
    @(posedge tb_clk);
    @(negedge tb_clk);

    slave.HWDATA = data;
    slave.HTRANS = IDLE;

    // Wait for the hready to go high to proceed
    @(posedge tb_clk);
    @(negedge tb_clk);
    while(slave.HREADY == '0) begin
        @(posedge tb_clk);
        @(negedge tb_clk);
    end
    slave.HSEL = '0;
    slave.HWDATA = '0;
    slave.HADDR = '0;
    slave.HWRITE = '0;
end
endtask

task ahb_read;
    input logic [ADDR_MAX_BIT:0] address;
    input logic [DATA_MAX_BIT:0] expected_data;
begin
    // Provide Initial Data
    @(negedge tb_clk)
    tb_hsel = '1;
    tb_htrans = NON_SEQ; //check this
    tb_haddr = address;
    tb_hsize = '0;
    tb_hwrite = '0;
    while(tb_hready == '0) begin
        @(posedge tb_clk);
        @(negedge tb_clk);
    end

    // Advance the clock
    @(posedge tb_clk);
    @(negedge tb_clk);

    tb_htrans = IDLE;

    // Wait for the hready to go high to proceed
    while(tb_hready == '0) begin
        assert(tb_hrdata == expected_data) begin
            $info("Correct: The tb_hrdata %x matches the expected value %x", tb_hrdata, expected_data); 
        end
        else begin
            $error("Incorrect: The tb_hrdata %x does NOT match the expected value %x", tb_hrdata, expected_data);
        end
        @(posedge tb_clk);
        @(negedge tb_clk);
    end
    tb_hsel = '0;
end
endtask

dma_controller DUT(tb_clk, tb_n_rst, tb_drq, tb_daq, 
    slave.HTRANS,
    slave.HWRITE,
    slave.HADDR,
    slave.HWDATA,
    slave.HSIZE,
    slave.HSEL,
    slave.HBURST,
    slave.HREADY,
    slave.HPROT,
    slave.HMASTLOCK,
    slave.HREADYOUT,
    slave.HRESP,
    slave.HRDATA,
    master.HREADY,
    master.HRESP,
    master.HRDATA,
    master.HTRANS,
    master.HWRITE,
    master.HADDR,
    master.HWDATA,
    master.HSIZE,
    master.HBURST,
    master.HPROT,
    master.HMASTLOCK,
    tb_dma_interrupt);

integer test_num;
string test_case;

initial begin
    @(posedge tb_clk);
	test_case = "Initialization";
	test_num = -1; 
    tb_drq = '0;
    slave.HTRANS = NON_SEQ;
    slave.HWRITE = '0;
    slave.HADDR = '0;
    slave.HWDATA = '0;
    slave.HSIZE = '0;
    slave.HSEL = '0;
    slave.HBURST = '0;
    master.HREADY = '1;
    master.HRESP = '0;
    master.HRDATA = '0;

    @(posedge tb_clk);
    test_case = "Power on Reset";
    test_num++;

    reset_dut();
    @(posedge tb_clk)
    ahb_write(SAR, 32'haaaaaaaa);
    ahb_write(DAR, 32'hbbbbbbbb);
    ahb_write(TSR, 32'd1);
    temp_word = {18'd0, 1'b1, 1'b1, 1'b1, 1'b1, 9'd0, 1'b0};
    ahb_write(CR, temp_word);
    temp_word = {18'd0, 1'b0, 1'b1, 1'b1, 1'b0, 9'd0, 1'b1};
    ahb_write(CR, temp_word);

    test_case = "DMA Now Enabled";
    master.HREADY = '1;
    master.HRESP = '0;
    master.HRDATA = 32'h5678;


    @(posedge tb_clk);
    @(posedge tb_clk);
    @(posedge tb_clk);
    @(posedge tb_clk);
    @(posedge tb_clk);
    @(posedge tb_clk);
    @(posedge tb_clk);
    @(posedge tb_clk);
    @(posedge tb_clk);

    reset_dut();
    @(posedge tb_clk)
    ahb_write(SAR, 32'haaaaaaaa);
    ahb_write(DAR, 32'hbbbbbbbb);
    ahb_write(TSR, 32'd4);
    temp_word = {18'd0, 1'b1, 1'b1, 1'b1, 1'b1, 9'd0, 1'b0};
    ahb_write(CR, temp_word);
    temp_word = {18'd0, 1'b0, 1'b1, 1'b1, 1'b0, 9'd0, 1'b1};
    ahb_write(CR, temp_word);

    test_case = "DMA Now Enabled";
    master.HREADY = '1;
    master.HRESP = '0;
    test_case = "Ending";




end







endmodule
