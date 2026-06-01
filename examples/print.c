
#include "format.h"

int __attribute__((section(".text.main"))) main() {
   print("Hello, World!\n");
   print("Testing this.\n");

   for(;;);
   return 0;
}
