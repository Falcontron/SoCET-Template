#pragma once

#include <iostream>

#include "UARTDataBuffer.hh"

class UARTSimulator {
    UARTDataBuffer& rx_buf;
    UARTDataBuffer& tx_buf;
    uint32_t baud_rate;
    uint32_t cycles_per_bit;

    struct UARTChannelData {
        uint32_t count;
        uint32_t bitnum;
        uint8_t current_byte;
        bool active_now;
        uint8_t prev;

        UARTChannelData() : count(0), bitnum(0), current_byte(0), active_now(false), prev(1) {}
    };

    struct UARTChannelData rx_chan;
    struct UARTChannelData tx_chan;

public:
    UARTSimulator(UARTDataBuffer& rx_buf, UARTDataBuffer& tx_buf, uint32_t speed_mhz, uint32_t baud) : rx_buf(rx_buf), tx_buf(tx_buf), baud_rate(baud) {
        auto hz = speed_mhz * 1000000;
        cycles_per_bit = hz / baud;
        std::cout << "Using " << cycles_per_bit << "cycles per bit" << std::endl;
    }

    void reset() {
        
    }

    uint8_t tick(uint8_t tx) {

        // RX Handling
        uint8_t rx = rx_chan.prev;
        if(!rx_chan.active_now && rx_buf.data_avail()) {
            rx_chan.current_byte = rx_buf.pop();
            rx_chan.bitnum = 0;
            rx_chan.active_now = true;
            rx_chan.count = cycles_per_bit;
            std::cout << "[UART Rx]: Forwarding received byte " <<  (unsigned)rx_chan.current_byte << std::endl;
        } 
        
        if(rx_chan.active_now && rx_chan.count == 1) {
            if(rx_chan.bitnum == 0) {
                rx = 0;
                rx_chan.bitnum += 1;
            } else if(rx_chan.bitnum < 9) {
                rx = (rx_chan.current_byte >> (rx_chan.bitnum - 1)) & 0x1;
                rx_chan.bitnum += 1;
            } else if(rx_chan.bitnum == 9) {
                rx = 1;
                rx_chan.bitnum += 1;
            } else if(rx_chan.bitnum == 10) {
                rx = 1;
                rx_chan.active_now = false;
            }

            rx_chan.count -= 1;
        } else if(rx_chan.active_now && rx_chan.count == 0) {
            rx_chan.count = cycles_per_bit;
        } else if(rx_chan.active_now && rx_chan.count > 0) {
            rx_chan.count -= 1;
        }


        // TX Handling
        if(!tx_chan.active_now && tx_chan.prev == 1 && tx == 0) {
            // start condition
            tx_chan.current_byte = 0;
            tx_chan.active_now = true;
            tx_chan.count = cycles_per_bit / 2; // sample in the middle
            tx_chan.bitnum = 0;
        }

        if(tx_chan.active_now) {
            if(tx_chan.count == 1) {
                if(tx_chan.bitnum == 0) { // start bit
                    if(tx != 0) {
                        std::cerr << "[UART Tx]: Framing error (start bit)" << std::endl;
                        tx_chan.active_now = false;
                        tx_chan.count = 0;
                        tx_chan.bitnum = 0;
                    } else {
                        tx_chan.count = cycles_per_bit;
                        tx_chan.bitnum += 1;
                    }
                } else if(tx_chan.bitnum < 9) {
                    tx_chan.current_byte |= (tx & 0x1) << (tx_chan.bitnum - 1);
                    tx_chan.bitnum += 1;
                } else if(tx_chan.bitnum == 9) {
                    if(tx != 1) {
                        std::cerr << "[UART Tx]: Framing error (stop bit)" << std::endl;
                    } else {
                        //std::cout << "[UART Tx]: Forwarding Tx byte to server" << std::endl;
                        tx_buf.push(tx_chan.current_byte);
                    }

                    tx_chan.active_now = false;
                    tx_chan.bitnum = 0;
                    tx_chan.count = 0;
                    tx_chan.current_byte = 0;
                }
            } else if(tx_chan.active_now && tx_chan.count == 0) {
                tx_chan.count = cycles_per_bit;
            }

            if(tx_chan.active_now && tx_chan.count > 0) {
                tx_chan.count -= 1;
            }
        }

        tx_chan.prev = tx;
        rx_chan.prev = rx;
        return rx;
    }
};