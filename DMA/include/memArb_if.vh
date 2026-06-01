`ifndef MEMARB_IF_VH
`define MEMARB_IF_VH

interface memArb_if(
  input CLK
);
  //inputs from control
  logic [2:0] r_hsize;
  logic r_hsel;
  logic [31:0] r_haddr;

  //Inputs from write_control_unit
  logic [2:0] w_hsize;
  logic w_hwrite;     
  logic w_hsel;
  logic [31:0] w_haddr;
  logic [31:0] w_hwdata;

  //outputs to controllers
  logic w_hready;
  logic r_hready;       
  logic [31:0] hrdata;   
  logic error;


   modport arb (
     input r_hsize, r_hsel, r_haddr, w_hsize, w_hwrite, w_hsel, w_haddr, w_hwdata,
     output w_hready, r_hready, hrdata, error
   );  

endinterface 

`endif //  `ifndef MEMARB_IF_VH