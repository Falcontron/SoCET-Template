import uvm_pkg::*;
`include "uvm_macros.svh"
`include "PWM_agent.svh"
`include "PWM_predictor.svh"
`include "PWM_comparator.svh"
`include "PWM_if.vh"

`include "apb_sequences.svh"
`include "apb_driver_seq_mon.svh"
`include "apb_if.svh"
`include "apb_rw.svh"

//apb_agent
class apb_agent extends uvm_agent;

   //Agent will have the sequencer, driver and monitor components for the APB interface
   apb_sequencer sqr;
   apb_master_drv drv;
   apb_monitor mon;

   virtual apb_if  vif;

   `uvm_component_utils_begin(apb_agent)
   `uvm_field_object(sqr, UVM_ALL_ON)
   `uvm_field_object(drv, UVM_ALL_ON)
   `uvm_field_object(mon, UVM_ALL_ON)
   `uvm_component_utils_end
   
   function new(string name, uvm_component parent = null);
      super.new(name, parent);
   endfunction

   //Build phase of agent - construct sequencer, driver and monitor
   //get handle to virtual interface from env (parent) config_db
   //and pass handle down to srq/driver/monitor
   virtual function void build_phase(uvm_phase phase);
      sqr = apb_sequencer::type_id::create("sqr", this);
      drv = apb_master_drv::type_id::create("drv", this);
      mon = apb_monitor::type_id::create("mon", this);
      
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
         `uvm_fatal("APB/AGT/NOVIF", "No virtual interface specified for this agent instance")
      end

     uvm_config_db#(virtual apb_if)::set( this, "sqr", "vif", vif);
     uvm_config_db#(virtual apb_if)::set( this, "drv", "vif", vif);
     uvm_config_db#(virtual apb_if)::set( this, "mon", "vif", vif);
   endfunction: build_phase

   //Connect - driver and sequencer port to export
   virtual function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
      uvm_report_info("apb_agent::", "connect_phase, Connected driver to sequencer");
   endfunction
endclass: apb_agent


//----Env----
class PWM_env extends uvm_env;

`uvm_component_utils(PWM_env)

	PWM_agent PWM_agnt;
	apb_agent agt;

	PWM_monitor PWM_mon;
	
	virtual apb_if  vif;
	virtual PWM_if PWMif;

	function new(string name = "PWM_env", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	function void build_phase( uvm_phase phase);
		//reg model build phase (not in standard UVM ?)
		//PWM_regs = reg_env::type_id::create ("PWM_regs", this);

		//APB build phase
		agt = apb_agent::type_id::create("agt", this);
		//PWM_build phase
		PWM_agnt = PWM_agent::type_id::create("PWM_agnt",this);

		//predictor
		PWM_pred = PWM_predictor::type_id::create("PWM_pred", this);

		//comparator
		PWM_comp = PWM_comparator::type_id::create("PWM_comp", this);

		//----------------------send interface down for apb---------------------------
		if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
			`uvm_fatal("APB/AGT/NOVIF", "No virtual interface specified for this env instance")
		end
		$display("FOUND first interface");
		uvm_config_db#(virtual apb_if)::set( this, "agt", "vif", vif);

		//----------------------send interface down for PWM---------------------------
		if (!uvm_config_db#(virtual PWM_if)::get(this, "", "PWM_vif", PWMif)) begin
			 `uvm_fatal("APB/DRV/NOVIF", "No virtual interface specified for this test instance")
		end 
		uvm_config_db#(virtual PWM_if)::set( this, "PWM_agnt", "PWM_vif", PWMif);



		//send interface to predictor
		//uvm_config_db#(virtual apb_if)::set( this, "PWM_pred", "apb_if", vif);
		//uvm_config_db#(virtual PWM_if)::set( this, "PWM_pred", "PWM_if", PWMif);

	endfunction: build_phase

	function void connect_phase( uvm_phase phase);
		
		//agt.mon.ap.connect(PWM_regs.m_apb2reg_predictor.bus_in);
		//PWM_regs.m_ral_model.default_map.set_sequencer(agt.sqr, PWM_regs.m_reg2apb);		

		agt.mon.ap.connect(PWM_pred.analysis_export);
		PWM_pred.PWM_ap_pred.connect(PWM_comp.before_export);
		PWM_agnt.PWM_mon.PWM_ap.connect(PWM_comp.after_export);
		
	endfunction: connect_phase

endclass: PWM_env




