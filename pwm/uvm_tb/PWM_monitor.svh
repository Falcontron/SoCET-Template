class pwm_monitor extends uvm_monitor;
  
  virtual pwm_if vif;
  
  //---------------------------------------
  //Analysis port declaration
  //---------------------------------------
  uvm_analysis_port#(pwm_seq_item)ap;
  
  `uvm_component_utils(pwm_monitor)
  
  //---------------------------------------
  //Constructor
  //---------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap=new("ap", this);
  endfunction
  
  //---------------------------------------
  //Build phase
  //---------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual pwm_if)::get(this, "", "vif", vif)) begin
       `uvm_error("build_phase", "No virtual interface specified for this monitor instance")
       end
   endfunction
  
  
  //---------------------------------------
  //Run phase
  //---------------------------------------
  virtual task run_phase(uvm_phase phase);
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

    bit pwm_enable, polarity, alignment;
    bit[31:0] count = 32'h0;
    bit[31:0] fcount = 32'h0;
    bit data = 1'b0;
    super.run_phase(phase);
    wait(`MON_IF.start);
    forever begin
      pwm_seq_item trans;
      
      trans=new();
      wait(`MON_IF.load_master==1 && `MON_IF.load_slave==1);
      fork
        trans.control=`MON_IF.control;
        trans.duty=`MON_IF.duty;
	trans.period=`MON_IF.period;
      join

      //wait(`MON_IF.load_master==0 && `MON_IF.load_slave==0);
      pwm_enable = trans.control[0];
      polarity = trans.control[1];
      alignment = trans.control[2];

      @(posedge vif.MONITOR.clk); //write period
	  @(posedge vif.MONITOR.clk);   //data phase
      #(DELAY);
      @(posedge vif.MONITOR.clk); //write duty
	  @(posedge vif.MONITOR.clk);   //data phase
      #(DELAY);
      @(posedge vif.MONITOR.clk); //write control
	  @(posedge vif.MONITOR.clk);   //data phase
      #(DELAY);
	  @(posedge vif.MONITOR.clk); //write period
	  @(posedge vif.MONITOR.clk);   //data phase
      #(DELAY);
	  @(posedge vif.MONITOR.clk); //now is the time to check the values
	  #(DELAY);
       repeat(16 * 4) begin
		   if (alignment == 1'b1) begin
			 #(PERIOD);
			 data = fcount < trans.duty;
			 fcount = fcount + 1;
			 end 	
		   else begin
			 #(PERIOD);
				data = (fcount < (trans.period >> 2 + trans.duty >> 2 + trans.duty[0])) &&
				 (fcount >= (trans.period >> 2 - trans.duty >> 2));
				fcount = fcount + 1;
			 end
        end
      wait(`MON_IF.read_master==1 && `MON_IF.read_slave==1);
      fork
        trans.PADDR=`MON_IF.PADDR;
        trans.PWDATA=`MON_IF.PWDATA;
      join  
      ap.write(trans);
      end
  endtask
endclass
    
