`ifndef READCONTROL_IF_VH
`define READCONTROL_IF_VH

interface readControl_if();
   //Registers
   logic [31:0] source_addr, dest_addr, control;

   //Counter Logic
   logic 	count_enable, clear_counter;
   logic [3:0]  rollover_val, count;
   
   //FIFO
   logic        wen, clear_fifo, full;

   //Memory Arbiter
   logic        r_hready;

   //Median Control Logic 
   logic        status;
   //AHB Signals, {dest, data}

   modport readControl (
     input source_addr, dest_addr, control, rollover_val, count, r_hready, full,
     output count_enable, clear_counter, clear_fifo, wen
   );

endinterface // READCONTROL_if

`endif //  `ifndef READCONTROL_IF_VH
