import uvm_pkg::*;
`include "uvm_macros.svh"

`include "PWM_if.vh"

class PWM_driver extends uvm_driver#(PWM_transaction);
	 `uvm_component_utils(PWM_driver)

	 //Interface declaration
	 protected virtual PWM_if PWMif;

	 function new(string name, uvm_component parent);
		  super.new(name, parent);
	 endfunction: new

	 function void build_phase(uvm_phase phase);
	   	super.build_phase(phase);
	 	if( !uvm_config_db#(virtual PWM_if)::get(this, "", "PWM_vif", PWMif) ) begin
			 `uvm_fatal("APB/DRV/NOVIF", "No virtual interface specified for this test instance");
		end
	 endfunction: build_phase

	 task run_phase(uvm_phase phase);
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
		PWM_transaction req_item;

     	forever begin 

			seq_item_port.get_next_item(req_item);
			@(negedge n_rst);
			@(this.PWMif.PWM_cb);
			PWMif.PADDR <= req_item.PADDR;
			PWMif.PSEL <= req_item.PSEL;
			PWMif.PENABLE <= req_item.PENABLE;
			PWMif.PWDATA <= req_item.PWDATA;
			PWMif.PWRITE <= req_item.PWRITE;
			for(i = 0; i < NUM_CHANNELS; i ++) begin

			      //write period
			      @(this.PWMif.PWM_cb);
			      //address phase
			        PWMif.PADDR <= req_item.PADDR;
				PWMif.PSEL <= req_item.PSEL;
				PWMif.PENABLE <= req_item.PENABLE;
				PWMif.PWDATA <= req_item.PWDATA;
				PWMif.PWRITE <= req_item.PWRITE;
			      @(this.PWMif.PWM_cb);
			      //data phase
			      PWMif.PENABLE = 1;
			      #(DELAY);

			      //write duty
			       @(this.PWMif.PWM_cb);
			        PWMif.PADDR <= req_item.PADDR;
				PWMif.PSEL <= req_item.PSEL;
				PWMif.PENABLE <= req_item.PENABLE;
				PWMif.PWDATA <= req_item.PWDATA;
				PWMif.PWRITE <= req_item.PWRITE;
			      @(this.PWMif.PWM_cb);
			      //data phase
			      PWMif.PENABLE = 1;
			      #(DELAY);

			      //write control
			       @(this.PWMif.PWM_cb);
			      //address phase
			        PWMif.PADDR <= req_item.PADDR;
				PWMif.PSEL <= req_item.PSEL;
				PWMif.PENABLE <= req_item.PENABLE;
				PWMif.PWDATA <= req_item.PWDATA;
				PWMif.PWRITE <= req_item.PWRITE;
			      @(this.PWMif.PWM_cb);
			      //data phase
			      PWMif.PENABLE = 1;
			      #(DELAY);

			@(this.PWMif.PWM_cb);
			      PWMif.PENABLE = 0;
			      #(DELAY);
                          #(PERIOD * 16 * 4);

			rsp.set_id_info(req_item);
			seq_item_port.item_done();
		end

   	endtask: run_phase
endclass: PWM_driver
