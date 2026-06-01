
class uart_test extends uvm_test;
    //registering the class
    `uvm_component_utils(uart_test);
    
    function new(string name = "uart_test", uvm_component parent);
        super.new(name, parent);

        //display stmts
        `uvm_info("TEST_CLASS_TAG", "Inside Constructor", UVM_HIGH);
    endfunction //new()

    //Build Phase

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info("TEST_CLASS_TAG", "Build Phase!", UVM_HIGH);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("TEST_CLASS_TAG", "Connect Phase!", UVM_HIGH);
    endfunction


    //tasks can contain time consuming stmts. functions cannot.
    task run_phase(uvm_phase phase);
        super.run_phase(phase);

        //Logic Below
    endtask
    
endclass //className extends superClass