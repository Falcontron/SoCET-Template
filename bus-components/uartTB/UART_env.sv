

class uart_env extends uvm_env;

    `uvm_component_utils(uart_env);
    function new(string name = "uart_env", uvm_component parent);
      super.new(name, parent); 

      `uvm_info("ENV CLASS", "Inside Constructor", UVM_HIGH)
    endfunction //new()

    //build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);  
    `uvm_info("ENV_CLASS", "Inside Build", UVM_HIGH)

    endfunction
    //connect phase
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);  
        `uvm_info("ENV CLASS", "Inside Connect", UVM_HIGH)

    endfunction
    //run phase
    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        //Logic   
    endtask
endclass //className extends superClass