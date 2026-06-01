
#include "format.h"

int __attribute__((section(".text.main"))) main() {
   print("Hello, World!\n");
   print("Testing this.\n");

   int start_arr[8] = {1, 2, 3, 4, 5, 6, 7, 8};
    for(int i = 0; i < 8; i++) {
        print("%d\n", start_arr[i]);
    }

   for(;;);
   return 0;
}
