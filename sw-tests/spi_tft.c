#include "pal.h"
#include "interrupt.h"
#include "format.h"
#include "fpga.h"

#include <stdint.h>

// SPI Control Register Fields (flipped from documentation)
#define SPI_TX_START (1<<31)
#define SPI_MODE (1<<30)
#define SPI_CLK_POL (1<<29)
#define SPI_CLK_PHASE (1<<28)
#define SPI_SSOE (1<<27)
#define SPI_BIT_ORDER (1<<26)
#define SPI_MODF_EN (1<<25)
#define SPI_RX_WM (0x1f<<20)
#define SPI_TX_WM (0x1f<<15)
#define SPI_TC_IE (1<<14)
#define SPI_RXWM_IE (1<<13)
#define SPI_TXWM_IE (1<<12)
#define SPI_RXF_IE (1<<11)
#define SPI_TXE_IE (1<<10)
#define SPI_MODF_IE (1<<9)
// SPI Status Register Fields
#define SPI_SR_COMPLETE (1<<31)
#define SPI_SR_TXE (1<<27)

SPIRegBlk *spi = (SPIRegBlk *) SPI_BASE;
GPIORegBlk *gpio = (GPIORegBlk *) GPIO0_BASE;
IOMuxRegBlk *iomux = (IOMuxRegBlk *) IO_MUX_BASE;

// For use with 2.2in SPI TFT LCD ILI9341
// Uses GPIO[7] as D/CX pin, GPIO[0] as reset pin, and GPIO[4] as CS pin - does not interfere with OLED print routine
#define LCD_W 240
#define LCD_H 320
#define DC_PIN 7
#define DC_HIGH do { gpio->data |=  (1<<DC_PIN); } while(0)
#define DC_LOW  do { gpio->data &= ~(1<<DC_PIN); } while(0)
#define RESET_PIN 0
#define RESET_HIGH do { gpio->data |=  (1<<RESET_PIN); } while(0)
#define RESET_LOW  do { gpio->data &= ~(1<<RESET_PIN); } while(0)
#define CS_PIN 4
#define CS_HIGH do { gpio->data |=  (1<<CS_PIN); } while(0)
#define CS_LOW  do { gpio->data &= ~(1<<CS_PIN); } while(0)

static void lcd_select(uint32_t val) {
    if (val) {
        CS_LOW;
    } else {
        while (!(spi->sr0 & SPI_SR_TXE));
        CS_HIGH;
    }
}

static void lcd_reset(void) {
    RESET_LOW;
    wait(0x200000);
    RESET_HIGH;
    wait(0x200000);
}

static void lcd_reg_select(uint32_t val) {
    if (val == 1) {  // select regs
        DC_LOW;
    } else {  // select data
        DC_HIGH;
    }
}

void write_byte(uint8_t data) {
    while (!(spi->sr0 & SPI_SR_TXE));
    spi->txdr0 = data;
    spi->cr0 |= SPI_TX_START;
}

void lcd_w_reg(uint8_t data) {
    lcd_reg_select(1);
    write_byte(data);
}

void lcd_w_data(uint8_t data) {
    lcd_reg_select(0);
    write_byte(data);
}

void lcd_write_to_reg(uint8_t reg, uint8_t value) {
    lcd_w_reg(reg);
    lcd_w_data(value);
}

void init_lcd() {
    lcd_select(1);
    
    lcd_reset();
    lcd_w_reg(0xCF);
    lcd_w_data(0x00);
    lcd_w_data(0xD9);   // C1
    lcd_w_data(0X30);
    lcd_w_reg(0xED);
    lcd_w_data(0x64);
    lcd_w_data(0x03);
    lcd_w_data(0X12);
    lcd_w_data(0X81);
    lcd_w_reg(0xE8);
    lcd_w_data(0x85);
    lcd_w_data(0x10);
    lcd_w_data(0x7A);
    lcd_w_reg(0xCB);
    lcd_w_data(0x39);
    lcd_w_data(0x2C);
    lcd_w_data(0x00);
    lcd_w_data(0x34);
    lcd_w_data(0x02);
    lcd_w_reg(0xF7);
    lcd_w_data(0x20);
    lcd_w_reg(0xEA);
    lcd_w_data(0x00);
    lcd_w_data(0x00);
    lcd_w_reg(0xC0);    // Power control
    lcd_w_data(0x21);   // VRH[5:0]  //1B
    lcd_w_reg(0xC1);    // Power control
    lcd_w_data(0x12);   // SAP[2:0];BT[3:0] //01
    lcd_w_reg(0xC5);    // VCM control
    lcd_w_data(0x39);   // 3F
    lcd_w_data(0x37);   // 3C
    lcd_w_reg(0xC7);    // VCM control2
    lcd_w_data(0XAB);   // B0
    lcd_w_reg(0x36);    // Memory Access Control
    lcd_w_data(0x48);
    lcd_w_reg(0x3A);
    lcd_w_data(0x55);
    lcd_w_reg(0xB1);
    lcd_w_data(0x00);
    lcd_w_data(0x1B);   // 1A
    lcd_w_reg(0xB6);    // Display Function Control
    lcd_w_data(0x0A);
    lcd_w_data(0xA2);
    lcd_w_reg(0xF2);    // 3Gamma Function Disable
    lcd_w_data(0x00);
    lcd_w_reg(0x26);    // Gamma curve selected
    lcd_w_data(0x01);

    lcd_w_reg(0xE0);    // Set Gamma
    lcd_w_data(0x0F);
    lcd_w_data(0x23);
    lcd_w_data(0x1F);
    lcd_w_data(0x0B);
    lcd_w_data(0x0E);
    lcd_w_data(0x08);
    lcd_w_data(0x4B);
    lcd_w_data(0XA8);
    lcd_w_data(0x3B);
    lcd_w_data(0x0A);
    lcd_w_data(0x14);
    lcd_w_data(0x06);
    lcd_w_data(0x10);
    lcd_w_data(0x09);
    lcd_w_data(0x00);
    lcd_w_reg(0XE1);    // Set Gamma
    lcd_w_data(0x00);
    lcd_w_data(0x1C);
    lcd_w_data(0x20);
    lcd_w_data(0x04);
    lcd_w_data(0x10);
    lcd_w_data(0x08);
    lcd_w_data(0x34);
    lcd_w_data(0x47);
    lcd_w_data(0x44);
    lcd_w_data(0x05);
    lcd_w_data(0x0B);
    lcd_w_data(0x09);
    lcd_w_data(0x2F);
    lcd_w_data(0x36);
    lcd_w_data(0x0F);
    lcd_w_reg(0x2B);
    lcd_w_data(0x00);
    lcd_w_data(0x00);
    lcd_w_data(0x01);
    lcd_w_data(0x3f);
    lcd_w_reg(0x2A);
    lcd_w_data(0x00);
    lcd_w_data(0x00);
    lcd_w_data(0x00);
    lcd_w_data(0xef);
    lcd_w_reg(0x11);    // Exit Sleep
    wait(2400000);      // Wait 120 ms
    lcd_w_reg(0x29);    // Display on

    // Set to horizontal direction
    lcd_write_to_reg(0x36, (1<<3)|(0<<6)|(0<<7));  //BGR==1,MY==0,MX==0,MV==0

    lcd_select(0);
}

void lcd_write_16_start(void) {
    lcd_reg_select(0);
    while (!(spi->sr0 & SPI_SR_COMPLETE));  // wait for previous tx to be sent
    spi->blr0 = 2;  // 2 byte packets
}

void lcd_write_16_end(void) {
    while (!(spi->sr0 & SPI_SR_COMPLETE));  // wait for previous tx to be sent
    spi->blr0 = 1;  // 1 byte packets
}

void lcd_w_data_16(uint16_t data) {
    while (!(spi->sr0 & SPI_SR_TXE));
    spi->txdr0 = data >> 8;
    spi->txdr0 = data & 0xff;
    spi->cr0 |= SPI_TX_START;
    // write_byte(data >> 8);
    // write_byte(data);
    wait(0x10);  // requirement as there is no 'BUSY' flag
}

void lcd_set_window(uint16_t xStart, uint16_t yStart, uint16_t xEnd, uint16_t yEnd) {
    lcd_w_reg(0x2a);  // 'set x' command
    lcd_w_data(xStart >> 8);
    lcd_w_data(0x00ff & xStart);
    lcd_w_data(xEnd >> 8);
    lcd_w_data(0x00ff & xEnd);

    lcd_w_reg(0x2b);  // 'set y' command
    lcd_w_data(yStart >> 8);
    lcd_w_data(0x00ff & yStart);
    lcd_w_data(yEnd >> 8);
    lcd_w_data(0x00ff & yEnd);

    lcd_w_reg(0x2c);  // 'write RAM' command
}

void lcd_fill_color(uint16_t color) {
    lcd_select(1);

    lcd_set_window(0, 0, LCD_W-1, LCD_H-1);
    lcd_write_16_start();
    for (int i = 0; i < LCD_H; i++) {
        for (int m = 0; m < LCD_W; m++) {
            lcd_w_data_16(color);
        }
    }
    lcd_write_16_end();

    lcd_select(0);
}

int main() {
    print("setting up...\n");
    
    // IO Mux setup
    iomux->fsel0 = IOM_F0_SPI_SCK | IOM_F0_SPI_MOSI;  // SPI SCK and MOSI

    // GPIO setup
    gpio->ddr |= (1 << DC_PIN) | (1 << RESET_PIN) | (1 << CS_PIN);  // will use GPIO[6:4]

    // SPI setup
    spi->cr0 = SPI_MODE | SPI_SSOE | SPI_BIT_ORDER;
    spi->blr0 = 1;
    spi->brr0 = 0x1;

    spi->txdr0 = 0xff;
    spi->cr0 |= SPI_TX_START;

    lcd_select(0);
    lcd_reset();
    lcd_reg_select(0);
    init_lcd();

    print("start coloring\n");

    lcd_fill_color(0x001F);  // blue

    print("done coloring\n");

    return 0;
}
