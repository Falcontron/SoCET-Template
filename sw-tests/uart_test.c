#include <stdint.h>

#include "pal.h"
#include "format.h"

#define BAUD_CYCLES 9600

UARTRegBlk *uart = (UARTRegBlk *) UART_BASE;

int main() {
    uint32_t data = 0;

    uart->rxstate = (BAUD_CYCLES / 16) << 16;
    uart->txstate = BAUD_CYCLES << 16;
    for (int i = 0; i < 40000 * 4; i++);  // wait for bytes to be sent to test RX buffering
    while (!(uart->rxstate & 0x1));
    data = uart->rxdata;
    print("data: %x\n", data);

    if ((data >> 24) != 3) {
        print("Incorrect number of bytes read\n");
        print("Read %d, expected %d\n", data >> 24, 3);
        return 1;
    }
    if ((data & 0xffffff) != 0x6045f7) {
        print("Incorrect bytes received\n");
        print("Read %x, expected %x\n", data & 0xffffff, 0x6045f7);
        return 1;
    }

    uart->txdata = 0xaabb11 | 3 << 24;
    while (!(uart->txstate & 0x1));

    if ((uart->txstate >> 16) != BAUD_CYCLES) {
        print("Incorrect baud rate read\n");
        print("Read %d, expected %d\n", uart->txstate >> 16, BAUD_CYCLES);
        return 1;
    }

    return 0;
}
