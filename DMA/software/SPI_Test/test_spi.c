/*  Test SPI

    Desription: -test C file to ensure spi works on AFTx06
            -generate binary through running on src_to_rom.py
            -pass to src_to_rom.py as an input on computer 256

			-Code writes to the write capable registers
			-reads from registers and confirms correct value and address range
				-incorrect reads sets the 22nd bit of STATUS_REG low
				-correct read sets the 22nd bit of STATUS_REG high
            
    Author:     Chris Chiminski, Cole Nelson
    Date:       November 23rdt, 2020

	SPI - ADDRESS
  	-->0x80003000

    */



#define ADDR_SPI 0x80030000

int main(void)
{
    
    volatile unsigned int *CNTRL_REG = (unsigned int *)ADDR_SPI;				//Read and Write
    volatile unsigned int *BYTE_LEN_REG = (unsigned int *)(ADDR_SPI + 0x4);		//Read and Write
    volatile unsigned int *BAUD_RATE_REG = (unsigned int *)(ADDR_SPI + 0x8);	//Read and Write
	volatile unsigned int *TX_DATA_REG = (unsigned int *)(ADDR_SPI + 0xC);		//Write only
    volatile unsigned int *RX_DATA_REG = (unsigned int *)(ADDR_SPI + 0x10);		//Read only
	volatile unsigned int *STATUS_REG = (unsigned int *)(ADDR_SPI + 0x14);		//Read and write

	unsigned int cntrl_reg_value;
	unsigned int byte_len_value;
	unsigned int baud_rate_value;
	unsigned int rx_data_value;
	unsigned int status_value;

	//Write to registers
	(*CNTRL_REG) 		= 0x74;
	(*BYTE_LEN_REG) 	= 0x4;
	(*BAUD_RATE_REG) 	= 0x404;
	(*TX_DATA_REG) 		= 0xFF;
	(*STATUS_REG)		= 0x2800;

	//read registers and compare, if correct set bit 22 of control register high
	cntrl_reg_value = (*CNTRL_REG);
	if(cntrl_reg_value == 0x74)
	{
		(*CNTRL_REG) |= 0x400000;
	}
	byte_len_value = (*BYTE_LEN_REG);
	if(byte_len_value == 0x4)
	{
		(*CNTRL_REG) |= 0x400000;
	}
	else
	{
		(*CNTRL_REG) &= 0x3FFFFF;
	}
	baud_rate_value = (*BAUD_RATE_REG);
	if(baud_rate_value == 0x404)
	{
		(*CNTRL_REG) |= 0x400000;
	}
	else
	{
		(*CNTRL_REG) &= 0x3FFFFF;
	}
	status_value = (*STATUS_REG);
	if(status_value == 0x2800)
	{
		(*CNTRL_REG) |= 0x400000;
	}
	else
	{
		(*CNTRL_REG) &= 0x3FFFFF;
	}

	//read RX Buffer
	rx_data_value = (*RX_DATA_REG);

	return 0;
	
   
}
