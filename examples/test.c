#include <stdarg.h>
#include <stdint.h>
#include "utility.h"
#include "format.h"


int main() {

    print("Hello, world!\n");
    print("Different representations of %d:\n\t%b\n\t%x\n\t'%c'\n\t", 56, 56, 56, 56);
    print("Negative percentage: %d%%\n", -25);
    print("Bad format, percent at end: %q %", 1000);
    print("\nSigned %d, Unsigned %u\n", -127, -127);
    print("String insertion: %s\n", 10 > 5 ? "true" : "false");

    return 0;
}
