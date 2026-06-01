#include <stdint.h>

#include "pal.h"

GPIORegBlk* gpio = (GPIORegBlk *) GPIO0_BASE;

int main() {
    // set gpios
    gpio->ddr = 0xFFFFFFFE;
    gpio->data = 0xAAAAAAAA;

    // cause bus fault
    volatile uint32_t data = *(volatile uint32_t *)(0xFFFFFFFC);

    // should not reach here to set all gpios
    gpio->data = 0xFFFFFFFF;

    return 0;
}

