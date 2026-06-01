#include "format.h"
#include "pal.h"
#include "riscv.h"
#include <stdint.h>

LIMIT_HARTS(2)

volatile CLINTRegBlk *clint = (CLINTRegBlk *)CLINT_BASE;

extern void __sim_halt();
extern void __sim_wfi();

__attribute__((used)) __attribute__((interrupt)) void mswi_handler() {
    uint32_t mhartid = get_mhartid();
    clint->msip[mhartid] = 0;
    print("hello, hart %d got interrupted\n", mhartid);
    __sim_halt();
}

// Hart0 will enter here
int main() {
    uint32_t mhartid = get_mhartid();
    print("hello from hart %d\n", mhartid);
    clint->mtimecmp[mhartid].h = 0xFFFFFFFF;

    interrupt_enable();
    swi_interrupt_enable();

    // Stall hart 1
    if (mhartid != 0) {
        for (volatile int i = 0; i < 1000; i++) {
            asm("");
        }
    }

    // And trigger a software interrupt
    clint->msip[1] = 1;

    return 0;
}
