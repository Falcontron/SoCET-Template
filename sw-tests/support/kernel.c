#include <stdint.h>
#include <stdnoreturn.h>
#include <assert.h>

#include "interrupt.h"
#include "format.h"

extern noreturn void __sim_halt();
extern int main();

// this symbol must be overridden for tests
// that need multiple harts. you may use the provided
// macro from riscv.h
__attribute__((weak)) uint32_t _femtokernel_test_max_hart = 1;

noreturn void panic(const char *msg) {
    print("Panic: %s, exiting...\n", msg);

    __sim_halt();
}

void print_statistics(uint32_t cycle_start, uint32_t cycle_end, uint32_t inst_start, uint32_t inst_end) {
    uint32_t elapsed_cycles = cycle_end - cycle_start;
    uint32_t elapsed_inst = inst_end - inst_start;

    kprint("%d Instructions in %d cycles\n", elapsed_inst, elapsed_cycles);
}

noreturn void kmain() {
    uint32_t mtvec_value = (uint32_t)(handler_dispatch) | 0x1;
    // Setup handler
    kprint("Setting up CSRs for interrupts and PMP\n");
    asm volatile("csrw mtvec, %0" : : "r"(mtvec_value));
    asm volatile("csrw mie, %0" : : "r"(0x888));
    //asm volatile("csrw mstatus, %0" : : "r"(0x8));
    
    uint32_t mhartid;
    asm volatile("csrr %0, mhartid\n"
                    : "=r"(mhartid));

    uint32_t start, start_insn;
    asm volatile("csrr %0, cycle\n"
                 "csrr %1, instret\n"
                 : "=r"(start), "=r"(start_insn));

    // some tests only make sense for single-hart execution
    // this provides a method to bypass extra harts for those tests
    if(mhartid < _femtokernel_test_max_hart) {
        // TODO: we should check that a certain number
        // of HARTs pass the tests; enforce REQUIRE_HARTS.
        // currently, only limits the tests with LIMIT_HARTS.
        int pass = main();
        uint32_t end, end_insn;
        asm volatile("csrr %0, cycle\n"
                     "csrr %1, instret\n"
                     : "=r"(end), "=r"(end_insn));
        if(pass == 0) {
            kprint("Test Passed (HART %d)\n", mhartid);
        } else {
            kprint("Test Failed (HART %d)\n", mhartid);
        }
        print_statistics(start, end, start_insn, end_insn);
    } else {
        kprint("Test skipped (HART %d): HARTID > MAX HARTID (%d)\n", mhartid, _femtokernel_test_max_hart);
    }
 

    __sim_halt();
}
