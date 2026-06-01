/*
scp ~/system/AFTx06/programs/intspi.c socetlnx03@128.46.75.147:~/dma_team/dtest.c
ssh socetlnx03@128.46.75.147
~/dma_team/runy
exit
rm -f ~/system/AFTx06/sram_controller/src/SOC_ROM.sv
scp socetlnx03@128.46.75.147:~/builder/out/SOC_ROM.sv ~/system/AFTx06/sram_controller/src/SOC_ROM.sv
*/

#define ADDR_SPI 0x80030000

int main(void)
{
    volatile int* status_reg = 0x80050014; // Set address of status reg
    volatile int* control_reg = 0x80050010; // Set address of control reg
    volatile int* transfer_reg = 0x8005000C; // Set address of Transfer reg
    volatile int* source_reg = 0x80050004; // Set address of Source reg
    volatile int* dest_reg = 0x80050008; // Set address of Dest. reg

    volatile unsigned int *CNTRL_REG = (unsigned int *)ADDR_SPI;				//Read and Write
    volatile unsigned int *BYTE_LEN_REG = (unsigned int *)(ADDR_SPI + 0x4);		//Read and Write
    volatile unsigned int *BAUD_RATE_REG = (unsigned int *)(ADDR_SPI + 0x8);	//Read and Write
	volatile unsigned int *TX_DATA_REG = (unsigned int *)(ADDR_SPI + 0xC);		//Write only
    volatile unsigned int *RX_DATA_REG = (unsigned int *)(ADDR_SPI + 0x10);		//Read only
	volatile unsigned int *STATUS_REG = (unsigned int *)(ADDR_SPI + 0x14);		//Read and write
    
    volatile int* src_address = 0x8100; // Set address of a location in SRAM
    src_address[0] = 0x12; // Set the value at 0x8100 to be 0x12345678
    src_address[1] = 0x34;
    src_address[2] = 0x56;
    src_address[3] = 0x78;
    volatile int x = *src_address; 


    *source_reg = 0x8100; // Set the source address to be 0x8100
    *dest_reg = TX_DATA_REG;
    *transfer_reg = 0x4; // Set the transfer size to be 1 byte
    *control_reg = 0x3081; // 0x3801; // Set control register for a single byte and enable

    // *CNTRL_REG = 0x2103;
    *CNTRL_REG = 0x1002103;
    (*BYTE_LEN_REG) 	= 0x4;
    (*BAUD_RATE_REG) 	= 0x404;
    // (*TX_DATA_REG) 		= 0xBBCCDD;
	//(*STATUS_REG)		= 0x2800;


    volatile int* dest_address = 0x8200;

    volatile int i;
    volatile int j;
    for(i = 0; i < 100; i++);
    {
        j = i;
    }
    volatile int y = *dest_address;
    


}