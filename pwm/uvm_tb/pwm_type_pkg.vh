`ifndef SPI_TYPE_PKG_VH
`define SPI_TYPE_PKG_VH
package spi_type_pkg;

  // word width and size
parameter WORD_W    = 32;
parameter WBYTES    = WORD_W/8;
parameter NUM_REGS = 6;
parameter NUM_ROREGS = 4;

parameter SPICR1 = 0;
parameter SPIBL = 1;
parameter SPIBR = 2;
parameter SPITDR = 3;
parameter SPIRDR = 4;	//read only to CPU
parameter SPISR = 5;	//read only to CPU

//control register 1
parameter SPIE = 31;
parameter SPE = 30;
parameter MSTR = 29;
parameter CPOL = 28;
parameter CPHA = 27;
parameter SSOE = 26;
parameter LSBFE = 25;
parameter MODFEN = 24;
parameter SPIBWM = 23;	//SPI buffer water mark level 23:20
parameter SPIBWMW = 4;	//SPI buffer water mark bit width

//status register
parameter SPITF = 31;	//transfer complete
parameter SPIRF = 30;	//recieve complete
parameter SPIBWF = 29;	//high if buffer water hit
parameter SPIBF = 28;	//buffer full
parameter SPIBE = 27;	//transfer buffer empty
parameter MODF = 26;	
parameter NDIB = 25;	//number of data in buffer max 10
parameter NDIBW = 4;
// word_t
  typedef logic [WORD_W-1:0] word_t;

  typedef enum logic [2:0] {
	IDLE, 
	TRS, 
	TRS1,
	TXRE,
	RCV,
	RCV1,
	RXPT
  } control_state;

endpackage
`endif //SPI_TYPE_PKG_VH
