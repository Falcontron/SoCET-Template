//------------------------------------
// Basic APB  Read/Write Transaction class definition
//  This transaction will be used by Sequences, Drivers and Monitors
//------------------------------------
`ifndef APB_RW_SV  
`define APB_RW_SV

import uvm_pkg::*;

//apb_rw sequence item derived from base uvm_sequence_item
class apb_rw extends uvm_sequence_item;
    //Register with factory for dynamic creation
    `uvm_object_utils(apb_rw)
   //typedef for READ/Write transaction type
   typedef enum {READ, WRITE, IDLE} kind_e;
   rand bit   [31:0] addr;      //Address
   rand logic [31:0] data;     //Data - For write or read response
   rand kind_e  apb_cmd;       //command type
 
/*
   constraint addr_con {addr % 4;}
   constraint word_align {addr[2:0] == '0;}
                     
   constraint range 
   {
     (data <= 1000) -> addr inside {[0:1000]};
     (data <= 2000 && data >1000) -> addr inside {[1000:10000]};
     (data > 2000) -> addr inside {[10000:100000]};
   }
   

   constraint categorize
   {
     (apb_cmd == READ) -> data inside {[100000:1000000]};
     (apb_cmd == WRITE) -> data inside {[0:100000]};
   }
*/

   function new (string name = "apb_rw");
      super.new(name);
   endfunction

   function string convert2string();
     return $psprintf("kind=%s addr=%0h data=%0h ",apb_cmd,addr,data);
   endfunction

endclass: apb_rw

`endif
