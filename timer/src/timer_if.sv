interface timer_if ();

    parameter int CHANNELS = 8;

    logic [CHANNELS - 1 : 0] t_in;
    logic [CHANNELS - 1 : 0] t_out;
    logic [CHANNELS - 1 : 0] t_irq;
    logic [CHANNELS - 1 : 0] t_oe;
    logic                    tc_irq;

    modport timer(input t_in, output t_out, t_irq, tc_irq, t_oe);

    modport io(output t_in, input t_out);

    modport interrupt_controller(input t_irq, tc_irq);

endinterface
