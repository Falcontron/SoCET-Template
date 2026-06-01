/*  Test Timer Interrupt

    Desription: -test C file to ensure interrupt works on AFTx06
            -generate binary through running on src_to_rom.py
            -pass to src_to_rom.py as an input on computer 256
            
    Author:     Chris Chiminski, Cole Nelson
    Date:       October 25th, 2020




      mie - machine interrupts enaBle register MRW 0x304
        xSIP - bit 3 MSIP, bit 1 SSIP, bit 0 USIP 
        xTIP - bit 7 MTIP, bit 5 STIP, bit 4 UTIP
        xEIP - bit 11 MEIP, bit 9 SEIP, bit 8 UEIP

      mip - machine interrupt pending MRW 0x344
        xSIE - bit 3 MSIE, bit 1 SSIE, bit 0 USIE
        xTIE - bit 7 MTIE, bit 5 STIE, bit 4 UTIE
        xEIE - bit 11 MEIE, bit 9 SEIE, bit 8 UEIE
    
      0xE000_0000 - CLINT
      0xE001_0000 - PLIC

    */

/*
scp ~/system/AFTx06/programs/intex.c socetlnx03@128.46.75.147:~/dma_team/dtest.c
ssh socetlnx03@128.46.75.147
~/dma_team/runy
exit
rm -f ~/system/AFTx06/sram_controller/src/SOC_ROM.sv
scp socetlnx03@128.46.75.147:~/builder/out/SOC_ROM.sv ~/system/AFTx06/sram_controller/src/SOC_ROM.sv
*/

#include "gpio.h"

int main(void) __attribute__((section(".start")));
void interrupt_handler(void); //interrupt handler
void DMA_send(void);

#define ADDR_CLINT 0xE0000000
#define ADDR_PLIC 0xE0010000

// Delcare as volatile to ensure re-reading after interrupt -- maybe unnecessary, but better safe
volatile unsigned int *interrupted = (unsigned int *)0x8000;
volatile unsigned int *swi_dont_clear = (unsigned int *)0x8004;
volatile unsigned int *a = (unsigned int *)0x8008;
volatile unsigned int *b = (unsigned int *)0x800C;
volatile unsigned int *c = (unsigned int *)0x8010;

int main(void)
{
    volatile int* src_address = 0x8100; // Set address of a location in SRAM
    *src_address = 0x123456ab; // Set the value at 0x8100 to be 0x12345678
    unsigned int value = 0x888;
    asm volatile ("csrwi mstatus, 0x8"); //enables interrupts globally
    asm volatile ("csrw mie, %[reg]": : [reg] "r" (value)); //enables mie interrupts
    asm volatile("csrw mtvec, %[reg]": : [reg] "r" (interrupt_handler)); //assign interrupt controller
    
    int i = 0;
    (*swi_dont_clear) = 1;
    volatile unsigned int *SWI_ADDR = (unsigned int *)ADDR_CLINT;
    volatile unsigned int *MTIMECMP_ADDR = (unsigned int *)(ADDR_CLINT + 0xC);
    volatile unsigned int *MTIME_ADDR = (unsigned int *)(ADDR_CLINT + 0x4);
    //volatile unsigned int *ADDR_CLINT = (unsigned int *)0xE0000000;       //CLINT ADDRESS 
    volatile unsigned int *PLIC = (unsigned int *)ADDR_PLIC;        //PLIC ADDRESS
        
    // //TIMING INTERRUPT
    // int mtime_high = MTIME_ADDR[1];
    // int mtime_low = MTIME_ADDR[0];

    // MTIMECMP_ADDR[1] = mtime_high;
    // MTIMECMP_ADDR[0] = mtime_low + 20;
    // while(!(*interrupted))
    //     ;
    // (*interrupted) = 0;
    
    // //SOFTWARE INTERRUPT
    // (*SWI_ADDR) = 0x1;
    // while(!(*interrupted))
    //     ;

    // (*interrupted) = 0;

    // Setup PLIC
    volatile unsigned int *PLIC_ENABLE = (unsigned int *)(ADDR_PLIC + 0x88);
    (*PLIC_ENABLE) = 0xFFFFFFFF; // Enable 'all' interrupts
    PLIC[1] = 0x7; // Set priority of interrupt source 1 to be 7
    PLIC[2] = 0x6;
    PLIC[3] = 0x5;
    PLIC[4] = 0x4;
    PLIC[5] = 0x4;
    PLIC[6] = 0x2;
    PLIC[7] = 0x1;
    PLIC[8] = 0x1;

    DMA_send();
    while(!(*interrupted))
        ;

    (*interrupted) = 0;

    *src_address = 0xcccccccc;
    //infinite loop - finished with program
    for(;;);
}

void interrupt_handler()
{
    volatile unsigned int *CLINT = (unsigned int *)ADDR_CLINT;
    volatile unsigned int *PLIC_CLAIM = (unsigned int *)(ADDR_PLIC + 0x94);
    volatile unsigned int *MTIMECMP_ADDR = (unsigned int *)(ADDR_CLINT + 0xC);
    volatile unsigned int *MTIME_ADDR = (unsigned int *)(ADDR_CLINT + 0x4);
    unsigned int mcause_value;

    (*interrupted) = 1;

    asm volatile ("csrr %[reg], mcause ": [reg] "=r" (mcause_value));
    // if((mcause_value & 0xFFFF) == 0x3) //machine software interrupt
    // {
    //     //write to clint
    //     (*CLINT) = 0x00;
        
    // }
    // if((mcause_value & 0xFFFF) == 0x7) //machine timer interrupt
    // {
    //     //write to clint
    //     //(*CLINT)
    //     if((*swi_dont_clear)) {
    //         (*swi_dont_clear) = 0;
    //     } else {
    //         MTIMECMP_ADDR[1] = 0xFFFFFFFF;
    //         MTIMECMP_ADDR[0] = 0xFFFFFFFF;
    //     }
    // }
    // read PLIC. Clears interrupt.
    int cause = (*PLIC_CLAIM);
    (*PLIC_CLAIM) = cause;
    volatile int* src_address = 0x8100;
    *src_address = 0xdddddddd;
    if((mcause_value & 0xFFFF) == 0xB) //machine external interrupt
    {
        // read PLIC. Clears interrupt.
        int cause = (*PLIC_CLAIM);
        (*PLIC_CLAIM) = cause;
        volatile int* src_address = 0x8100;
        *src_address = 0xdddddddd;
        volatile int* status_reg = 0x80050014;
        volatile int data = 0;
        data = *status_reg;
    }
    asm volatile ("mret");
}

void DMA_send()
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
