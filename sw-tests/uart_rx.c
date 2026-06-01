#include <stdint.h>

#include "pal.h"
#include "format.h"

#define BAUD_CYCLES 2604

UARTRegBlk *uart = (UARTRegBlk *) UART_BASE;

int main() {
    uint32_t data = 0;
    uint32_t state = 0;
    uint32_t nerr = 0;
    uint32_t fifoCount = 0;
    uint32_t i = 0;

    uart->rxstate = (BAUD_CYCLES / 16) << 16;
    uart->txstate = BAUD_CYCLES << 16;

    while (i < 0x8 << 10) {
        while (!((state = uart->rxstate) & 0x1)) {  // wait for byte to be received
            if (state & 0x2) {  // on error
                nerr += 1;
            }
        }
        data = uart->rxdata;
        fifoCount = data >> 24;
        while (fifoCount) {
            if ((data & 0xff) != (i & 0xff)) {
                print("Packet mismatch on %x!", i);
                print("rcv %x != %x, %d\n", data & 0xff, i, nerr);
            #ifdef SYNTHESIS
                for (;;);
            #endif
                print("errors: %d\n", nerr);
                return 1;
            }
            data >>= 8;
            fifoCount -= 1;
            i += 1;
        }
    }

    print("up to %x success!\n", i);
    print("errors: %d\n", nerr);

    return 0;
}
