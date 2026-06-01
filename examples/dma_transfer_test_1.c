#include <stdarg.h>
#include <stdint.h>
#include "utility.h"
#include "format.h"

typedef struct DMA_CR_CONFIG
{
    // Bit[0] : EN : should be set to start the transfer
    uint8_t EN;
    // Bit[1] : TCIE : is the Transfer Complete Interrupt Enable
    uint8_t TCIE;
    // Bit[2] : HTIE : is the Half Transfer Interrupt Enable
    uint8_t HTIE;
    // Bit[4] : SRC : Is the source a peripheral or memory (0: Source is Memory, 1: Source is Peripheral)
    uint8_t SRC;
    // Bit[5] : DST : Is the source a peripheral or memory (0: Source is Memory, 1: Source is Peripheral)
    uint8_t DST;
    // Bit[6:7] : PSIZE : Peripheral Size (00: 8-bit, 01: 16-bit, 10: 32-bit)
    uint8_t PSIZE;
    // Bit[8] : TE : DMA Trigger Enable
    uint8_t TE;
    // Bit[10] : CIRC: Circular Mode
    uint8_t CIRC;
    // Bit[11]: IDST: Increment destination address every read/write
    uint8_t IDST;
    // Bit[12]: ISRC: Increment source address every read/write
    uint8_t ISRC;
}DMA_CR_CONFIG;

unsigned int DMA_CR_trans(DMA_CR_CONFIG config)
{
    unsigned int DMA_CR = config.EN | (config.TCIE << 1) | (config.HTIE << 2) | (config.SRC << 3) | (config.DST << 4) | (config.PSIZE << 5) | (config.TE << 8) | (config.CIRC << 10) | (config.IDST << 11) | (config.ISRC << 12);
    return DMA_CR;
}

int compare_array(int* arr_a, int* arr_b, int len){
    int is_equal = 1;
    for(int i = 0; i < len; i++) {
        if(arr_a[i] != arr_b[i]) {
            is_equal = 0;
        }
    }
    return is_equal;
}

int main() {
    volatile unsigned int *DMA_SAR = 0x90001004;
    volatile unsigned int *DMA_DAR = 0x90001008;
    volatile unsigned int *DMA_TSR = 0x9000100C;
    volatile unsigned int *DMA_CR = 0x90001010; 
    volatile unsigned int *DMA_SR = 0x90001014;

    int start_arr[8] = {1, 2, 3, 4, 5, 6, 7, 8};
    int end_arr[8] = {99, 99, 99, 99, 99, 99, 99, 99};
    int test_arr_1[16] = {32, 32, 32, 32, 32, 32, 32, 32};
    int test_arr_2[16] = {88, 88, 88, 88, 88, 88, 88, 88};
    int output_1;
    int equal;

    // --- Test 1 ---
    //      8 word transfer
    //      increment both source and distination

    print("start_arr = %x\n", start_arr);
    print("end_arr = %x\n", end_arr);

    // (*DMA_SAR) = (int *)start_arr;
    // (*DMA_DAR) = (int *)end_arr;
    (*DMA_SAR) = 0xA3A0;            
    (*DMA_DAR) = 0xA3C0;
    (*DMA_TSR) = (unsigned int) 8;

    print("SAR = %x\n", *DMA_SAR);
    print("DAR = %x\n", *DMA_DAR);
    print("TSR = %x\n", *DMA_TSR);

    print("test_arr_1 = %x\n", *test_arr_1);
    print("test_arr_2 = %x\n", *test_arr_2);

    DMA_CR_CONFIG test_config = {.EN = 1, .TCIE = 1, .HTIE = 0, .SRC = 0, .DST = 0, .PSIZE = 2, .TE = 0, .CIRC = 0, .IDST = 1, .ISRC = 1};

    unsigned int middle = DMA_CR_trans(test_config);
    print("middle = %x\n", middle);
    (*DMA_CR) = middle;
    print("write finished\n");

    // for(int i = 0; i < 500; i++) {
    //     test_arr_1[i] = i;
    //     output_1 = test_arr_2[i % 13];
    //     output_1 = test_arr_1[i % 14 + 3];
    // }
    
    for(int i = 0; i < 500; i++) {
        __asm__("wfi");
    }

    print("DMA test 1 should be finished writing\n");
    // print("\nend_arr:");
    for(int i = 0; i < 8; i++) {
        print("%d\n", end_arr[i]);
    }

    equal = compare_array(start_arr, end_arr, 8);
    if (equal) {
        print("--- Test 1 passed --- \n");
    } else {
        print("--- Test 1 failed --- \n");
    }

    // read status register
    unsigned int status = *DMA_SR;
    print("SR = %d\n", status);

    // disable DMA
    test_config.EN = 0;
    middle = DMA_CR_trans(test_config);
    (*DMA_CR) = middle;
 

    // --- Test 2 ---
    //      8 word transfer
    //      increment both source and distination
    //      added circular mode

    // enable circular mode    
    test_config.CIRC = 1;
    test_config.EN = 1;
    middle = DMA_CR_trans(test_config);
    (*DMA_CR) = middle;

    for(int i = 0; i < 100; i++) {
        __asm__("wfi");
    }

    print("1st version of source array\n");
    print("\nend_arr:\n");
    for(int i = 0; i < 8; i++) {
        print("%d\n", end_arr[i]);
    }

    // modify source array
    for(int i = 0; i < 8; i++) {
        start_arr[i] = i + 8;
    }
    
    // check source array
    print("\nstart_arr:\n");
    for(int i = 0; i < 8; i++) {
        print("%d\n", start_arr[i]);
    }

    // wait for DMA to update the desitnation array
    for(int i = 0; i < 100; i++) {
        __asm__("wfi");
    }

    print("DMA test 2 should be finished writing\n");
    print("\nend_arr:\n");
    for(int i = 0; i < 8; i++) {
        print("%d\n", end_arr[i]);
    }

    equal = compare_array(start_arr, end_arr, 8);
    if (equal) {
        print("--- Test 2 passed --- \n\n");
    } else {
        print("--- Test 2 failed --- \n\n");
    }


}