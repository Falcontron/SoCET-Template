#include <stdarg.h> 
#include <stdint.h> 
#include "format.h" 
#include "riscv.h"
#include "pal.h"

#define ROM_BASE_ADDR 0x400 

int main() { 
    volatile unsigned int *ROM = ROM_BASE_ADDR; 

    // get values 
    print("Attempting to fetch from ROM\n"); 
    unsigned int before = *ROM;
    unsigned int not_before = ~before; 
  
    // try writing 
    print("Attempting to write to ROM\n");
    print("An interrupt should be caught; if so, test OK\n\n");
    *ROM = not_before;
    unsigned int after = *ROM;
 
    // cleanup 
    if (after != before) *ROM = before;
  
    // print results
    print("TEST FAILED; write successful\n");
    return 0; 
}

void __attribute__((interrupt)) mtime_handler() {
    print("TEST OK; write unsuccessful\n");
}
