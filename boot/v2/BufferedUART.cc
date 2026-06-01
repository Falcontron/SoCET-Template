#include <cstdint>

#include "BufferedUART.hh"
#include "format.h"

BufferedUART::BufferedUART(uint32_t baud) 
    : uart_regs((UARTRegBlk *)UART_BASE), rptr(0), wptr(0), full(false) {
    
    uint32_t divider = (((CPU_MHZ * 1000000) / baud));
    uart_regs->rxstate = (divider << 16);
    uart_regs->txstate = (divider << 16);
    // read out RX state & data
    volatile uint32_t readout = uart_regs->rxstate;
    readout = uart_regs->rxdata;
}

bool BufferedUART::poll() {
    uint32_t state = uart_regs->rxstate;
    if(state & 0x1) {
        uint32_t rxdata = uart_regs->rxdata;
        uint8_t count = (rxdata >> 24) & 0xFF;
        if(count > 3) {
            asm volatile("ecall");
        }

        for(auto i = 0; i < count; i++) {
            push(static_cast<uint8_t>((rxdata & 0xFF)));
            rxdata >>= 8;
        }
    } else if(state & 0x2) {
        dprint("UART Error! (RX)\n");
        asm volatile("ecall");
    }

    return !empty();
}

uint8_t BufferedUART::get_byte() {
    while(!poll());
    return pop();
}

uint8_t BufferedUART::peek_byte() {
    while(!poll());
    return peek();
}

bool BufferedUART::ready_to_send() const {
    if(uart_regs->txstate & 0x2) {
        dprint("UART Error (TX)\n");
    }
    return (uart_regs->txstate & 1);
}

void BufferedUART::send_byte(uint8_t byte) {
    while(!ready_to_send()) {
        poll();
    }
    uart_regs->txdata = byte | (1u << 24);
}
