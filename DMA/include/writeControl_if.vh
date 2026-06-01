`ifndef WRITECONTROL_IF_VH
`define WRITECONTROL_IF_VH

interface writeControl_if();
  parameter  DATA_W = 12;
  parameter  ADDRESS_W = 32;
   //FIFO
   logic 	    empty;
   logic        wen, ren, clear_fifo;
   //Memory Arbiter
   logic        w_hready;
   //Median Control Logic 
   logic        status;

   logic [DATA_W + ADDRESS_W - 1: 0] data_frm;

   //AHB Signals, {dest, data}

   modport writeControl (
     input empty, w_hready,
     output clear_fifo, ren, data_frm
   );

endinterface // WRITECONTROL_if

`endif //  `ifndef WRITECONTROL_IF_VH