import uvm_pkg::*;
`include "uvm_macros.svh"
`include "PWM_env.svh"

class PWM_test extends uvm_test;

	`uvm_component_utils(PWM_test)
	
	PWM_env env;
    	virtual apb_if vif;
	virtual PWM_if PWMif;

	function new( string name = "PWM_test", uvm_component parent);
		super.new(name,parent);
	endfunction: new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = PWM_env::type_id::create("env",this);

		//----------------------send interface down for apb---------------------------
		if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
		   `uvm_fatal("APB/DRV/NOVIF", "No virtual interface specified for this test instance")
		end 

		uvm_config_db#(virtual apb_if)::set( this, "env.agt*", "vif", vif);

		//----------------------send interface down for PWM---------------------------
		if (!uvm_config_db#(virtual PWM_if)::get(this, "", "PWM_vif", PWMif)) begin
		   `uvm_fatal("APB/DRV/NOVIF", "No virtual interface specified for this test instance")
		end 

		uvm_config_db#(virtual PWM_if)::set( this, "env.PWM_agnt", "PWM_vif", PWMif);

	endfunction: build_phase

	task run_phase(uvm_phase phase);
		//apb_base_seq apb_seq;
		PWM_sequence PWM_seq;

		apb_demo_seq apb_seq;

		//apb_seq = apb_base_seq::type_id::create("apb_seq");
		apb_seq = apb_demo_seq::type_id::create("apb_seq");
		PWM_seq = PWM_sequence::type_id::create("PWM_seq");

		phase.raise_objection( this, "Starting apb_base_seq in main phase" );
		$display("%t Starting sequence apb_seq run_phase",$time);
 		fork
		apb_seq.start(env.agt.sqr);
		PWM_seq.start(env.PWM_agnt.PWM_seqr);
		join
		#100ns;
		phase.drop_objection( this , "Finished apb_seq in main phase" );
	endtask

	//ignoring reset and main phase

endclass: PWM_test
