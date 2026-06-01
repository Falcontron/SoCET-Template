
class uart_base_seq extends uvm_sequence;
    `uvm_object_utils(uart_sequence_item);
    function new(string name = "uart_base_sequence");
        super.new(name);
        `uvm_info("uart_BASE_SEQ", "INSIDE CONSTRUCTOR!", UVM_HIGH);
    endfunction //new()

    task body();
        `uvm_info("uart_BASE_SEQ", "Inside Body!", UVM_HIGH);
    endtask
endclass //className extends superClass