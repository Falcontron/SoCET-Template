#include <stdint.h>
#include <stdbool.h>

#include "format.h"
#include "pal.h"
#include "alloc.h"
#include "riscv.h"

CLINTRegBlk *clint = (CLINTRegBlk *)CLINT_BASE;
PLICRegBlk *plic = (PLICRegBlk *)PLIC_BASE;
DMARegBlk *dma = (DMARegBlk *)DMA_BASE;

volatile bool transfer_complete = false;

void __attribute__((interrupt)) mext_handler() {
    uint32_t cause = plic->cfg[0].claim_complete;
    dma->cr = 0;
    plic->cfg[0].claim_complete = cause;
    print("Handler:\n");
    print("\tCause: %d\n", cause);
    transfer_complete = true;
}


int main() {
    int *a = malloc(sizeof(*a) * 64);
    if(a == NULL) {
        print("Alloc failure\n");
        return 1;
    }

    for(int i = 0; i < 64; i++) {
        a[i] = i;
    }

    int *b = malloc(sizeof(*b) * 64);
    if(b == NULL) {
        print("Alloc failure\n");
        return 1;
    }

    // setup DMA
    dma->sar = (uint32_t)a;
    dma->dar = (uint32_t)b;
    dma->tsr = 64;

    // setup PLIC
    plic->enable[1] = 0xFFFFFFFF;
    plic->priority[38] = 0x7;

    // set CLINT so that no timer interrupt happens
    clint->mtimecmp[0].l = 0xFFFFFFFF;

    // global interrupt enable
    interrupt_enable();

    // Fence -- flush caches
    asm volatile("fence.i" : : : "memory");

    // Start DMA & wait for interrupt
    uint32_t dma_cfg = 
                  0x1 // EN
                | (0x1 << 1) // TCIE
                | (0x2 << 5) // PSIZE
                | (0x1 << 11) // IDST
                | (0x1 << 12) // ISRC
                ;
    dma->cr = dma_cfg;

    while(!transfer_complete) {
        asm volatile("wfi");
    }

    // Check
    for(int i = 0; i < 64; i++) {
        if(a[i] != b[i]) {
            print("Mismatch: a[i] = %d, b[i] = %d\n", a[i], b[i]);
            return 1;
        }
    }

    return 0;
}
