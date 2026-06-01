#include <stdint.h>
#include <stdarg.h>

#include "format.h"
#include "pal.h"
#include "riscv.h"

#define INSN_FAULT 1
#define LOAD_FAULT 5
#define STORE_FAULT 7

volatile unsigned cnt = 1;
volatile unsigned fail = 0;
volatile unsigned flag = 0;

void __attribute__((interrupt)) __attribute__((aligned(4))) handler() {
    uint32_t cause;
    uint32_t addr;
    uint32_t mepc_value;

    asm volatile("csrr %0, mcause" : "=r"(cause));
    asm volatile("csrr %0, mtval" : "=r"(addr));


    print("Fault %d: %s @ %x\n", cnt, exception_names[cause], addr);

    cnt += 1;

    asm volatile("csrr %0, mepc" : "=r"(mepc_value));
    if(cause != INSN_FAULT) {
        mepc_value += 4;
    } else {
        flag = 1;
        if (cnt == 4) {
            fail = 0;
        } else {
            fail = 1;
        }
        // get address of main from mscratch reg
        asm volatile("csrr %0, mscratch" : "=r"(mepc_value));
        mepc_value += 4;
    }
    asm volatile("csrw mepc, %0" : : "r"(mepc_value));
}

int main() {
    if (flag) return fail;

    uint32_t mtvec_value = (uint32_t) handler;

    asm volatile("csrw mtvec, %0" : : "r"(mtvec_value));

    // save address of main to mscratch reg (for use after illegal instruction)
    asm volatile("csrw mscratch, %0" : : "r"((uint32_t) main));

    // try to fault on data load
    asm volatile(".option norvc");
    print("LW @0x4\n");
    uint32_t x = *(volatile uint32_t *)(0x200000);

    // try to fault on data store
    print("SW @0xFFFFFFFC\n");
    *((volatile uint32_t *)(0xFFFFFFFC)) = 0;

    // try to fault on insn
    print("JR to 0x0\n");
    asm volatile("jr %0" : : "r"(0x80005000) : "memory");

    __builtin_unreachable();
}
