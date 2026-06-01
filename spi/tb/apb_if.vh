`ifndef APB_IF_SV
`define APB_IF_SV

interface apb_if(input bit pclk);
   wire [31:0] PADDR;
   wire        PSEL;
   wire        PENABLE;
   wire        PWRITE;
   wire [31:0] PRDATA;
   wire [31:0] PWDATA;


   //Master Clocking block - used for Drivers
   clocking master_cb @(posedge pclk);
      output PADDR, PSEL, PENABLE, PWRITE, PWDATA;
      input  PRDATA;
   endclocking: master_cb

   //Slave Clocking Block - used for any Slave BFMs
   clocking slave_cb @(posedge pclk);
      input  PADDR, PSEL, PENABLE, PWRITE, PWDATA;
      output  PRDATA;
   endclocking: slave_cb

   //Monitor Clocking block - For sampling by monitor components
   clocking monitor_cb @(posedge pclk);
      input PADDR, PSEL, PENABLE, PWRITE, PRDATA, PWDATA;
   endclocking: monitor_cb

  modport master(clocking master_cb);
  modport slave(clocking slave_cb);
  modport passive(clocking monitor_cb);
  modport apb_s(      
      input  PADDR, PSEL, PENABLE, PWRITE, PWDATA,
      output  PRDATA);
endinterface: apb_if

`endif