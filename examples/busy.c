

int fib(int n) {
    return (n > 1) ? fib(n-1) + fib(n-2) : 1;
}

int main() {
    int input = 5;
    print("Fib %d = %d\n", input, fib(input));
}
