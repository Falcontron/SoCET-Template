#include <stdint.h>
#include <stddef.h>
#include <stdnoreturn.h>

#include "i2cbb.h"
#include "platform.h"

const i2cbb_t i2ccfg = {
    .set_sda = set_sda,
    .set_scl = set_scl,
    .read_sda = read_sda,
    .delay_us = delay_us
};

int main() {
    uint8_t *RAM_PTR = (uint8_t *)0x8400;
    uint8_t addr[2] = {0};

    // If we request SRAM boot, jump to it
    if (read_pin(2)) {
        asm volatile ("j 0x20000");
    }

    // Read entire 4KB EEPROM
    i2cbb_write(0x50, addr, 2);
    for (int i = 0; i < 128; i++) {
        i2cbb_read(0x50, &RAM_PTR[i*32], 32);
    }

    while (1) {
        asm volatile ("j 0x8400");
    }

    return 0;
}
