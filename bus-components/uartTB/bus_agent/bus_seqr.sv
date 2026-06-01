
class bus_sequencer extends uvm_sequencer#(bus_sequence_item);
    //registering the class
    `uvm_component_utils(bus_sequencer);
    
    function new(string name = "bus_sequencer", uvm_component parent);
        super.new(name, parent);

        //display stmts
        `uvm_info("sequencer_CLASS_TAG", "Inside Constructor", UVM_HIGH);
    endfunction //new()

    //Build Phase

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info("sequencer_CLASS_TAG", "Build Phase!", UVM_HIGH);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("sequencer_CLASS_TAG", "Connect Phase!", UVM_HIGH);
    endfunction

    
endclass //className extends superClass