#pragma once

#include <cstdint>

#define __I  volatile const
#define __O  volatile
#define __IO volatile

#define UART_BASE ((uint32_t)0x90002000)
#define CPU_MHZ 30

#define FIFO_IDX_MASK 0x3F

/// @brief UART manager class with FIFO buffer for Rx
class BufferedUART {
    
    typedef struct {
        __IO uint32_t rxstate;
        __I  uint32_t rxdata;
        __IO uint32_t txstate;
        __IO uint32_t txdata;
    } UARTRegBlk;

    uint8_t buffer[64];
    UARTRegBlk *uart_regs;
    uint8_t rptr;
    uint8_t wptr;
    bool full;

    bool empty() {
        return (wptr == rptr) && !full;
    }

    void push(uint8_t byte) {
        buffer[wptr] = byte;
        wptr = (wptr + 1) & FIFO_IDX_MASK;
        full = (wptr == rptr);
    }

    uint8_t pop() {
        auto rv = buffer[rptr];
        rptr = (rptr + 1) & FIFO_IDX_MASK;
        full = false;
        return rv;
    }

    uint8_t peek() {
        return buffer[rptr];
    }

public:
    BufferedUART(uint32_t baud);
    /// @brief Check for UART data and place in buffer
    /// @return true if data available
    bool poll();
    /// @brief Pull a byte from the buffer. Block if no data available.
    /// @return Next byte of UART data
    uint8_t get_byte();
    /// @brief Same as `get_byte`, but does not advance the buffer head
    /// @return Next byte of UART data
    uint8_t peek_byte();
    /// @brief Check if Tx is available
    /// @return true if ready to send a new byte
    bool ready_to_send() const;
    /// @brief Send a byte, block if Tx not yet available
    /// @param byte Data to send via UART
    void send_byte(uint8_t byte);
};