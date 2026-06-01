#include <stdint.h>
#include "pal.h"

int pwm0_test() {
    PWMRegBlk *pwm = (PWMRegBlk *)PWM_BASE;
    IOmuxRegBlk *iomux = (IOmuxRegBlk *)DIG_MUX_BASE;
    
    pwm->per0 = 0x10; // period = 16 clk
    pwm->duty0 = 0x9; // 50% duty cycle (PWM duty off by 1)
    pwm->ctrl0 = 0x5; // center-aligned, active high, enabled

    iomux->Func_Select_Reg_0 = 0x00040000; //Configure Pin9 as PWM0

    for(;;) {
        asm volatile("wfi");
    }
}

int gpio_test() {
    GPIORegBlk *gpio = (GPIORegBlk *)GPIO_BASE;

    IOmuxRegBlk *iomux = (IOmuxRegBlk *)DIG_MUX_BASE;
    gpio->ddr = 0x1;
    gpio->data = 0x1;
    iomux->Func_Select_Reg_0 = 0x00000000; //all gpio

    for(;;) {
        asm volatile("wfi");
    }
}

int spi_test() {
    SPIRegBlk *spi = (SPIRegBlk *)SPI_BASE;
    IOmuxRegBlk *iomux = (IOmuxRegBlk *)DIG_MUX_BASE;
    iomux->Func_Select_Reg_0 = 0x00005500; //configure pin4-7 as spi regs
    spi->brr0 = 0x10;
    spi->txdr0 = 0xAA;
    spi->blr0 = 0x1;
    spi->cr0 = 0xF8007E03;
    for(;;) {
       asm volatile("wfi");
    }
}

int main() {
    gpio_test();
    // pwm0_test();
    // spi_test();
    return 0;
}
