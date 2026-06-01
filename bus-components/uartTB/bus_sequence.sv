
class bus_base_seq extends uvm_sequence;
    `uvm_object_utils(bus_sequence_item);
    function new(string name = "bus_base_sequence");
        super.new(name);
        `uvm_info("BUS_BASE_SEQ", "INSIDE CONSTRUCTOR!", UVM_HIGH);
    endfunction //new()

    task body();
        `uvm_info("BUS_BASE_SEQ", "Inside Body!", UVM_HIGH);
    endtask
endclass //className extends superClass