`include "uvm_macros.svh"

class pwm_scoreboard extends uvm_component;
  `uvm_component_utils(pwm_scoreboard)

  uvm_tlm_analysis_fifo #(pwm_transaction) pwm_fifo;
  uvm_tlm_analysis_fifo #(apb_rw) apb_tx_fifo; //all the apb transactions that write to TX register
  uvm_tlm_analysis_fifo #(apb_rw) apb_rx_fifo; //all the apb transactions that read from rx register
  apb_rw received_apb_tx;
  apb_rw apb_tx; //cloned value
  pwm_transaction received_tx;
  pwm_transaction pwm_tx; //cloned value
  bit addr_mode;
  bit rw_status; //check if current sequence of transactions ia r or w. 1 -> read, 0 -> write

  pwm_env_config env_config;
  pwm_top_block pwm_rb;
  
  uvm_reg_data_t pwm_read_data;
  uvm_status_e status;

  // statistics
  int no_pwm_transaction; //number of transactions
  int no_error; //number of errors


  function new(string name = "", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    pwm_fifo = new("pwm_fifo", this);
    apb_tx_fifo = new("apb_tx_fifo", this);
    apb_rx_fifo = new("apb_rx_fifo", this);
    if (env_config == null) begin
			`uvm_fatal("SCOREBOARD", "No configuration passed in")
    end
    pwm_rb = env_config.pwm_rb;
    no_pwm_transaction = 0;
    no_error = 0;
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("pwm_SB:", $sformatf("\nTotal number of pwm transactions: %d\nTotal number of error %d\n", no_pwm_transaction, no_error), UVM_LOW)
  endfunction

  //-------------------------------------

  task run_phase(uvm_phase phase);
    if (env_config.master_slave) begin
      master_run; // when DUT is a master
    end else begin
      slave_run; // when DUT is a slave
    end
  endtask: run_phase

  task master_run();
    forever begin
      pwm_fifo.get(received_tx);
      if (!$cast(pwm_tx, received_tx.clone())) begin
        `uvm_fatal("SCOREBOARD", "Cannot cast");
      end
      no_pwm_transaction++;

      if (pwm_tx.tx_type) begin //ADDR transaction
        addr_check;
        rw_status = pwm_tx.rw;
      end else begin //DATA transaction
        if (rw_status) begin // when DUT tries to read from slave
          rx_auto_check;
        end else begin // when DUT tries to write data
          tx_check;
        end
      end
    end
  endtask

 
  
  //-------------------------------------





  //-------------------------------------  

  function int addr_match(pwm_transaction tx); //check if the master is communicating with DUT
    // $info("DEBUG::SB tx: addr mode: %b, addr %b\n", tx.addr_mode, tx.addr);
    // $info("DEBUG::SB config: addr mode: %b, addr %b\n", env_config.DUT_addr_mode, env_config.DUT_addr);
    if(tx.addr_mode != env_config.DUT_addr_mode) begin
      return 0;
    end
    if (tx.addr_mode) begin //if 10 bit mode
      return tx.addr == env_config.DUT_addr;
    end else begin //7 bit mode
      return tx.addr[6:0] == env_config.DUT_addr[6:0];
    end
  endfunction

endclass

`endif
