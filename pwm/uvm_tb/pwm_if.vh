`ifndef pwm_IF_VH
`define pwm_IF_VH

interface pwm_if(input bit clk);


	logic	[31:0] PADDR;
	logic	[31:0] PWDATA;

	logic	PSEL;
	logic	PENABLE;

	logic 	[31:0] PRDATA;
	logic	PWM_OUT;


	
	clocking pwm_cb @(posedge clk);
		input	PADDR,PSEL,PENABLE,PRDATA;
		output  PWM_OUT,PRDATA;
	endclocking: pwm_cb

	clocking monitorpwm_cb @(negedge clk);
		input PADDR,PSEL,PENABLE,PRDATA,PWM_OUT,PWM_OUT,PRDATA;
	endclocking: monitorpwm_cb

        modport pwm_tb(clocking pwm_cb);
	modport pwmmon(clocking monitorpwm_cb);

	modport pwm
	(
		input	PADDR,PSEL,PENABLE,PRDATA,
		output  PWM_OUT,PWM_OUT,PRDATA
	);

endinterface

`endif
