`ifndef APB_IF_VH
`define APB_IF_VH

interface apb_if();
   logic [31:0] PADDR;
   logic       PSEL;
   logic        PENABLE;
   logic        PWRITE;
   logic [31:0] PRDATA;
   logic [31:0] PWDATA;

  modport apb_s(      
      input  PADDR, PSEL, PENABLE, PWRITE, PWDATA,
      output  PRDATA);
endinterface: apb_if

`endif