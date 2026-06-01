#include <stdint.h>
#include "pal.h"
#include "format.h"
#include "riscv.h"

void __attribute__((interrupt)) exception_handler() {
    uint32_t mcause = get_mcause();
    uint32_t mepc = get_mepc();
    uint32_t mtval = get_mtval();

    print("Fault: %s @ %x (to %x)\n", exception_names[mcause], mepc, mtval);

    mepc += 4;
    asm volatile("csrw mepc, %0" : : "r"(mepc));
}

int main() {
    uint32_t data;

    for (uint32_t i = 0; i < 1024 * 8; i += 4) {
        *((uint32_t *) (FF_RAM_BASE + i)) = i ^ 0xFF;
    }

    for (uint32_t i = 0; i < 1024 * 8; i += 4) {
        data = *(uint32_t *)(FF_RAM_BASE + i);
        if (data != (i ^ 0xFF)) {
            print("Mismatch @ %x\n", FF_RAM_BASE + i);
            print("%x vs %x\n", data, i ^ 0xFF);
            return 1;
        }
    }

    return 0;
}
