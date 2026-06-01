#include "utility.h"
#include "format.h"

void __attribute__((noinline)) print_string(const char *s) {
    volatile char *MAGIC_ADDR = (volatile char *)0xB0000000;
    for(int i = 0; s[i]; i++) {
        *MAGIC_ADDR = s[i];
    }
}

/*static char *
byte_to_hex(char byte) {
    static char txt[3] = {'\0', '\0', '\0'};
    if(byte & 0xF < 10) {
        txt[0] = '0' + (byte & 0xF);
    } else {
        txt[0] = 'A' + (byte & 0xF) - 10;
    }
   
    byte >>= 4;

    if(byte & 0xF < 10) {
        txt[1] = '0' + (byte & 0xF);
    } else {
        txt[1] = 'A' + (byte & 0xF) - 10;
    }

    return txt;
}*/

/*
static inline void
print_byte_helper(char byte) {
    switch(byte) {
        case 0: print("0"); break;
        case 1: print("1"); break;
        case 2: print("2"); break;
        case 3: print("3"); break;
        case 4: print("4"); break;
        case 5: print("5"); break;
        case 6: print("6"); break;
        case 7: print("7"); break;
        case 8: print("8"); break;
        case 9: print("9"); break;
        case 10: print("A"); break;
        case 11: print("B"); break;
        case 12: print("C"); break;
        case 13: print("D"); break;
        case 14: print("E"); break;
        case 15: print("F"); break;
        default: print("?"); break;
    }
}

void print_byte(char byte) {
    print_byte_helper(byte >> 4);
    print_byte_helper(byte & 0xF);
}*/

void __attribute__((noinline)) hexdump(char *b, int n) {
    for(int i = 0; i < n; i++) {
        if(i % 8 == 0) {
            print("\n");
        } else if(i % 2 == 0) {
            print(" ");
        }
    }
}

