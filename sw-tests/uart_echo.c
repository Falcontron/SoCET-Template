#include <stdint.h>

#include "pal.h"
#include "format.h"

#define BAUD_CYCLES 2604

UARTRegBlk *uart = (UARTRegBlk *) UART_BASE;
GPIORegBlk *gpio = (GPIORegBlk *) GPIO0_BASE;

int main() {
    uint32_t data = 0;

    gpio->ddr = 0xFFFF;
    gpio->data = 0x0;

    uart->rxstate = (BAUD_CYCLES / 16) << 16;
    uart->txstate = BAUD_CYCLES << 16;

    for (;;) {
        while (!(uart->rxstate & 0x1));  // wait for byte to be received
        data = uart->rxdata;
        uart->txdata = data;  // send back byte
        gpio->data = (data & 0xFF) | 0xFF00;
        //while (!(uart->txstate & 0x1));
    }

    return 0;
}

