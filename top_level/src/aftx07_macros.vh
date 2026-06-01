`ifndef __AFTx07_MACROS__
`define __AFTx07_MACROS__
    

    `define ADD_APB(module_name, index, nwords, bus_interface) \
        apb_completer #(                    \
            .BASE_ADDR(APB_MAP[(index)]),   \
            .NWORDS((nwords))               \
        ) APB_``module_name`` (             \
            .apbif(apb_peripherals[(index)]),   \
            .protif(bus_interface)          \
        );

    `define ADD_AHB(module_name, index, nwords, bus_interface) \
        ahb_subordinate #(                      \
            .BASE_ADDR(AHB_MAP[(index)]),       \
            .NWORDS((nwords))                   \
        ) AHB_``module_name`` (                 \
            .ahb_if(ahb_peripherals[(index)]),      \
            .bus_if(bus_interface)              \
        );

    `define DEFINE_INTERRUPT(irq_name, irq_num, signal) \
        socetlib_synchronizer #(              \
            .STAGES(2),                       \
            .RESET_STATE(1'b0)                \
        ) irq_sync_``irq_name`` (.CLK(HCLK), .nRST(ahb_nRST), \
            .async_in(signal),                \
            .sync_out(plicif.hw_interrupt_requests[irq_num]) \
        );

    // TODO: Define analagous "ADD_AHB"

    `define DEFINE_PIN(pin_num, functions_to_module, functions_from_module, functions_output_enable) \
      assign output_enable[(pin_num+1)*IO_MUX_NUM_FUNC-1:pin_num*IO_MUX_NUM_FUNC] = functions_output_enable; \
      assign from_module[(pin_num+1)*IO_MUX_NUM_FUNC-1:pin_num*IO_MUX_NUM_FUNC] = functions_from_module; \
      assign ``functions_to_module`` = to_module[(pin_num+1)*IO_MUX_NUM_FUNC-1:pin_num*IO_MUX_NUM_FUNC];

`endif


`define ADD_MULTI_SYNC(signal_name, width, reset_state, stages, clk, nrst) \
    sync_wrapper #(.WIDTH(width), .RESET_STATE(reset_state), .STAGES(stages)) \
    sync_wrapper_``signal_name`` (.CLK(clk), .nRST(nrst), \
    .async_in(signal_name[((width)-1):0]), \
    .sync_out(sync_``signal_name``[((width)-1):0]) );

`define ADD_SYNC(signal_name, reset_state, stages, clk, nrst) \
    socetlib_synchronizer #(.STAGES(stages), .RESET_STATE(reset_state)) \
    digilib_sync_``signal_name`` (.CLK(clk), .nRST(nrst), \
    .async_in(signal_name), .sync_out(sync_``signal_name``));