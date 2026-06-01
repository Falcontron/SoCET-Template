
#include "alloc.h"

int main() {
    volatile int *a = malloc(sizeof(*a) * 20);
    volatile int *b = malloc(sizeof(*b) * 30);
    volatile int *c = malloc(sizeof(*c) * 40);
    free(b);
    volatile int *d = malloc(sizeof(*d) * 10);
    

    return 0;
}