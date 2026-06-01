
class bus_monitor extends uvm_monitor;
    //registering the class
    `uvm_component_utils(bus_monitor);

    virtual bus_interface bus_vif_monitor;

    
    function new(string name = "bus_monitor", uvm_component parent);
        super.new(name, parent);

        //display stmts
        `uvm_info("monitor_CLASS_TAG", "Inside Constructor", UVM_HIGH);
    endfunction //new()

    //Build Phase

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info("monitor_CLASS_TAG", "Build Phase!", UVM_HIGH);
        if(!(uvm_config_db #(virtual bus_interface):: get(this, "*", "bus_vif", bus_vif_monitor))) begin
            //if get method fails then
            `uvm_error("Monitor Driver Class", "Failed to get vif from config db!")
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("monitor_CLASS_TAG", "Connect Phase!", UVM_HIGH);
    endfunction


    //tasks can contain time consuming stmts. functions cannot.
    task run_phase(uvm_phase phase);
        super.run_phase(phase);

        //Logic Below
    endtask
    
endclass //className extends superClass