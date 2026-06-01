#include "format.h"

int fib(int n) {
    return (n > 1) ? fib(n - 1) + fib(n - 2) : 1;
}

int main() {
    int input = 10;
    print("fib(%d) = %d\n", input, fib(input));

    return 0;
}
