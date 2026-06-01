/*
scp ~/system/AFTx06/programs/dtest.c socetlnx03@128.46.75.147:~/dma_team/dtest.c
ssh socetlnx03@128.46.75.147
~/dma_team/runy
exit
rm -f ~/system/AFTx06/sram_controller/src/SOC_ROM.sv
scp socetlnx03@128.46.75.147:~/builder/out/SOC_ROM.sv ~/system/AFTx06/sram_controller/src/SOC_ROM.sv
*/

int main(void)
{
    volatile int* status_reg = 0x80050014; // Set address of status reg
    volatile int* control_reg = 0x80050010; // Set address of control reg
    volatile int* transfer_reg = 0x8005000C; // Set address of Transfer reg
    volatile int* source_reg = 0x80050004; // Set address of Source reg
    volatile int* dest_reg = 0x80050008; // Set address of Dest. reg
    
    volatile int* src_address = 0x8100; // Set address of a location in SRAM
    *src_address = 0x123456ab; // Set the value at 0x8100 to be 0x12345678
    volatile int x = *src_address; 


    *source_reg = 0x8100; // Set the source address to be 0x8100
    *dest_reg = 0x8200; // Set the destination address to be 0x8200
    *transfer_reg = 0x1; // Set the transfer size to be 1 byte
    *control_reg = 0x1801; // Set control register for a single byte and enable


    volatile int* dest_address = 0x8200;

    volatile int i;
    volatile int j;
    for(i = 0; i < 100; i++);
    {
        j = i;
    }
    volatile int y = *dest_address;
    


}