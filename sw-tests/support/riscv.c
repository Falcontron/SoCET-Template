#include <stdint.h>
#include <stdnoreturn.h>

#include "riscv.h"

//
//  Enter user mode
//  1. Set mepc = ra: enter user mode at the return address of the function
//  2. Clear MPP field of mstatus (00 = U-Mode)
//  3. mret to return addres
//  Note: this function is naked + noreturn since we don't need any extra instructions
//  TODO: Swap to user-space stack here?
//  TODO: Is this sensible? Or should it take an argument of where to start user-space execution?
noreturn void __attribute__((noinline)) __attribute__((naked)) enter_user_mode() {
    // use t0, convention says it is caller-saved
    asm(
        "li t0, 3\n"
        "slli t0, t0, 12\n"
        "csrw mepc, ra\n"
        "csrc mstatus, t0\n"
        "mret");
}

void interrupt_disable() {
    uint32_t mie_bit = 0x8;
    asm volatile(
        "csrc mstatus, %0"
        : : "r"(mie_bit)
    );
}

void interrupt_enable() {
    uint32_t mie_bit = 0x8;
    asm volatile(
        "csrs mstatus, %0"
        : : "r"(mie_bit));
}

void swi_interrupt_enable() {
    uint32_t mie_bit = 0x8;
    asm volatile(
        "csrs mie, %0"
        : : "r"(mie_bit));
}

void swi_interrupt_disable() {
    uint32_t mie_bit = 0x8;
    asm volatile(
        "csrc mie, %0"
        : : "r"(mie_bit));
}

// mcause exception names table 
const char *exception_names[] = {
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

uint32_t get_mcause() {
    uint32_t mcause_value;
    asm volatile(
        "csrr %0, mcause"
        : "=r"(mcause_value));
    
    return mcause_value;
}

uint32_t get_mtval() {
    uint32_t mtval_value;
    asm volatile(
        "csrr %0, mtval"
        : "=r"(mtval_value));
    
    return mtval_value;
}

uint32_t get_mepc() {
    uint32_t mepc_value;
    asm volatile(
        "csrr %0, mepc"
        : "=r"(mepc_value));
    
    return mepc_value;
}

uint32_t get_mhartid() {
    uint32_t mhartid_value;
    asm volatile(
        "csrr %0, mhartid"
        : "=r"(mhartid_value));

    return mhartid_value;
}
