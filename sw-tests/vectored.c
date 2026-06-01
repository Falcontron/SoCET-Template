#include <stdint.h>
#include "format.h"
#include "pal.h"
#include "riscv.h"

GPIORegBlk *GPIO    = (GPIORegBlk *)GPIO0_BASE;
CLINTRegBlk *CLINT  = (CLINTRegBlk *)CLINT_BASE;
PLICRegBlk *PLIC = (PLICRegBlk *)PLIC_BASE;

volatile unsigned flag = 0;

const unsigned EXT_DONE     = 0x0FF;
const unsigned SW_DONE      = 0x100;
const unsigned TIMER_DONE   = 0x200;
const unsigned ECALL_DONE   = 0x400;
const unsigned UNEXPECTED_INT = 0x800;
const unsigned FLAG_PREFIX_MASK = 0x7FF; // exclude unexpected

void __attribute__((interrupt)) default_handler() {
    print("Unhandled interrupt.");
    flag |= 0x800;
}

void __attribute__((interrupt)) exception_handler() {
    const uint32_t EXC_ECALL = 11;

    uint32_t mcause = get_mcause();
    if(mcause == EXC_ECALL) {
        uint32_t mepc_value;
        print("ECALL\n");
        // Bump mepc
        asm volatile(
            "csrr %0, mepc"
            : "=r"(mepc_value));
        mepc_value += 4;
        asm volatile(
            "csrw mepc, %0"
            : : "r"(mepc_value));
    } else {
        uint32_t mtval = get_mtval();
        uint32_t mepc = get_mepc();
        print("Unexpected EXC!\n");
        print("\tCause: %x\n", mcause);
        print("\tValue: %x\n", mtval);
        print("\tEPC: %x\n", mepc);
        flag |= 0x800;
    }

}

void __attribute__((interrupt)) mtime_handler() {
    flag |= TIMER_DONE;
    print("IRQ: mtime\n");
    CLINT->mtimecmp[0].l = 0xFFFFFFFF;
}

void __attribute__((interrupt)) mswi_handler() {
    flag |= SW_DONE;
    print("IRQ: swi\n");
    CLINT->msip[0] = 0x0;
}

void __attribute__((interrupt)) mext_handler() {
    uint32_t int_id = PLIC->cfg[0].claim_complete;//*PLIC_CLAIM_COMPLETE(PLIC_BASE, 0);
    flag |= (1 << (int_id-1));


    GPIO->ier &= ~(1 << (int_id-1));
    GPIO->icr = (1 << (int_id-1));

    //*PLIC_CLAIM_COMPLETE(PLIC_BASE, 0) = int_id;
    PLIC->cfg[0].claim_complete = int_id;

    print("Ext #%d\n", int_id);
}

int main() {
    CLINT->mtimecmp[0].l += 0x2000;
    //*PLIC_ENABLE(PLIC_BASE, 1, 0) = 0x1FF; // enable GPIO interrupts
    PLIC->enable[0] = 0x1FF;
    for(int i = 1; i <= 8; i++) {
        //*PLIC_PRIORITY(PLIC_BASE, i) = 0x7;
        PLIC->priority[i] = 0x7;
    }

    GPIO->per = 0xFF;
    GPIO->ier = 0xFF;

    interrupt_enable();

    // SW Interrupt
    CLINT->msip[0] = 0x1;

    // Ecall
    asm volatile("ecall");

    while((flag & FLAG_PREFIX_MASK) != (TIMER_DONE | SW_DONE | EXT_DONE));

    if(flag & UNEXPECTED_INT) {
        print("Unexpected interrupt!\n");
    }
}
