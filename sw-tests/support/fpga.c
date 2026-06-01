#include <stdarg.h>
#include <stdint.h>
#include "fpga.h"
#include "format.h"
#include "pal.h"

GPIORegBlk *gpio_PRINT = (GPIORegBlk *) GPIO0_BASE;

// Printing via bit-banged SPI over GPIO
// GPIO[0] = MISO_IN (currently unused)
// GPIO[1] = MOSI_OUT
// GPIO[2] = SCK
// GPIO[3] = NSS
// Assumes 1602A-OLED (from ECE362)

void wait(int t) {
    for (int i = 0; i < t; i++);
}

static void write_bit(uint32_t val) {
    uint32_t temp = gpio_PRINT->data;
    if (val) {
        gpio_PRINT->data = (temp & ~0x4) | 0x2;
        wait(0x10);
        gpio_PRINT->data = (temp | 0x4) | 0x2;
        wait(0x10);
        gpio_PRINT->data = (temp & ~0x4) | 0x2;
    } else {
        gpio_PRINT->data = (temp & ~0x4) & ~0x2;
        wait(0x10);
        gpio_PRINT->data = (temp | 0x4) & ~0x2;
        wait(0x10);
        gpio_PRINT->data = (temp & ~0x4) & ~0x2;
    }
}

static void oled_cmd(uint32_t data) {
    gpio_PRINT->data &= ~(0x8);  // SS low
    for (int i = 9; i >= 0; i--) {
        write_bit((data >> i) & 0x1);
    }
    gpio_PRINT->data |= 0x8;  // SS high
    wait(0x400);
}

static void oled_data(uint32_t data) {
    oled_cmd(data | 0x200);
}

void clear_oled_display() {
    oled_cmd(0x1);
}

void init_oled() {
    gpio_PRINT->ddr &= 0xf1;  // ensures GPIO[7:4] and GPIO[0] modes are not modified
    gpio_PRINT->ddr |= 0x0e;
    gpio_PRINT->data |= 0x8;  // SS high

    wait(0x10000);
    oled_cmd(0x38);
    oled_cmd(0x08);
    oled_cmd(0x01);
    wait(0x10000);
    oled_cmd(0x06);
    oled_cmd(0x02);
    oled_cmd(0x0c);
}

void oled_display1(const char *str) {
    oled_cmd(0x02);
    int i = 0;
    while ((*str != '\0') && (i < 16)) {
        if (*str == '\n') {
            oled_data(' ');
        } else {
            oled_data(*str);
        }
        str++;
        i++;
    }
}

void oled_display2(const char *str) {
    oled_cmd(0xc0);
    int i = 0;
    while ((*str != '\0') && (i < 16)) {
        if (*str == '\n') {
            oled_data(' ');
        } else {
            oled_data(*str);
        }
        str++;
        i++;
    }
}

void __attribute__((noinline))
oled_print(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    char print_buf[32] = {0};
    vformat(fmt, print_buf, args);
    va_end(args);

    init_oled();
    oled_display1(print_buf);
    oled_display2(print_buf+16);

    wait(0x101000);  // wait some time to read print statement
}
