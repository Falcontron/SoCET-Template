#pragma once

#include <stdint.h>

// Define the function pointers for platform-specific functionality
typedef struct {
    void (*set_sda)(uint8_t level);    // Set SDA line (high/low)
    void (*set_scl)(uint8_t level);    // Set SCL line (high/low)
    uint8_t (*read_sda)(void);         // Read SDA line
    void (*delay_us)(uint32_t us);  // Delay function in microseconds
} i2cbb_t;

void i2cbb_init(i2cbb_t *impl);
uint8_t i2cbb_write(uint8_t address, uint8_t *data, uint16_t length);
uint8_t i2cbb_read(uint8_t address, uint8_t *data, uint16_t length);
