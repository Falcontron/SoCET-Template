#include "pal.h"

GPIORegBlk *gpio0    = (GPIORegBlk *) GPIO0_BASE;
GPIORegBlk *gpio1    = (GPIORegBlk *) GPIO1_BASE;
GPIORegBlk *gpio2    = (GPIORegBlk *) GPIO2_BASE;
GPIORegBlk *gpio3    = (GPIORegBlk *) GPIO3_BASE;

int fib(int n) {
    return (n > 1) ? fib(n - 1) + fib(n - 2) : 1;
}

void display_gpio(int n) {
    int n1 = n & 0xFF;
    int n2 = (n >> 8) & 0xFF;
    int n3 = (n >> 16) & 0xFF;
    int n4 = (n >> 24) & 0xFF;

    gpio0->data = n1;
    gpio1->data = n2;
    gpio2->data = n3;
    gpio3->data = n4;
}

int main() {
    gpio0->ddr = 0xFFFFFFFF;
    gpio1->ddr = 0xFFFFFFFF;
    gpio2->ddr = 0xFFFFFFFF;
    gpio3->ddr = 0xFFFFFFFF;

    
    for (int i = 0; i < 20; ++i) {
        display_gpio(fib(i));
    }

    return 0;
}
