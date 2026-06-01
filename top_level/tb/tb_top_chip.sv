`timescale 1ns/10ps

module tb_top_chip;
  localparam int GPIO_PINS_PER_PORT = 8;
  localparam int BOOT_PINS = 3;
  localparam int PWM_CHANNELS = 2;
  localparam int IO_MUX_NUM_PINS = 32;
  localparam int NUM_CHIP = 2;
  localparam int ADDR_WIDTH = 18;
  localparam int DATA_WIDTH = 16;
  localparam int NREGS = 64 * 1024 / 4;

  supply1 VDD, VDDIO;
  supply0 VSS, VSSIO;

  logic pclk_pad_xi = 0;
  logic pclk_pad_xo;

  logic nRST_pad;

  logic uart_rx_pad;
  logic uart_tx_pad;

  wire [BOOT_PINS-1:0]  boot_pad;
  wire [IO_MUX_NUM_PINS-1:0] gpio_pad;
  wire [DATA_WIDTH-1:0] sram_data_pad;

  logic [NUM_CHIP-1:0]  sram_n_oe_pad;
  logic [NUM_CHIP-1:0]  sram_n_ce_pad;
  logic [NUM_CHIP-1:0]  sram_n_we_pad;
  logic [NUM_CHIP-1:0]  sram_n_lb_pad;
  logic [NUM_CHIP-1:0]  sram_n_ub_pad;
  logic [ADDR_WIDTH-1:0] sram_addr_pad;

  logic [IO_MUX_NUM_PINS-1:0] gpio_drive_en;
  logic [IO_MUX_NUM_PINS-1:0] gpio_drive_val;

  logic [BOOT_PINS-1:0]  boot_drive_en;
  logic [BOOT_PINS-1:0]  boot_drive_val;

  logic se_pad, te_pad;
  logic PLL_enable_pad;
  logic [3:0] PLL_ctrl_pad;

  logic SI0, SI1, SI2, SI3, SO0, SO1, SO2, SO3;
  // OCC Scan Signals
  logic pll_bypass, pll_reset;
  logic SI_OCC;
  logic SO_OCC; //out
  logic TESTMODE_OCC;
  logic TESTMODE_AUTOFIX;

  sram_sim #(
    .MEMCHIP("IS61WV25616BLL-10TL"),
    .ADDR_WIDTH(ADDR_WIDTH), // for the memory chip
    .DATA_WIDTH(DATA_WIDTH),
    .NREGS(NREGS),
    .ORDER(0)
  ) SRAM_chip_1 (
    .n_OE(sram_n_oe_pad[0]),
    .n_CE(sram_n_ce_pad[0]),
    .n_WE(sram_n_we_pad[0]),
    .n_LB(sram_n_lb_pad[0]),
    .n_UB(sram_n_ub_pad[0]),
    .addr(sram_addr_pad),
    .DOUT(sram_data_pad)
  );

  sram_sim #(
    .MEMCHIP("IS61WV25616BLL-10TL"),
    .ADDR_WIDTH(ADDR_WIDTH), // for the memory chip
    .DATA_WIDTH(DATA_WIDTH),
    .NREGS(NREGS),
    .ORDER(1)
  ) SRAM_chip_2 (
    .n_OE(sram_n_oe_pad[1]),
    .n_CE(sram_n_ce_pad[1]),
    .n_WE(sram_n_we_pad[1]),
    .n_LB(sram_n_lb_pad[1]),
    .n_UB(sram_n_ub_pad[1]),
    .addr(sram_addr_pad),
    .DOUT(sram_data_pad)
  );  

  // Drive ONLY when enabled, otherwise high-Z   
  genvar gi;
  generate
    for (gi = 0; gi < IO_MUX_NUM_PINS; gi++) begin : GEN_GPIO_Z
      assign gpio_pad[gi] = gpio_drive_en[gi] ? gpio_drive_val[gi] : 1'bz;
    end
  endgenerate

  genvar bi;
  generate
    for (bi = 0; bi < BOOT_PINS; bi++) begin : GEN_BOOT_DRV
      assign boot_pad[bi] = boot_drive_en[bi] ? boot_drive_val[bi] : 1'bz;
      pullup(boot_pad[bi]);
    end
  endgenerate

  // SRAM BUS FLOAT
  assign sram_data_pad = 'bz;

  top_chip dut (
    .pclk_pad_xi(pclk_pad_xi),
    .pclk_pad_xo(pclk_pad_xo),
    .tclk_pad_xi(tclk_pad_xi),
    .tclk_pad_xo(tclk_pad_xo),
    .nRST_pad  (nRST_pad),
    .uart_rx_pad(uart_rx_pad),
    .uart_tx_pad(uart_tx_pad),
    .boot_pad  (boot_pad),
    .gpio_pad  (gpio_pad),
    .sram_n_oe_pad(sram_n_oe_pad),
    .sram_n_ce_pad(sram_n_ce_pad),
    .sram_n_we_pad(sram_n_we_pad),
    .sram_n_lb_pad(sram_n_lb_pad),
    .sram_n_ub_pad(sram_n_ub_pad),
    .sram_addr_pad(sram_addr_pad),
    .sram_data_pad(sram_data_pad),

    .VDDIO(VDDIO),
    .VSSIO(VSSIO),
    .VDD(VDD),
    .VSS(VSS),
    .*
  );


  localparam int PCLK_PERIOD_NS = 80;
  
  always #(PCLK_PERIOD_NS/2) pclk_pad_xi++;

  task reset();
    nRST_pad = 0;
    repeat(2) @(negedge pclk_pad_xi);
    nRST_pad = 1;
    @(posedge pclk_pad_xi);
    #(1);
  endtask


  initial begin
    $fsdbDumpfile("waves.fsdb");
    $fsdbDumpvars(0,tb_top_chip);
    $fsdbDumpMDA(0, tb_top_chip);
  end

  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_top_chip);
  end
  
  integer cycles;
  localparam integer max_cycles = 10000;

  initial begin
    // init
    nRST_pad        = 1'b1;
    uart_rx_pad     = 1'b1;
    gpio_drive_en   = 'b0;
    gpio_drive_val  = 'b0;
    cycles = 0;

    PLL_enable_pad = '1;
    PLL_ctrl_pad = '1;

    boot_drive_en   = 3'b100;
    boot_drive_val  = '1;

    reset();
    
    while(cycles < max_cycles ) begin
      @(posedge pclk_pad_xi);
      cycles += 1;
    end

    $display("Ran for %0d cycles.\n", cycles);
      if(cycles == max_cycles) begin
          $display("Warning: Terminated due to number of cycles!");
      end
    $finish();

    $finish;
  end

endmodule
