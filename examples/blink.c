

int main() {

    volatile unsigned int *GPIO_DATA = 0x80000000;
    volatile unsigned int *GPIO_DIR  = 0x80000004;

    (*GPIO_DIR) = 0xFF;
    unsigned int state = ~(0);

    for(;;) {
        (*GPIO_DATA) = state;
        state = ~state;
    }

    return 0;
}
