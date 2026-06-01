import uvm_pkg::*;
`include "uvm_macros.svh"
`include "bus_agent.svh"
`include "bus_if.svh"
`include "bus_transaction.svh"
`include "pwm_agent.svh"
`include "pwm_scoreboard.svh"
`include "pwm_if.svh"
`include "pwm_transaction.svh"

class environment_base extends uvm_env;
    `uvm_component_utils(environment_base)
    bus_agent bus_agt;
    pwm_agent pwm_agt;
    scoreboard scrb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        bus_agt = bus_agent::type_id::create("bus_agt", this);
        pwm_agt = pwm_agent::type_id::create("pwm_agt", this);
        uvm_config_db#(int)::set(pwm_agt, "mon.*", "channel_num", 0);
        scrb = scoreboard::type_id::create("scoreboard0", this);
        uvm_config_db#(int)::set(scrb, "", "channel_num", 0);
    endfunction

    function void connect_phase(uvm_phase phase);
        pwm_agt.mon.pwm_ap.connect(scrb.pwm_export);
    endfunction
endclass : environment_base
class environment extends environment_base;
	`uvm_component_utils(environment)


	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
	endfunction
endclass : environment
