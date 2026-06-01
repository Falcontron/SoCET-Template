#include "pal.h"
#include "format.h"
#include "riscv.h"

#include <stdint.h>

TimerRegBlk *timer = (TimerRegBlk *) TIMER_BASE;
IOMuxRegBlk *iomux = (IOMuxRegBlk *) IO_MUX_BASE;
CLINTRegBlk *clint = (CLINTRegBlk *) CLINT_BASE;
PLICRegBlk *plic = (PLICRegBlk *) PLIC_BASE;

uint32_t interrupted = 0;
void __attribute__((interrupt)) mext_handler() {
    uint32_t cause = plic->cfg[0].claim_complete;
    timer->tcr &= ~TIM_TCR_EN;
    print("Interrupted!\n");
    print("Cause: %d\n", cause);
    interrupted = 1;
    plic->cfg[0].claim_complete = cause;  // claim interrupt
}

int main() {
    // enable interrupt for CC channel 5
    plic->enable[1] = 0xFFFFFFFF;
    plic->priority[44] = 0x7;

    clint->mtimecmp[0].l = 0xFFFFFFFF;
    interrupt_enable();

    // Configure IO mux for timer CC output
    iomux->fsel1 = IOM_F1_TIM0_CC0 | IOM_F1_TIM0_CC1 | IOM_F1_TIM0_CC2 |
                   IOM_F1_TIM0_CC3 | IOM_F1_TIM0_CC4 | IOM_F1_TIM0_CC5;

    // Configure timer
    timer->tpsc = 0x100;
    timer->tarr = 0xffff;
    // Configure CC channels 0-5
    timer->tccr[0] = 0x1000;
    timer->tccmr[0] = TIM_TCCMR_EN | TIM_TCCMR_OUTPUT | TIM_TCCMR_MATCH_HI;
    timer->tccr[1] = 0x2000;
    timer->tccmr[1] = TIM_TCCMR_EN | TIM_TCCMR_OUTPUT | TIM_TCCMR_TOGGLE;
    timer->tccr[2] = 0x4000;
    timer->tccmr[2] = TIM_TCCMR_EN | TIM_TCCMR_OUTPUT | TIM_TCCMR_FORCE_HI;
    timer->tccr[3] = 0x8000;
    timer->tccmr[3] = TIM_TCCMR_EN | TIM_TCCMR_OUTPUT | TIM_TCCMR_PWM1;
    timer->tccr[4] = 0x4000;
    timer->tccmr[4] = TIM_TCCMR_EN | TIM_TCCMR_OUTPUT | TIM_TCCMR_PWM2;
    timer->tccr[5] = 0x2000;
    timer->tccmr[5] = TIM_TCCMR_EN | TIM_TCCMR_RISING | TIM_TCCMR_TI1_IN | TIM_TCCMR_IRQ_EN;

    timer->tcr = TIM_TCR_EN;
    
    while (!interrupted);

    return 0;
}
