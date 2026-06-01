`ifndef SPI_IF_VH
`define SPI_IF_VH

interface spi_if();

	logic	MISO_IN;
	logic	MISO_OUT;

	logic	MOSI_IN;
	logic	MOSI_OUT;

	logic	SCK_IN;
	logic	SCK_OUT;

	logic 	SS_IN;
	logic	SS_OUT;

	logic	mode;	//1 for output 0 for input
	
	logic [5:0] interrupts;
	
	modport spi
	(
		input	MISO_IN, MOSI_IN, SCK_IN, SS_IN,
		output  MISO_OUT, MOSI_OUT, SCK_OUT,
                SS_OUT, mode, interrupts
	);
endinterface

`endif
	
