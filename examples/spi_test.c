#include <stdint.h>
#include "pal.h"

GPIORegBlk *GPIO    = (GPIORegBlk *)GPIO_BASE;
CLINTRegBlk *CLINT  = (CLINTRegBlk *)CLINT_BASE;
PLICRegBlk *PLIC    = (PLICRegBlk *)PLIC_BASE;
SPIRegBlk *spi = (SPIRegBlk *)SPI_BASE;

volatile int flag = 0;

const int EXT_DONE      = 0xFF; // 8 GPIO interrupts
const int SW_DONE       = 0x100;
const int TIMER_DONE    = 0x200;

//The current design has the bit fields flipped
union contrl_reg {
    struct {
        volatile unsigned int reserved_field : 9;
        //Interrupt enable signals
        volatile unsigned int MODF_int_en : 1;
        volatile unsigned int TX_buffer_empty_int_en : 1;
        volatile unsigned int RX_buffer_full_int_en : 1;
        volatile unsigned int TX_water_hit_int_en : 1;
        volatile unsigned int RX_water_hit_int_en : 1;
        volatile unsigned int Transfer_complete_int_en : 1;
        //Water mark
        volatile unsigned int TX_water_mark : 5;
        volatile unsigned int RX_water_mark : 5;    

        volatile unsigned int MODF_en : 1;
        volatile unsigned int MSB : 1;
        volatile unsigned int SSOE : 1;
        volatile unsigned int Clock_phase : 1;
        volatile unsigned int Clock_polarity : 1;
        volatile unsigned int Mode : 1;
        volatile unsigned int Start : 1;
    };
    uint32_t data;
};
void __attribute__((interrupt)) m_spi_handler() {
    print("SPI Interrupt handler!\n");
    uint32_t int_id = PLIC->ccr;
    union contrl_reg cr_data;
    spi->cr0 = 0x0;
    //spi->sr0 |= 0xFFFFFFFF;
    PLIC->ccr = int_id;
    //print("int_id = %x\n", int_id);
}

void __attribute__((interrupt)) default_handler() {
    print("Test failed!\n");
    __inf_loop(); // Test failed
}

void __attribute__((interrupt)) m_timer_handler() {
    flag |= TIMER_DONE;
    print("Timer handler\n");
    CLINT->mtimecmp = 0xFFFFFFFF;
}

void __attribute__((interrupt)) m_sw_handler() {
    flag |= SW_DONE;
    print("SW Interrupt handler!\n");
    CLINT->msip = 0x0;
}

void __attribute__((naked)) __attribute__((aligned(4))) handler_dispatch() {
    asm volatile(
        ".option push\n"
        ".option norvc\n"
        "j default_handler\n" // 0
        "j default_handler\n" // 1
        "j default_handler\n" // 2
        "j default_handler\n" // 3
        "j default_handler\n" // 4
        "j default_handler\n" // 5
        "j default_handler\n" // 6
        "j m_timer_handler\n" // 7
        "j default_handler\n" // 8
        "j default_handler\n" // 9
        "j default_handler\n" // 10
        "j m_spi_handler\n"   // 11
        : : : "memory");
}

int main() {
    CLINT->mtimecmp = 0xFFF;
    uint32_t mtvec_value = ((uint32_t)handler_dispatch) | 0x1;
    asm volatile("csrw mstatus, %0" : : "r" (0x8));
    asm volatile("csrw mtvec, %0" : : "r" (mtvec_value));
    asm volatile("csrw mie, %0" : : "r" (0x808));

    // Setup PLIC
    PLIC->ier = 0xFFFFFF;
    PLIC->iprior[8] = 0x7;
    PLIC->iprior[9] = 0x7;
    PLIC->iprior[10] = 0x7;
    PLIC->iprior[11] = 0x7;
    PLIC->iprior[12] = 0x7;
    PLIC->iprior[13] = 0x7;

    print("SPI TEST!\n");    
    union contrl_reg cr_data;
    spi->cr0 = 0x0;
    cr_data.Mode = 1;
    cr_data.Clock_polarity = 1;
    cr_data.Clock_phase = 1;
    cr_data.SSOE = 1;
    cr_data.Transfer_complete_int_en = 1;
    spi->cr0 = cr_data.data;
    // spi->cr0 = 0x0;
    // spi->cr0 = 0x78007E00; // Master mode, clock idle at 1, leading edge clock, SSOE
                            // Enable all interrupts to test
    spi->brr0 = 0x10;
    spi->txdr0 = 0xAA;
    spi->blr0 = 0x1;
    cr_data.Start = 1;
    spi->cr0 = cr_data.data;
    
    //spi->cr0 = 0xF8007E00;

    for(;;) {
        asm volatile("wfi");
    }
    
    return 0;
}
