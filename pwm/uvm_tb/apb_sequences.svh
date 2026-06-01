//A few flavours of apb sequences

`ifndef APB_SEQUENCES_SV
`define APB_SEQUENCES_SV   


`include "apb_if.svh"
`include "apb_rw.svh"
`include "apb_driver_seq_mon.svh"
//------------------------
//Base APB sequence derived from uvm_sequence and parameterized with sequence item of type apb_rw
//------------------------
class apb_base_seq extends uvm_sequence#(apb_rw);

  `uvm_object_utils(apb_base_seq)

  function new(string name ="");
    super.new(name);
  endfunction
  
  task body();
  endtask
  
  task APB_send;	
	input logic[31:0] addr;
	input logic[31:0] data;
	input bit [1:0]	  write;
	begin
	  apb_rw rw_trans;
	  rw_trans = apb_rw::type_id::create(.name("rw_trans"),.contxt(get_full_name()));
          start_item(rw_trans);
          rw_trans.addr = addr;
          rw_trans.data = data;
	  $cast(rw_trans.apb_cmd , write);
          finish_item(rw_trans);
	end
  endtask

endclass

class pwm_config_seq extends apb_base_seq;
	`uvm_object_utils(pwm_config_seq)
	
	function new(string name = "pwm_config_seq");
		super.new(name);
	endfunction

	randc bit [31:0] period;
	randc bit [31:0] duty;
	randc bit [31:0] control;
	randc bit [2:0] channel;	

	constraint period_values {period inside {[0:1000]};}	
	constraint duty_values {duty % 4 == 0;}
	constraint control_values {control inside {32'b00, 32'b01,32'b10,32'b011, 32'b100,32'b101, 32'b110,32'b111};}
	constraint channel_constrainer {channel inside {[0:NUM_CHANNELS]};};

	task body();
		APB_send(((channel * 3) + PERIOD_IND) * 4, period, 1);
		APB_send(((channel * 3) + DUTY_IND) * 4, duty, 1);
		APB_send(((channel * 3) + CONTROL_IND) * 4, control, 1);
	endtask
endclass


class check_interupt_seq extends apb_base_seq;

  `uvm_object_utils(check_interupt_seq)

   function new(string name ="check_interupt_seq");
     super.new(name);
   endfunction
   task body();
	APB_send(32'h14,32'h0,0);
	APB_send(32'h0,32'hFe100000,1); 
	//Wait 100clk then check interrupt
	APB_send(32'h0,100,2);
	APB_send(32'h14,32'h0,0);
	//Wait 75clk then check interrupt
	APB_send(32'h0,75,2);
	APB_send(32'h14,32'h0,0);
   endtask
endclass


class data_load_seq extends apb_base_seq;
  `uvm_object_utils(data_load_seq)

  function new(string name ="data_load_seq");
    super.new(name);
  endfunction
	
  rand logic [31:0] my_data;
  
  task body();	
	APB_send(32'hc,my_data,1);	

  endtask
endclass


class apb_demo_seq extends apb_base_seq;

  `uvm_object_utils(apb_demo_seq)

  function new(string name ="apb_demo_seq");
    super.new(name);
  endfunction
  
  data_load_seq load_seq;
  spi_config_seq config_seq;
  check_interupt_seq check_seq;

  task body();
	//slave mode
	APB_send(32'h0,32'h9e400000,1);
	APB_send(32'h4,32'h4,1);
	APB_send(32'h8,32'h3,1);
    	APB_send(32'h14,32'h0,0);
	APB_send(32'h0,32'hca400000,1);
	//Wait 200clk then check interrupt
	APB_send(32'h0,200,2);
	APB_send(32'h14,32'h0,0);
	//Wait 75clk then check interrupt
	APB_send(32'h0,75,2);
	APB_send(32'h14,32'h0,0);
	//Read Output
	APB_send(32'h10,32'h0,0);

	repeat(8) begin
		assert(config_seq.randomize());
		`uvm_do(config_seq)
		assert(load_seq.randomize());
		`uvm_do(load_seq)
		`uvm_do(check_seq)
	end
  endtask

endclass
`endif
