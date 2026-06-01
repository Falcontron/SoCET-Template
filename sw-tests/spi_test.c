#include <stdint.h>

#include "riscv.h"
#include "format.h"
#include "pal.h"

CLINTRegBlk *CLINT  = (CLINTRegBlk *)CLINT_BASE;
PLICRegBlk *PLIC    = (PLICRegBlk *)PLIC_BASE;
SPIRegBlk *spi = (SPIRegBlk *)SPI_BASE;
IOMuxRegBlk *iomux = (IOMuxRegBlk *)IO_MUX_BASE;

volatile int flag = 0;

const unsigned EXT_DONE   = 0x0FF;
const unsigned SW_DONE    = 0x100;
const unsigned TIMER_DONE = 0x200;
const unsigned FLAG_PREFIX_MASK = 0x7FFF; // exclude unexpected

// The current design has the bit fields flipped
union contrl_reg {
    struct {
        volatile unsigned int reserved_field : 9;
        // Interrupt enable signals
        volatile unsigned int MODF_int_en : 1;
        volatile unsigned int TX_buffer_empty_int_en : 1;
        volatile unsigned int RX_buffer_full_int_en : 1;
        volatile unsigned int TX_water_hit_int_en : 1;
        volatile unsigned int RX_water_hit_int_en : 1;
        volatile unsigned int Transfer_complete_int_en : 1;
        // Water mark
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

void __attribute__((interrupt)) mtime_handler() {
    flag |= TIMER_DONE;
    print("IRQ: mtime\n");
    CLINT->mtimecmp[0].l = 0xFFFFFFFF;
}

void __attribute__((interrupt)) mext_handler() {
    uint32_t int_id = PLIC->cfg[0].claim_complete;
    flag |= (1 << (int_id-1));
    print("IRQ: ext\n");

    spi->cr0 = 0x0;
    //spi->sr0 |= 0xFFFFFFFF;

    PLIC->cfg[0].claim_complete = int_id;

    print("Ext #%d\n", int_id);
}

int main() {
    CLINT->mtimecmp[0].l += 0x2000;
    PLIC->enable[0] = 0xFFFFFF;
    for(int i = 8; i < 14; i++) {
        PLIC->priority[i] = 0x7;
    }

    interrupt_enable();

    iomux->fsel0 = IOM_F0_SPI_SS | IOM_F0_SPI_SCK | IOM_F0_SPI_MOSI | IOM_F0_SPI_MISO;

    dprint("configuring spi\n");
    union contrl_reg cr_data;
    // spi->cr0 = 0x0;
    // cr_data.Mode = 1;
    // cr_data.Clock_polarity = 1;
    // cr_data.Clock_phase = 1;
    // cr_data.SSOE = 1;
    // cr_data.Transfer_complete_int_en = 1;
    // spi->cr0 = cr_data.data;
    spi->cr0 = SPI_CR_MODE | SPI_CR_CLK_POL | SPI_CR_CLK_PHASE | SPI_CR_SSOE | SPI_CR_TC_IE;
    // spi->cr0 = 0x78007E00; // Master mode, clock idle at 1, leading edge clock, SSOE
                            // Enable all interrupts to test
    spi->brr0 = 0x10;
    spi->txdr0 = 0xAA;
    spi->blr0 = 0x1;
    // cr_data.Start = 1;
    // spi->cr0 = cr_data.data;
    spi->cr0 |= SPI_CR_TX_START;
    
    //spi->cr0 = 0xF8007E00;

    asm volatile("wfi");
    asm volatile("wfi");

    return 0;
}
