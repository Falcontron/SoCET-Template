#include <stddef.h>

#include "format.h"
#include "pal.h"



int main() {

    // Check structs
    print("PLICRegBlk: %x\n", sizeof(PLICRegBlk));

    PLICRegBlk *plic = (PLICRegBlk *)PLIC_BASE;

    print("plic->enable[0]: %x\n", (uint32_t)&plic->enable[0]);
    print("plic->priority[1]: %x\n", (uint32_t)&plic->priority[1]);
    print("plic->cfg[0]: %x\n", (uint32_t)&plic->cfg[0]);
    print("plic->cfg[1]: %x\n", (uint32_t)&plic->cfg[1]);

    return 0;
}
