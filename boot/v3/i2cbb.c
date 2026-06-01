#include <stdint.h>
#include <stddef.h>

#include "i2cbb.h"


// I2C bit-bang instance
extern i2cbb_t i2ccfg;
static const i2cbb_t *i2c = &i2ccfg;

#define DELAY_HALF 2
#define DELAY_FULL 5

static void i2c_start(void) {
    i2c->set_sda(1);
    i2c->set_scl(1);
    i2c->delay_us(DELAY_FULL);
    i2c->set_sda(0);
    i2c->delay_us(DELAY_FULL);
    i2c->set_scl(0);
}

static void i2c_stop(void) {
    i2c->set_sda(0);
    i2c->set_scl(1);
    i2c->delay_us(DELAY_FULL);
    i2c->set_sda(1);
    i2c->delay_us(DELAY_FULL);
}

static void i2c_write_bit(uint8_t bit) {
    i2c->set_sda(bit);
    i2c->delay_us(DELAY_HALF);
    i2c->set_scl(1);
    i2c->delay_us(DELAY_FULL);
    i2c->set_scl(0);
    i2c->delay_us(DELAY_HALF);
}

static uint8_t i2c_read_bit(void) {
    uint8_t bit = 1;
    i2c->set_sda(1); // Release SDA for input
    i2c->delay_us(DELAY_HALF);
    i2c->set_scl(1);
    i2c->delay_us(DELAY_HALF);
    bit = i2c->read_sda();
    i2c->delay_us(DELAY_HALF);
    i2c->set_scl(0);
    i2c->delay_us(DELAY_HALF);
    return bit;
}

static uint8_t i2c_write_byte(uint8_t data) {
    for (int i = 0; i < 8; i++) {
        i2c_write_bit(data & 0x80);
        data <<= 1;
    }
    return !i2c_read_bit(); // Read ACK, 0 means acknowledged
}

static uint8_t i2c_read_byte(uint8_t ack) {
    uint8_t data = 0;
    for (int i = 0; i < 8; i++) {
        data = (data << 1) | i2c_read_bit();
    }
    i2c_write_bit(!ack); // Send ACK/NACK
    return data;
}

// Public API

uint8_t i2cbb_write(uint8_t address, uint8_t *data, uint16_t length) {
    i2c_start();
    if (!i2c_write_byte(address << 1)) {
        i2c_stop();
        return 0; // NACK on address
    }
    for (uint16_t i = 0; i < length; i++) {
        if (!i2c_write_byte(data[i])) {
            i2c_stop();
            return 0; // NACK on data
        }
    }
    i2c_stop();
    return 1;
}

uint8_t i2cbb_read(uint8_t address, uint8_t *data, uint16_t length) {
    i2c_start();
    // Send device address to bus
    if (!i2c_write_byte((address << 1) | 1)) {
        i2c_stop();
        return 0; // NACK on address
    }
    for (uint16_t i = 0; i < length; i++) {
        data[i] = i2c_read_byte(i < (length - 1)); // ACK for all but last byte
    }
    i2c_stop();
    return 1;
}
