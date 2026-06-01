import uvm_pkg::*;
`include "uvm_macros.svh"

`include "PWM_if.vh"
`include "apb_if.svh"

`include "apb_rw.svh"

class PWM_comparator extends uvm_scoreboard;

	`uvm_component_utils(PWM_comparator)

	uvm_analysis_export #(PWM_transaction) before_export;
    uvm_analysis_export #(PWM_transaction) after_export;

	uvm_tlm_analysis_fifo #(PWM_transaction) before_fifo, after_fifo;

 	int m_matches, m_mismatches;

	
	function new( string name , uvm_component parent) ;
		super.new( name , parent );
	  	m_matches = 0;
	  	m_mismatches = 0;
 	endfunction

 	function void build_phase( uvm_phase phase );
	   	before_fifo = new("before_fifo", this);
	   	after_fifo = new("after_fifo", this);
	   	before_export = new("before_export", this);
	   	after_export = new("after_export", this);
	endfunction

 	function void connect_phase( uvm_phase phase );
   		before_export.connect(before_fifo.analysis_export);
  		after_export.connect(after_fifo.analysis_export);
 	endfunction
	
 	task run_phase( uvm_phase phase );
   		string s;
   		PWM_transaction before_PWM, after_PWM;
   		forever begin
	 		before_fifo.get(before_PWM);
			
			//Receiving 32 bit of data
			for (int i = 0; i <64 ; i+=1) begin
	 			after_fifo.get(after_PWM);
			end

 			
			uvm_report_info("PWM Comparator", $psprintf("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\nExpected Data: %h, Received Data: Rising= %h Falling= %h, CPOL: %h, CPHA: %h\n ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",before_PWM.data, after_PWM.data_risingedge, after_PWM.data_fallingedge, before_PWM.PWM_CPOL,before_PWM.PWM_CPHA));
			//before_PWM.convert2string(), after_PWM.convert2string()));
			
	 		if ( (!(before_PWM.PWM_CPOL ^ before_PWM.PWM_CPHA) && before_PWM.data !== after_PWM.data_risingedge) 
				|| ((before_PWM.PWM_CPOL ^ before_PWM.PWM_CPHA) &&  (before_PWM.data !== after_PWM.data_fallingedge)) )
			begin
	   			uvm_report_error("PWM Comparator", "Error: Data Mismatch");
	   			m_mismatches++;
	 		end else begin
	   			m_matches++;
				uvm_report_info("PWM Comparator", "Data Match");
	 		end
   		end
 	endtask
	
 	function void report_phase( uvm_phase phase );
  		uvm_report_info("PWM Comparator", $sformatf("Matches:    %0d", m_matches));
  		uvm_report_info("PWM Comparator", $sformatf("Mismatches: %0d", m_mismatches));
 	endfunction

endclass: PWM_comparator
