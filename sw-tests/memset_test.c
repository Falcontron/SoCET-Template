#include <stddef.h>
#include "format.h"

extern void *memset(void *, int, size_t);

int main() {
    char data[80];

    memset(data, 0xA, 80);

    for(int i = 0; i < 80; i++) {
        if(data[i] != 0xA) {
            print("Failed! (%d)\n", i);
            return 1;
        }
    }

    return 0;
}
