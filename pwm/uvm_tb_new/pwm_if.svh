`ifndef PWM_IF_SVH
`define PWM_IF_SVH

interface pwm_if #(parameter NUM_CHANNELS = 1);
    // Inputs
    logic clk;
    logic n_rst;

    // Output
    logic [NUM_CHANNELS-1:0] pwm_out;

endinterface : pwm_if

`endif
