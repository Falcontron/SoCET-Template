#include "display.h"
#include "i2cbb.h"
#include "platform.h"
#include <stdint.h>

// commands
#define LCD_CLEARDISPLAY 0x01
#define LCD_RETURNHOME 0x02
#define LCD_ENTRYMODESET 0x04
#define LCD_DISPLAYCONTROL 0x08
#define LCD_CURSORSHIFT 0x10
#define LCD_FUNCTIONSET 0x20
#define LCD_SETCGRAMADDR 0x40
#define LCD_SETDDRAMADDR 0x80

// flags for display entry mode
#define LCD_ENTRYRIGHT 0x00
#define LCD_ENTRYLEFT 0x02
#define LCD_ENTRYSHIFTINCREMENT 0x01
#define LCD_ENTRYSHIFTDECREMENT 0x00

// flags for display on/off control
#define LCD_DISPLAYON 0x04
#define LCD_DISPLAYOFF 0x00
#define LCD_CURSORON 0x02
#define LCD_CURSOROFF 0x00
#define LCD_BLINKON 0x01
#define LCD_BLINKOFF 0x00

// flags for display/cursor shift
#define LCD_DISPLAYMOVE 0x08
#define LCD_CURSORMOVE 0x00
#define LCD_MOVERIGHT 0x04
#define LCD_MOVELEFT 0x00

// flags for function set
#define LCD_8BITMODE 0x10
#define LCD_4BITMODE 0x00
#define LCD_2LINE 0x08
#define LCD_1LINE 0x00
#define LCD_5x10DOTS 0x04
#define LCD_5x8DOTS 0x00

// flags for backlight control
#define LCD_BACKLIGHT 0x08
#define LCD_NOBACKLIGHT 0x00

#define En 0x00000100 // Enable bit
#define Rw 0x00000010 // Read/Write bit
#define Rs 0x00000001 // Register select bit

#define DISPLAY_ADDR 0x27

void expander_write(uint8_t data) {
    i2cbb_write(DISPLAY_ADDR, &data, 1);
}

void pulse_enable(uint8_t data) {
    expander_write(data | En);
    delay_us(1);
    expander_write(data & ~En);
}

void write_4bit(uint8_t data) {
    expander_write(data);
    pulse_enable(data);
}

void send(uint8_t data, uint8_t mode) {
    uint8_t hi = data & 0xf0;
    uint8_t lo = (data << 4) & 0xf0;
    write_4bit(hi | mode);
    write_4bit(lo | mode);
}

void command(uint8_t data) {
    send(data, 0);
}

void display(uint8_t data) {
    command(data | LCD_DISPLAYCONTROL | LCD_DISPLAYON);
}

void clear() {
    command(LCD_CLEARDISPLAY);
    delay_us(2000);
}

void home() {
    command(LCD_RETURNHOME);
    delay_us(2000);
}

// Steps:
// 1. Clear display
// 2. Funtion set:
//    DL = 1; 8-bit interface data
//    N = 0; 1-line display
//    F = 0; 5x8 dot character font
// 3. Display on/off control:
//    D = 0; Display off
//    C = 0; Cursor off
//    B = 0; Blinking off
// 4. Entry mode set:
//    I/D = 1; Increment by 1
//    S = 0; No shift
void init_display() {
    delay_us(50);

    expander_write(LCD_BACKLIGHT);
    delay_us(1000);

    write_4bit(0x3 << 4);
    delay_us(45000);

    write_4bit(0x3 << 4);
    delay_us(45000);

    write_4bit(0x3 << 4);
    delay_us(45000);

    write_4bit(0x2 << 4);

    uint8_t disp = LCD_4BITMODE | LCD_1LINE | LCD_5x8DOTS;
    command(LCD_FUNCTIONSET | disp);

    disp = LCD_DISPLAYON | LCD_CURSOROFF | LCD_BLINKOFF;
    display(disp);

    clear();

    disp = LCD_ENTRYLEFT | LCD_ENTRYSHIFTDECREMENT;
    command(LCD_ENTRYMODESET | disp);

    home();
}

void write(uint8_t value) {
    send(value, Rs);
}

void print(char *str) {
    while (*str) {
        write(*str);
    }
}
