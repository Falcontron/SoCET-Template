#include <stdint.h>
#include <stdbool.h>

#include "riscv.h"
#include "pal.h"
#include "format.h"

CLINTRegBlk *clint = (CLINTRegBlk *)CLINT_BASE;
TimerRegBlk* timer = (TimerRegBlk *)TIMER_BASE;

volatile bool timer_interrupted = false;

void __attribute__((interrupt)) mext_handler() {
    uint32_t cause = *PLIC_CLAIM_COMPLETE(PLIC_BASE, 0);
    timer->tcr = 0;
    *PLIC_CLAIM_COMPLETE(PLIC_BASE, 0) = cause;
    print("Handler:\n");
    print("\tCause: %d\n", cause);
    timer_interrupted = true;
}

void enable_timer(TimerRegBlk* timer) {
    timer->tcr = TIM_TCR_EN; // Enable timer
    timer->tcr |= TIM_TCR_IRQ_EN; // Enable irq for timer
    timer->tpsc = 0x0; //no prescale
    timer->tarr = 0x0000ffff; // max reload value
    timer->tccmr[0] = 0x0; // capture/compare disabled
    timer->tccr[0] = 0x0; //
}
int main() {
    // setup PLIC
    *PLIC_ENABLE(PLIC_BASE, 1, 0) = 0xFFFFFFFF;
    *PLIC_PRIORITY(PLIC_BASE, 47) = 0x7;
    // set CLINT so that no timer interrupt happens
    clint->mtimecmp[0].l = 0xFFFFFFFF;

    // global interrupt enable
    interrupt_enable();

    // Fence -- flush caches
    asm volatile("fence.i" : : : "memory");

    enable_timer(timer);

    // wait for interrupt
    while(!timer_interrupted) {
        print("TCNT: %d\n", timer->tcnt);
        asm volatile("wfi");
    }
    
    return 0;
}
