#include <stdint.h>
#include <stdnoreturn.h>

#include "interrupt.h"
#include "format.h"

extern noreturn void panic(const char *);

void __attribute__((used)) __attribute__((weak)) __attribute__((interrupt)) default_handler() {
    uint32_t cause;
    uint32_t epc;
    uint32_t value;

    asm volatile("csrr %0, mcause" : "=r"(cause));
    asm volatile("csrr %0, mepc" : "=r"(epc));
    asm volatile("csrr %0, mtval" : "=r"(value));

    print("Unhandled interrupt:\n");
    print("\tCause: %x\n", cause);
    print("\tEPC: %x\n", epc);
    print("\tValue: %x\n", value);

    panic("unhandled interrupt");
}

void exception_handler()    __attribute__((used)) __attribute__((interrupt)) __attribute__((weak, alias("default_handler"))) ;
void mtime_handler()        __attribute__((used)) __attribute__((interrupt)) __attribute__((weak, alias("default_handler")));
void mext_handler()         __attribute__((used)) __attribute__((interrupt)) __attribute__((weak, alias("default_handler")));
void mswi_handler()         __attribute__((used)) __attribute__((interrupt)) __attribute__((weak, alias("default_handler")));

void __attribute__((naked)) __attribute__((aligned(4))) handler_dispatch() {
    asm(".option push\n"
        ".option norvc\n"
        "j exception_handler\n" // 0
        "j default_handler\n"   // 1
        "j default_handler\n"   // 2
        "j mswi_handler\n"      // 3
        "j default_handler\n"   // 4
        "j default_handler\n"   // 5
        "j default_handler\n"   // 6
        "j mtime_handler\n"     // 7
        "j default_handler\n"   // 8
        "j default_handler\n"   // 9
        "j default_handler\n"   // 10
        "j mext_handler\n"      // 11
        ".option pop"
    );
}