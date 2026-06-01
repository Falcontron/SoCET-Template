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
        parameter SPE = 31;
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

        // struct representing SPI Control Register
        typedef struct packed {
            logic start_transaction; // bit 0
            logic mode; // master/slave select, 1 = Master
            logic clock_polarity;
            logic clock_phase;
            logic ssoe;
            logic msb_first; // Transfer direction, 1 = MSB First
            logic modf_enable;
            logic [4:0] rx_water_mark;
            logic [4:0] tx_water_mark;
            logic [5:0] interrupt_enable; // Interrupts in same order as SR below
            logic [8:0] reserved;
        } spi_cr_t;

        // struct representing SPI status register
        /* 
        * Interrupt order
        * 0 - TXN Complete
        * 1 - RX Water Mark
        * 2 - TX Water Mark
        * 3 - RX Full
        * 4 - TX Empty
        * 5 - MODF
        */
        typedef struct packed {
            logic transfer_complete;
            logic rx_water_mark_hit;
            logic tx_water_mark_hit;
            logic rx_buffer_full;
            logic tx_buffer_empty;
            logic modf;
            logic [4:0] rx_buffer_cnt;
            logic [4:0] tx_buffer_cnt;
            logic [15:0] reserved;
        } spi_status_t;

    endpackage
`endif //SPI_TYPE_PKG_VH
