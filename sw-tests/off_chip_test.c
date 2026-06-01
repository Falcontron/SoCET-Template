#include <stdint.h>
#include "pal.h"
#include "format.h"
#include "riscv.h"

GPIORegBlk* gpio = (GPIORegBlk *) GPIO0_BASE;

int main() {
    uint32_t data;

    // assert GPIO[4] on error, GPIO[5] when done
    gpio->ddr = 0x3 << 4;
    gpio->data = 0;

    for (uint32_t i = 0; i < 1024 * 2; i += 4) {
        *((uint32_t *) (SRAM_BASE + i)) = i ^ 0xFF;
    }

    for (uint32_t i = 0; i < 1024 * 2; i += 4) {
        data = *(uint32_t *)(SRAM_BASE + i);
        if (data != (i ^ 0xFF)) {
            gpio->data = 1 << 4;
        #ifndef SYNTHESIS
            dprint("Mismatch @ %x\n", SRAM_BASE + i);
            dprint("%x vs %x\n", data, i ^ 0xFF);
        #endif
            gpio->data = 1 << 5;
        #ifdef SYNTHESIS
            for (;;);
        #endif
            return 1;
        }
    }

    gpio->data = 1 << 5;
#ifdef SYNTHESIS
    // wait in loop on FPGA
    for (;;);
#endif
    return 0;
}
