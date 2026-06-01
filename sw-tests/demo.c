#include "pal.h"
#include "interrupt.h"
#include "riscv.h"

GPIORegBlk *gpio    = (GPIORegBlk *) GPIO0_BASE;
PWMRegBlk  *pwm     = (PWMRegBlk *) PWM_BASE;
CLINTRegBlk *clint  = (CLINTRegBlk *) CLINT_BASE;
IOMuxRegBlk *iomux = (IOMuxRegBlk *) IO_MUX_BASE;
PLICRegBlk *plic = (PLICRegBlk *) PLIC_BASE;

void __attribute__((interrupt)) mtime_handler() {
    clint->mtimecmp[0].l = 0xFFFFFFFF;
}

void __attribute__((interrupt)) mswi_handler() {
    clint->msip[0] = 0x0;
}

void __attribute__((interrupt)) mext_handler() {
    uint32_t mstatus_prev;
    asm volatile("csrrw %0, mstatus, %1" : "=r"(mstatus_prev) : "r"(0x0));
    // Interrupt # corresponds to pin #
    // Interrupt claim
    uint32_t int_id = plic->cfg[0].claim_complete;

    gpio->icr = (1 << (int_id-1)); // cleared

    // Flash GPIOs
    unsigned int state = ~(0);
    for (int i = 0; i < 5; i++) {
        gpio->data = state & 0x7F;
        state = ~state;
        for (int j = 0; j < 0x100000; j++);
    }
   
    // PLIC: complete
    plic->cfg[0].claim_complete = int_id;
    asm volatile("csrw mstatus, %0" : : "r"(mstatus_prev));
}

int main() {
    clint->mtimecmp[0].l = 0xFFFFFFFF;

    // iomux->fsel0 = IOM_F0_PWM0_0 | IOM_F0_PWM0_1;  // Configure IO Mux for PWM output

    // PWM setup
    pwm->per0 = 0x1000000;
    pwm->duty0 = 0x900000; // 50% duty cycle (PWM duty off by 1)

    pwm->per1 = 0x20000000;
    pwm->duty1 = 0x2000000; // 1/32 duty cycle

    pwm->ctrl0 = 0x5; // center-aligned, active high, enabled
    pwm->ctrl1 = 0x3; // left-aligned, active low, enabled

    // PLIC setup
    //*PLIC_ENABLE(PLIC_BASE, 1, 0) = 0x1FF;
    plic->enable[0] = 0x1FF;
    for(int i = 1; i <= 8; i++) {
        //*PLIC_PRIORITY(PLIC_BASE, i) = 0x7;
        plic->priority[i] = 0x7;
    }

    // GPIO setup
    // gpio->ddr = 0x7F;
    gpio->ddr = 0xFFFFFFFF;

    // gpio->per = 0x80;
    // gpio->ier = 0x80;

    interrupt_enable();

    unsigned int state = 0;

    for(;;) {
    #ifdef SYNTHESIS
        for (int i = 0; i < 0x80000; i++);
    #endif
        // gpio->data = state & 0x7F;
        gpio->data = (state & 0xFF) | (state << 8);
        state += 1;
    }

    return 0;
}
