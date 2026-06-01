
#include <stdint.h>
#include <stdarg.h>
#include <stdnoreturn.h>

#include "format.h"
#include "utility.h"

#define INSN_FAULT 1
#define LOAD_FAULT 5
#define STORE_FAULT 7

extern void __inf_loop();

volatile unsigned cnt = 1;
static const char *names[] = {
    "mal_insn",
    "insn_fault",
    "illegal",
    "bkpt",
    "mal_load",
    "load_fault",
    "mal_store",
    "store_fault",
    "ecall-u",
    "ecall-s",
    "reserved (10)",
    "ecall-m",
    "unknown"
};


// indirection for instruction fault
void do_exit() {
    if(cnt == 4) {
        print("PASSED\n");
    } else {
        print("FAILED\n");
    }


    __inf_loop(); 
}

void __attribute__((interrupt)) __attribute__((aligned(4))) handler() {
    uint32_t cause;
    uint32_t addr;
    unsigned idx;
    uint32_t mepc_value;

    asm volatile("csrr %0, mcause" : "=r"(cause));
    asm volatile("csrr %0, mtval" : "=r"(addr));


    print("Fault %d: %s @ %x\n", cnt, names[cause], addr);
    cnt += 1;

    asm volatile("csrr %0, mepc" : "=r"(mepc_value));
    if(cause != INSN_FAULT) {
        mepc_value += 4;
    } else {
        mepc_value = do_exit;
    }
    asm volatile("csrw mepc, %0" : : "r"(mepc_value));
}


noreturn int main() {

    // GNU-specific
    //static void *list_labels[] = {
    //    &&fault_l,
    //    &&fault_s,
    //    &&fault_i,
    //    &&done
    //};

    uint32_t mtvec_value = (uint32_t)handler;

    asm volatile("csrw mtvec, %0" : : "r"(mtvec_value));

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
