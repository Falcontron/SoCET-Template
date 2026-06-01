#include "format.h"

void __attribute__((constructor)) secret_message() {
    print("It's a secret to everyone.\n");
}

int main() {
    print("This is the main function\n");
}