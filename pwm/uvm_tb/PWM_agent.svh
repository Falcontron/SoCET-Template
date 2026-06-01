import uvm_pkg::*;
`include "uvm_macros.svh"
`include "PWM_sequencer.svh"
`include "PWM_driver.svh"
`include "PWM_mon.svh"

class PWM_agent extends uvm_agent;
 
     //Analysis ports to connect the monitors to the scoreboard
     uvm_analysis_port#(PWM_transaction) agent_ap;
 
     PWM_sequencer        PWM_seqr;
     PWM_driver        PWM_drvr;
     PWM_monitor    PWM_mon;

     `uvm_component_utils_begin(PWM_agent)
	    `uvm_field_object(PWM_seqr, UVM_ALL_ON)
	    `uvm_field_object(PWM_drvr, UVM_ALL_ON)
	    `uvm_field_object(PWM_mon, UVM_ALL_ON)
     `uvm_component_utils_end

	 virtual PWM_if PWMif;
 
     function new(string name, uvm_component parent);
          super.new(name, parent);
     endfunction: new
 
     function void build_phase(uvm_phase phase);
          super.build_phase(phase);
 
          agent_ap    = new(.name("agent_ap"), .parent(this));
 
          PWM_seqr        = PWM_sequencer::type_id::create("seqr", this);
          PWM_drvr        = PWM_driver::type_id::create("drvr", this);
          PWM_mon   	  = PWM_monitor::type_id::create("mon" , this);

		  if (!uvm_config_db#(virtual PWM_if)::get(this, "", "PWM_vif", PWMif)) begin
			 `uvm_fatal("APB/DRV/NOVIF", "No virtual interface specified for this test instance")
		  end 
		  uvm_config_db#(virtual PWM_if)::set( this, "PWM_seqr", "PWM_vif", PWMif);
		  uvm_config_db#(virtual PWM_if)::set( this, "PWM_drvr", "PWM_vif", PWMif);
		  uvm_config_db#(virtual PWM_if)::set( this, "PWM_mon", "PWM_vif", PWMif);
     endfunction: build_phase
 
     function void connect_phase(uvm_phase phase);
          super.connect_phase(phase);
          PWM_drvr.seq_item_port.connect(PWM_seqr.seq_item_export);
          uvm_report_info("PWM_agent::", "connect_phase, Connected driver to sequencer");
          PWM_mon.PWM_ap.connect(agent_ap);
     endfunction: connect_phase

endclass: PWM_agent


	
