
class bus_sequence_item extends uvm_sequence_item;
    rand logic [31:0] addr;
    rand logic [31:0] wdata;
    logic [31:0] rdata;
    rand logic [3:0]  strobe;
    rand logic        wen;
    rand logic        ren;
    `uvm_object_utils(bus_sequence_item);
    function new(string name = "bus_sequence_item");
        super.new(name);
        
    endfunction //new()
endclass //className extends superClass