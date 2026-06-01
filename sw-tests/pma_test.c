#include <stdint.h>
#include "format.h"
#include "pal.h"
#include "riscv.h"

#define PMA_REG_BASE 0xBC0
#define PMA_ROM 0x1BF1
#define PMA_RAM 0x3BF1
#define PMA_IO  0x3B30

#define INSN_FAULT 1
#define EXC_ILLEGAL_INSN 2
#define LOAD_FAULT 5
#define STORE_FAULT 7

volatile unsigned cnt = 1;
volatile uint32_t saved_pc;

void __attribute__((interrupt)) exception_handler() {
    uint32_t mcause = get_mcause();
    uint32_t mepc = get_mepc();
    uint32_t mtval = get_mtval();


    print("Fault %d: %s @ %x (to %x)\n", cnt, exception_names[mcause], mepc, mtval);
    cnt += 1;

    if(mcause == EXC_ILLEGAL_INSN) {
        uint32_t mpp_m = (0x3 << 11);
        // Make MPP = "M", mret will return to M-mode
        asm volatile("csrs mstatus, %0" : : "r"(mpp_m));
    }

    // fix return address
    if (mcause == INSN_FAULT) {
        mepc = saved_pc + 18;
    } else if (mcause == LOAD_FAULT) {
        mepc += 2;
    } else {
        mepc += 4;
    }
    asm volatile("csrw mepc, %0" : : "r"(mepc));
}

int main() {
    // PMA default:
    // Tagged as RAM for 0x00000000 - 0x7FFFFFFF
    // Tagged as IO  for 0x80000000 - 0xFFFFFFFF

    print("sw @0x80000000, IO - OK\n");
    *((volatile uint32_t *)(0x80000000)) = 0;

    print("jr to 0x98760004, IO - ILLEGAL\n");
    asm volatile("auipc %0, 0" : "=r"(saved_pc));
    asm volatile("jr %0" : : "r"(0x98760004) : "memory");

    asm volatile("csrw 0xBC8, %0" : : "r"((PMA_RAM << 16) | PMA_ROM));  // change to ROM

    print("sw @0x80000000, now ROM - ILLEGAL\n");
    *((volatile uint32_t *)(0x80000000)) = 0;

    return 0;
}
