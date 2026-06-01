#include "format.h"
#include "pal.h"
#include "interrupt.h"
#include "riscv.h"
#include "fpga.h"

PWMRegBlk *pwm     = (PWMRegBlk *) PWM_BASE;
PLICRegBlk *plic   = (PLICRegBlk *) PLIC_BASE;
CLINTRegBlk *clint = (CLINTRegBlk *) CLINT_BASE;
IOMuxRegBlk *iomux = (IOMuxRegBlk *) IO_MUX_BASE;

uint32_t period = 0;

void __attribute__((interrupt)) mtime_handler() {
    print("T: %x", period);
    clint->mtimecmp[0].l += 0x200000;

    period = period + 0x8000;
    if (period > 0x400000) {
        period = 0xA0000;
    }

    pwm->per0 = period;
    pwm->duty0 = period / 2;
}

void __attribute__((interrupt)) mswi_handler() {
    clint->msip[0] = 0x0;
}

void __attribute__((interrupt)) mext_handler() {
    uint32_t mstatus_prev;
    asm volatile("csrrw %0, mstatus, %1" : "=r"(mstatus_prev) : "r"(0x0));
    // Interrupt claim
    uint32_t int_id = plic->cfg[0].claim_complete;

    // PLIC: complete
    plic->cfg[0].claim_complete = int_id;
    asm volatile("csrw mstatus, %0" : : "r"(mstatus_prev));
}

int main() {
    clint->mtimecmp[0].l += 0x200000;

    iomux->fsel0 = IOM_F0_PWM0_0 | IOM_F0_PWM0_1;

    period = 0xA0000;
    pwm->per0 = period;
    pwm->duty0 = period / 2;
    pwm->ctrl0 = 0x1;

    interrupt_enable();

    for (;;);

    return 0;
}
