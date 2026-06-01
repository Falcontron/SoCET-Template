#include <stdint.h>

#include "riscv.h"
#include "format.h"

volatile uint32_t flag = 1;

void __attribute__((interrupt)) exception_handler() {
    const uint32_t EXC_ILLEGAL_INSN = 0x2;
    uint32_t mcause = get_mcause();
    uint32_t mepc = get_mepc();
    if(mcause == EXC_ILLEGAL_INSN) {
        flag = 0;
        uint32_t mpp_m = (0x3 << 11);
        // Make MPP = "M", mret will return to M-mode
        asm volatile("csrs mstatus, %0" : : "r"(mpp_m));
    }

    // fix return address
    mepc += 4;
    asm volatile("csrw mepc, %0" : : "r"(mepc));
}

int main() {
    // Priv. code can execute
    asm volatile("csrw mtval, 0");
    enter_user_mode();

    // Unpriv. code cannot exec priv. insn
    asm volatile("csrw mtval, 0");

    return flag;
}