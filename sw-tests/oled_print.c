#include "pal.h"
#include "interrupt.h"
#include "riscv.h"
#include "fpga.h"

GPIORegBlk *gpio   = (GPIORegBlk *) GPIO0_BASE;
PLICRegBlk *plic   = (PLICRegBlk *) PLIC_BASE;
CLINTRegBlk *clint = (CLINTRegBlk *) CLINT_BASE;

uint32_t interrupt_count = 0;

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

    interrupt_count += 1;

    clear_oled_display();
    oled_print("Interrupt #%d", interrupt_count);
    clear_oled_display();
   
    // PLIC: complete
    plic->cfg[0].claim_complete = int_id;
    asm volatile("csrw mstatus, %0" : : "r"(mstatus_prev));
}

int main() {
    oled_print("OLED print function test string");

    init_oled();

    // Set up GPIO[7] to trigger interrupt on posedge
    gpio->per = 0x80;
    gpio->ier = 0x80;

    // PLIC setup
    plic->enable[0] = 0x1FF;
    for(int i = 1; i <= 8; i++) {
        plic->priority[i] = 0x7;
    }

    clint->mtimecmp[0].l = 0xFFFFFFFF;
    interrupt_enable();

    for (;;) {
        oled_display1("AFTx07 says:");
        oled_display2("Hello World!");
    }

    return 0;
}
