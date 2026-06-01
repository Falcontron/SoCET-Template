#include <stdint.h>
#include <stdarg.h>
#include "utility.h"
#include "format.h"
#include "pal.h"

GPIORegBlk *GPIO    = (GPIORegBlk *)GPIO_BASE;
CLINTRegBlk *CLINT  = (CLINTRegBlk *)CLINT_BASE;
PLICRegBlk *PLIC    = (PLICRegBlk *)PLIC_BASE;

typedef struct DMA_CR_CONFIG
{
    // Bit[0] : EN : should be set to start the transfer
    uint8_t EN;
    // Bit[1] : TCIE : is the Transfer Complete Interrupt Enable
    uint8_t TCIE;
    // Bit[2] : HTIE : is the Half Transfer Interrupt Enable
    uint8_t HTIE;
    // Bit[4] : SRC : Is the source a peripheral or memory (0: Source is Memory, 1: Source is Peripheral)
    uint8_t SRC;
    // Bit[5] : DST : Is the source a peripheral or memory (0: Source is Memory, 1: Source is Peripheral)
    uint8_t DST;
    // Bit[6:7] : PSIZE : Peripheral Size (00: 8-bit, 01: 16-bit, 10: 32-bit)
    uint8_t PSIZE;
    // Bit[8] : TE : DMA Trigger Enable
    uint8_t TE;
    // Bit[10] : CIRC: Circular Mode
    uint8_t CIRC;
    // Bit[11]: IDST: Increment destination address every read/write
    uint8_t IDST;
    // Bit[12]: ISRC: Increment source address every read/write
    uint8_t ISRC;
}DMA_CR_CONFIG;

unsigned int DMA_CR_trans(DMA_CR_CONFIG config)
{
    unsigned int DMA_CR = config.EN | (config.TCIE << 1) | (config.HTIE << 2) | (config.SRC << 3) | (config.DST << 4) | (config.PSIZE << 5) | (config.TE << 8) | (config.CIRC << 10) | (config.IDST << 11) | (config.ISRC << 12);
    print("CR = %x\n", DMA_CR);
    return DMA_CR;
}

volatile int flag = 0;
const int GPIO_DONE      = 0xFF; // 8 GPIO interrupts
const int EXT_DONE      = 0x40FF; // 8 GPIO interrupts + DMA

void __attribute__((interrupt)) default_handler() {
    print("Test failed!\n");
    __inf_loop(); // Test failed
}

void __attribute__((interrupt)) m_sw_handler() {
    print("SW Interrupt handler!\n");
    CLINT->msip = 0x0;
}

// void __attribute__((interrupt)) m_dma_handler() {
void m_dma_handler() {
    volatile unsigned int *DMA_CR = 0x90001010; 
    uint32_t int_id = PLIC->ccr;

    flag |= (1 << (int_id-1));
    print("DMA Interrupt handler!\n");
    (*DMA_CR) = (uint32_t)0;
    PLIC->ccr = int_id;
}

void __attribute__((interrupt)) m_timer_handler() {
    print("Timer handler\n");
    CLINT->mtimecmp = 0xFFFFFFFF;
}

void __attribute__((interrupt)) m_ext_handler() {
    // Interrupt # corresponds to pin #
    // Interrupt claim
    uint32_t int_id = PLIC->ccr;
    flag |= (1 << (int_id-1));
    print("Flag = %x\n", flag);

    if(int_id == 15) {
        m_dma_handler();
    } else {

        // GPIO Disable
        GPIO->icr = (1 << (int_id-1)); // cleared
        GPIO->ier &= ~(1 << (int_id-1));
    
    }
    // PLIC: complete
    PLIC->ccr = int_id;
}

void __attribute__((naked)) __attribute__((aligned(4))) handler_dispatch() {
    asm volatile(
        ".option push\n"
        ".option norvc\n"
        "j default_handler\n" // 0
        "j default_handler\n" // 1
        "j default_handler\n" // 2
        "j m_sw_handler\n"    // 3
        "j default_handler\n" // 4
        "j default_handler\n" // 5
        "j default_handler\n" // 6
        "j m_timer_handler\n" // 7
        "j default_handler\n" // 8
        "j default_handler\n" // 9
        "j default_handler\n" // 10
        "j m_ext_handler\n"   // 11
        : : : "memory");
}

int main() {    


    // for(int i = 0; i < 500; i++) {
    //     __asm__("wfi");
    // }


    volatile unsigned int *DMA_SAR = 0x90001004;
    volatile unsigned int *DMA_DAR = 0x90001008;
    volatile unsigned int *DMA_TSR = 0x9000100C;
    volatile unsigned int *DMA_CR = 0x90001010; 
    volatile unsigned int *DMA_SR = 0x90001014;

    int start_arr[8] = {1, 2, 3, 4, 5, 6, 7, 8};
    int end_arr[8] = {99, 99, 99, 99, 99, 99, 99, 99};

    //      8 word transfer
    //      increment both source and distination

    print("start_arr = %x\n", start_arr);
    print("end_arr = %x\n", end_arr);

    (*DMA_SAR) = (int *)start_arr;
    (*DMA_DAR) = (int *)end_arr;
    // (*DMA_SAR) = 0xA3B0;
    // (*DMA_DAR) = 0xA3D0;
    (*DMA_TSR) = (unsigned int) 8;

    print("SAR = %x\n", *DMA_SAR);
    print("DAR = %x\n", *DMA_DAR);
    print("TSR = %x\n", *DMA_TSR);

    DMA_CR_CONFIG test_config = {.EN = 1, .TCIE = 1, .HTIE = 0, .SRC = 0, .DST = 0, .PSIZE = 2, .TE = 0, .CIRC = 0, .IDST = 1, .ISRC = 1};


    // Does CLINT also need to be setup?
    // CLINT->mtimecmp = 0xFFF;
    uint32_t mtvec_value = ((uint32_t)handler_dispatch) | 0x1;
    asm volatile("csrw mstatus, %0" : : "r" (0x8));
    asm volatile("csrw mtvec, %0" : : "r" (mtvec_value));
    asm volatile("csrw mie, %0" : : "r" (0x888));


    // Setup PLIC
    PLIC->ier = 0xFFFFFFFF;
    PLIC->iprior[0] = 0x7;
    PLIC->iprior[1] = 0x7;
    PLIC->iprior[2] = 0x7;
    PLIC->iprior[3] = 0x7;
    PLIC->iprior[4] = 0x7;
    PLIC->iprior[5] = 0x7;
    PLIC->iprior[6] = 0x7;
    PLIC->iprior[7] = 0x7;
    PLIC->iprior[14] = 0x7; // DMA added

    // setup GPIO (input mode default)
    GPIO->per = 0xFF;
    GPIO->ier = 0xFF;

    print("Triggering SW interrupt!\n");
    CLINT->msip = 0x1;

    // setup DMA transfer
    unsigned int middle = DMA_CR_trans(test_config);
    print("middle = %x\n", middle);
    (*DMA_CR) = middle;

    // wait for DMA interrupt 
    for(int i = 0; i < 500; i++) {
        __asm__("wfi");
    }
    print("DMA should be finished\n");
    
    while(flag != EXT_DONE);
    // print(flag);
    // // while(flag != EXT_DONE);

    // print("Test passed!\n");
    // return 0;
}