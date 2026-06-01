import uvm_pkg::*;
`include "uvm_macros.svh"

string test_case;
//---------------------------------------------------------------------------------------------------------
class PWM_transaction extends uvm_sequence_item;

	`uvm_object_utils(PWM_transaction)	
    
	rand bit [31:0] control;
	rand bit [31:0] duty;
	rand bit [31:0] period;
	bit PENABLE, PWRITE, PSEL;
	bit [31:0] PADDR, PWDATA;
	bit n_rst;
	 //PWM_predictor sends it to the comparator which will then choose the correct bits to compare based on this config
	 //PWM_mon will take all 4 combination to send to the PWM_comparator

 
     function new(string name = "PWM_transaction");
          super.new(name);
     endfunction: new
 

	//Utility and Field macros,
	`uvm_object_utils_begin(PWM_transaction)
		`uvm_field_int(PADDR,UVM_ALL_ON)
		`uvm_field_int(PWDATA,UVM_ALL_ON)
		`uvm_field_int(PWRITE,UVM_ALL_ON)
		`uvm_field_int(PSEL,UVM_ALL_ON)
		`uvm_field_int(PENABLE,UVM_ALL_ON)
		`uvm_field_int(data,UVM_ALL_ON)
	`uvm_object_utils_end
     //`uvm_object_utils_begin(PWM_transaction)
     //`uvm_field_int(read_data, UVM_ALL_ON)
     //`uvm_field_int(Enable, UVM_ALL_ON)
     //`uvm_object_utils_end


	function string convert2string();
		return $psprintf("PADDR = %h, PWDATA= %h, PSEL= %h, PENABLE= %h,data= %h, data_risingedge= %h, data_fallingedge= %h", PADDR , PWDATA,  PSEL, PENABLE, data, data_risingedge, data_fallingedge);
	endfunction

	  constraint duty_c duty inside {
    	    32'h1, 32'h4, 32'h8, 32'ha
  	  };

	  constraint period_c period inside {
	    32'h10, 32'h10, 32'h10, 32'h10
	  };

	  constraint control_c control inside {
	    32'b0001, 32'b0011, 32'b0101, 32'b0111
	  };


endclass: PWM_transaction
	


//------------------------------------------------------------------------------------------------------------

class PWM_sequence extends uvm_sequence #(PWM_transaction);
     `uvm_object_utils(PWM_sequence)
 
     function new(string name = "");
          super.new(name);
     endfunction: new
 
     task body();
	  localparam DELAY = 1;
	  localparam PERIOD = 20;
	  localparam ADDRESS = 32'h80000000;
	  localparam BYTES_PER_WORD = 4;
	  localparam NUM_REGS = 28;

	  localparam NUM_CHANNELS = 4;
	  localparam NUM_REG_PER_CHAN = 3;
	  localparam PERIOD_IND = 0;
	  localparam DUTY_IND = 1;
	  localparam COUNT_IND = 2;
	integer i;
      //for Slave
	test_case = "PWM";
		

	PWM_transaction req_item;
    	req_item = PWM_transaction::type_id::create("req_item");
    	start_item(req_item);
	assert(req_item.randomize());
	n_rst = 1'b0;
	req_item.PADDR = 0;
	req_item.PENABLE = 0;
	req_item.PWRITE = 0;
	req_item.PSEL = 0;
	req_item.PWDATA = 0;
	    
    //begin testing
    
	    @(negedge clk);
	    n_rst = 1'b1;
	for(i = 0; i < NUM_CHANNELS; i ++) begin
	      $info("Writing to PeriodAddr %h DutyAddr %h ControlAddr %h", 
		((i * 3) + PERIOD_IND * 4), 
		((i * 3) + DUTY_IND * 4), 
		((i * 3) + COUNT_IND * 4));

	      //write period
	      @(posedge clk);
	      //address phase
	      req_item.PADDR = ((i * 3) + PERIOD_IND) * 4;
	      req_item.PWDATA = req_item.period[i];
	      req_item.PSEL = 1;
	      req_item.PWRITE = 1;
	      req_item.PENABLE = 0;
	      @(posedge clk);
	      //data phase
	      req_item.PENABLE = 1;
	      #(DELAY);

	      //write duty
	       @(posedge clk);
	      req_item.req_item.//address phase
	      req_item.PADDR = ((i * 3) + DUTY_IND) * 4;
	      req_item.PWDATA = req_item.duty[i];
	      req_item.PSEL = 1;
	      req_item.PWRITE = 1;
	      req_item.PENABLE = 0;
	      @(posedge clk);
	      //data phase
	      req_item.PENABLE = 1;
	      #(DELAY);

	      //write control
	       @(posedge clk);
	      //address phase
	      req_item.PADDR = ((i * 3) + COUNT_IND) * 4;
	      req_item.PWDATA = req_item.control[i];
	      req_item.PSEL = 1;
	      req_item.PWRITE = 1;
	      req_item.PENABLE = 0;
	      @(posedge clk);
	      //data phase
	      req_item.PENABLE = 1;
	      #(DELAY);
	end
	finish_item(req_item);
endtask: body


//----------------------------------------------------------------------------------------------------------------------------------------------


//---------------------------------------------------------------------------------------------------------
class PWM_sequencer extends uvm_sequencer#(PWM_transaction);

   `uvm_component_utils(PWM_sequencer)
 
   function new(input string name= "PWM_sequencer", uvm_component parent=null);
      super.new(name, parent);
   endfunction : new

endclass : PWM_sequencer
