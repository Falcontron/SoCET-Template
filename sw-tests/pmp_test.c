#include <stdint.h>
#include "format.h"
#include "pal.h"
#include "riscv.h"

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
        mepc = saved_pc + 16;
    } else if (mcause == LOAD_FAULT) {
        mepc += 2;
    } else {
        mepc += 4;
    }
    asm volatile("csrw mepc, %0" : : "r"(mepc));
}

int main() {
    uint32_t x;

    // Allow user to RWX RAM block and use special address for printing
    asm volatile("csrw pmpaddr0, %0" : : "r"(0x8400 >> 2) : "memory");  // OFF (bottom of range)
    asm volatile("csrw pmpaddr1, %0" : : "r"(0x18400 >> 2) : "memory");  // TOR RAM (RWX) 0x18400
    asm volatile("csrw pmpaddr2, %0" : : "r"(0xB0000000 >> 2) : "memory");  // magic addr for printing - NA4 (8B) RW
    asm volatile("csrw pmpcfg0, %0" : : "r"(0x130f00));

    asm volatile("csrw pmpaddr4, %0" : : "r"(GPIO0_BASE >> 2) : "memory");  // NA4 no RWX
    asm volatile("csrw pmpaddr5, %0" : : "r"(PWM_BASE >> 2) : "memory");  // NAPOT (8B) R-only
    asm volatile("csrw pmpcfg1, %0" : : "r"(0x1910));
    asm volatile("csrw pmpaddr11, %0" : : "r"((SPI_BASE >> 2) | 0x1) : "memory");  // NAPOT (16B) RW + L
    asm volatile("csrw pmpcfg2, %0" : : "r"(0x9b000000));

    // All should pass - not checked in M mode
    *((volatile uint32_t *)(0x80000000)) = 0;
    x = *((volatile uint32_t *)(0x80000004));
    *((volatile uint32_t *)(0x80001004)) = 0;
    x = *((volatile uint32_t *)(0x80001004));
    *((volatile uint32_t *)(0x8000400c)) = 0;
    x = *((volatile uint32_t *)(0x80004008));
    *((volatile uint32_t *)(0x80004010)) = 0;

    enter_user_mode();  // PMP checks are only done in S/U modes

    print("sw @0x80000000 - ILLEGAL\n");
    *((volatile uint32_t *)(0x80000000)) = 0;
    print("lw @0x80000000 - ILLEGAL\n");
    x = *((volatile uint32_t *)(0x80000004));

    print("sw @0x80001004 - ILLEGAL\n");
    *((volatile uint32_t *)(0x80001004)) = 0;
    print("lw @0x80001004 - OK\n");
    x = *((volatile uint32_t *)(0x80001004));

    print("sw @0x8000400c - OK\n");
    *((volatile uint32_t *)(0x8000400c)) = 0;
    print("lw @0x80004008 - OK\n");
    x = *((volatile uint32_t *)(0x80004008));
    print("sw @0x80004010 - ILLEGAL\n");
    *((volatile uint32_t *)(0x80004010)) = 0;

    print("jr to 0x700ff000 - ILLEGAL\n");
    asm volatile("auipc %0, 0" : "=r"(saved_pc));
    asm volatile("jr %0" : : "r"(0x700ff000) : "memory");

    print("jr to 0xb0000000 - ILLEGAL\n");
    asm volatile("auipc %0, 0" : "=r"(saved_pc));
    asm volatile("jr %0" : : "r"(0xb0000000) : "memory");

    print("jr to pc + 4 - OK\n");
    asm volatile("auipc %0, 0" : "=r"(saved_pc));
    saved_pc += 40;
    asm volatile("jr %0" : : "r"(saved_pc) : "memory");
    print("SHOULD NOT PRINT!\n");

    return 0;
}
