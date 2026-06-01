#include <stdint.h>

#include "pal.h"
#include "format.h"

#define BAUD_CYCLES 2604

UARTRegBlk *uart = (UARTRegBlk *) UART_BASE;

int main() {
    uint32_t data = 0x66;

    uart->txstate = BAUD_CYCLES << 16;

    uart->txdata = data;  // send back byte

    return 0;
}

