#include "format.h"
#include "pal.h"
#include "riscv.h"
#include <stdint.h>

LIMIT_HARTS(2)

//register names for plic and gpio
#define GPIO_IRQ_ID 1
#define HART0_CONTEXT 0
#define HART1_CONTEXT 1

//pointers to register blocks
volatile GPIORegBlk *gpio = (GPIORegBlk *)GPIO0_BASE;
volatile PLICRegBlk *plic = (PLICRegBlk *)PLIC_BASE;
volatile CLINTRegBlk *CLINT  = (CLINTRegBlk *)CLINT_BASE;

extern void __sim_halt(); //stops sim
extern void __sim_wfi(); //waits for interrupt

// flag to set interrupt handled
volatile int mext_handled = 0;
volatile int mtime_handled = 0;

//gpio handler
__attribute__((used)) __attribute__((interrupt)) void mext_handler() {
    uint32_t mhartid = get_mhartid(); //read which hart being executed
    uint32_t irq_id = *PLIC_CLAIM_COMPLETE(PLIC_BASE, mhartid); // aknowledge and claim interrupt
    if (irq_id == GPIO_IRQ_ID) {
        print("Hart %d: GPIO interrupt received with irq id %d\n", mhartid, irq_id);
        gpio->icr = 0xFF;  //clear all GPIO interrupts
        gpio->ier = 0x00;  // disable future GPIO interrupts
        mext_handled = 1;
    }
    
    *PLIC_CLAIM_COMPLETE(PLIC_BASE, mhartid) = irq_id; //complete interrupt
}

// mtime handler for hart 1 to wait
void __attribute__((interrupt)) mtime_handler() {
uint32_t mhartid = get_mhartid();
    mtime_handled = 1;
    print("Hart %d stall complete\n", mhartid);
    CLINT->mtimecmp[get_mhartid()].l = 0xFFFFFFFF;
}

int main() {
    uint32_t mhartid = get_mhartid();
    // ignore mtime interrupt
    CLINT->mtimecmp[mhartid].l = 0xFFFFFFFF;
    print("Booting up hart %d\n", mhartid);
    *PLIC_PRIORITY(PLIC_BASE, GPIO_IRQ_ID) = 1;//set priority of gpio interrupt in plic = 1
    
    if (mhartid == 0) { 
      // enable GPIO interrupts for hart 0
      *PLIC_ENABLE(PLIC_BASE, GPIO_IRQ_ID, mhartid) |= (1 << (GPIO_IRQ_ID % 32)); //enable gpio interript for this specific hart in plic
      *PLIC_PRIORITY_THRESHOLD(PLIC_BASE, mhartid) = 0; //allow all interrpts of priotiy >0 set threshold = 0
    } else {
      // hart 1 sets a timer interrput to wait for hart 0 set up
      CLINT->mtimecmp[mhartid].l += 0x3000;
    }
    
    interrupt_enable();
   
    //hart 0 waiting to handle gpio interrupt
    if (mhartid == 0) {
        print("Hart 0 waiting for GPIO interrupt...\n");
        while (!mext_handled) __sim_wfi(); 
    } else {
        print("Hart %d stalling for Hart 0 to set up\n", mhartid);
        while (!mtime_handled) __sim_wfi();

        // enable interrupts on edge
        gpio->ier = 0xFF;
        gpio->per = 0xFF;
        gpio->ner = 0xFF;

        print("Hart %d triggering GPIO interrupt\n", mhartid);
        for (volatile int i = 0; i < 1000; i++) {
            asm("");
        }
    }
    return 0;
}
