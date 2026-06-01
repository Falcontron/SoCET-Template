#include <stdint.h>
#include "utility.h"
#include "format.h"
#include "pal.h"

GPIORegBlk *GPIO    = (GPIORegBlk *)GPIO_BASE;
CLINTRegBlk *CLINT  = (CLINTRegBlk *)CLINT_BASE;
PLICRegBlk *PLIC    = (PLICRegBlk *)PLIC_BASE;

volatile int flag = 0;

const int EXT_DONE      = 0xFF; // 8 GPIO interrupts
const int SW_DONE       = 0x100;
const int TIMER_DONE    = 0x200;

void __attribute__((interrupt)) default_handler() {
    print("Test failed!\n");
    __inf_loop(); // Test failed
}

void __attribute__((interrupt)) m_timer_handler() {
    uint32_t mstatus_prev;
    asm volatile("csrrw %0, mstatus, %1" : "=r"(mstatus_prev) : "r"(0x0));
    flag |= TIMER_DONE;
    print("Timer handler\n");
    CLINT->mtimecmp = 0xFFFFFFFF;
    asm volatile("csrw mstatus, %0" : : "r"(mstatus_prev));
}

void __attribute__((interrupt)) m_sw_handler() {
    uint32_t mstatus_prev;
    asm volatile("csrrw %0, mstatus, %1" : "=r"(mstatus_prev) : "r"(0x0));
    flag |= SW_DONE;
    print("SW Interrupt handler!\n");
    CLINT->msip = 0x0;
    asm volatile("csrw mstatus, %0" : : "r"(mstatus_prev));
}
void __attribute__((interrupt)) m_ext_handler() {
    uint32_t mstatus_prev;
    asm volatile("csrrw %0, mstatus, %1" : "=r"(mstatus_prev) : "r"(0x0));
    // Interrupt # corresponds to pin #
    // Interrupt claim
    uint32_t int_id = PLIC->ccr;
    flag |= (1 << (int_id-1));
    print("Flag = %x\n", flag);

    // GPIO Disable
    GPIO->icr = (1 << (int_id-1)); // cleared
    GPIO->ier &= ~(1 << (int_id-1));
   
    // PLIC: complete
    PLIC->ccr = int_id;
    asm volatile("csrw mstatus, %0" : : "r"(mstatus_prev));
}

void __attribute__((naked)) __attribute__((aligned(4))) handler_dispatch() {
    asm volatile(
        ".option push\n"
        ".option norvc\n"
        "j default_handler\n" // 0
        "j default_handler\n" // 1
        "j default_handler\n" // 2
        "j m_sw_handler\n"    // 3
        "j default_handler\n" // 4
        "j default_handler\n" // 5
        "j default_handler\n" // 6
        "j m_timer_handler\n" // 7
        "j default_handler\n" // 8
        "j default_handler\n" // 9
        "j default_handler\n" // 10
        "j m_ext_handler\n"   // 11
        : : : "memory");
}

int main() {
    CLINT->mtimecmp = 0x2000;
    uint32_t mtvec_value = ((uint32_t)handler_dispatch) | 0x1;
    asm volatile("csrw mstatus, %0" : : "r" (0x8));
    asm volatile("csrw mtvec, %0" : : "r" (mtvec_value));
    asm volatile("csrw mie, %0" : : "r" (0x888));

    // Setup PLIC
    PLIC->ier = 0x1FF;
    PLIC->iprior[0] = 0x7;
    PLIC->iprior[1] = 0x7;
    PLIC->iprior[2] = 0x7;
    PLIC->iprior[3] = 0x7;
    PLIC->iprior[4] = 0x7;
    PLIC->iprior[5] = 0x7;
    PLIC->iprior[6] = 0x7;
    PLIC->iprior[7] = 0x7;

    // setup GPIO (input mode default)
    GPIO->per = 0xFF;
    GPIO->ier = 0xFF;

    print("Triggering SW interrupt!\n");
    CLINT->msip = 0x1;

    while(flag != (TIMER_DONE | SW_DONE | EXT_DONE));

    print("Test passed!\n");
}
