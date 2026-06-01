
int main() {

    volatile unsigned int *GPIO_DATA = (volatile unsigned int *)0x80000000;
    volatile unsigned int *GPIO_DIR  = (volatile unsigned int *)0x80000004;

    (*GPIO_DIR) = 0xFF;
    unsigned int state = ~(0);

    for(;;) {
    #ifdef SYNTHESIS
        for (int i = 0; i < 0x800000; i++);
    #endif
        (*GPIO_DATA) = state;
        state = ~state;
    }

    return 0;
}
