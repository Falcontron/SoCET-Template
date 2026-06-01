#include <stdbool.h>

#define DMA_BASE (0x80050000)
#define DMA_CMAR (0x80050004)
#define DMA_CPAR (0x80050008)
#define DMA_CNDTR (0x8005000C)
#define DMA_CCR (0x80050010)
#define DMA_CSR (0x80050014)

//int main(void) __attribute__((section(".start")));

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned long uint32_t;

//When defining DMA Transfer
//DMA_TypeDef* periph = (DMA_TypeDef*) DMA_BASE;
//Since we only have a single channel I can define these all under DMA_TypeDef
typedef struct
{
    volatile const uint32_t RES1;       //Reserve
    volatile uint32_t CMAR;        //Source Address 
    volatile uint32_t CPAR;        //Destination Address      
    volatile uint32_t CNDTR;       //Transfer Size  
    volatile uint32_t CCR;         //configuration register  
    volatile const uint32_t CSR;         //Status Registers
    //volatile uint32_t ISR;   //DMA interrupt status register
    //volatile uint32_t IFCR;        // DMA interrupt flag clear register
} DMA_TypeDef;

typedef struct 
{
    uint32_t    source_addr;
    uint32_t    dest_addr;
    uint16_t    tx_size;

    bool        circular;
    uint8_t     dir;
    bool        mem_to_mem;
    uint8_t     mem_size; 
    uint8_t     periph_size;
    bool        mem_inc; 
    bool        periph_inc; 
    bool        dma_interrupt_en;
    bool        dma_trigger_en;

    volatile DMA_TypeDef* periph;
} dma_init_t;

void initDMA(dma_init_t* init);
//Start txfer after sucessful DMA peripheral initialization
void startTxfer(dma_init_t* init);
//Stop txfer
void stopTxfer(dma_init_t* init);
//Set memory address for DMA transfer. In Mem to Mem this acts as the source address
void DMA_setMemAddress(dma_init_t* init, const uint32_t address);
//Set transfer length for DMA transaction
void DMA_setTxferLength(dma_init_t* init, const uint32_t length);

static inline
void print(char *str) {
    int i = 0;
    volatile char *PRINT_ADDR = 0x20000;
    while(str[i] != '\0') {
        (*PRINT_ADDR) = str[i];
        i++;
    }
}


int main(void)
{ 
    //asm volatile ("li sp, 0x83FC");

    volatile int* src_address = (volatile int*) 0x8100;
    volatile int* second_byte = (volatile int*) 0x8104;
    volatile int* dest_address = (volatile int*) 0x8200;
    *src_address = 0x12345678;
    *second_byte = 0xDEADBEEF;

    volatile int x = *src_address;
    volatile DMA_TypeDef* dma_reg = (DMA_TypeDef*) DMA_BASE;

    dma_init_t dma_config = {
        .source_addr    = 0x8100,
        .dest_addr      = 0x8200,
        .tx_size        = 0x3,
        .circular       = 0x0,
        .dir            = 0x0,
        .mem_to_mem     = 0x0,
        .mem_size       = 0x0,
        .periph_size    = 0x1,
        .mem_inc        = 0x1,
        .periph_inc     = 0x1,
        .dma_trigger_en = 0x0,
        .dma_interrupt_en = 0x0,
        .periph         = dma_reg,
    };



    initDMA(&dma_config);
    startTxfer(&dma_config);

    volatile int i;
    volatile int j;
    for(i = 0; i < 100; i++);
    {
        j = i;
    }
    print("Hello, World!\n");
    print("Testing this.  \n");

    volatile int y = *dest_address;
}

void initDMA(dma_init_t* init) 
{
    //Make sure that values can be configured
    if (init->dir > 1)
    {
        return false;
    } 
    else if (init->mem_size > 2 || init->periph_size > 2) 
    {
        return false;
    }
    //Config
    /*Register Map i'm currently using - 
    0-Enable
    1-Tx Complete 
    2-Half Transfer Complete
    3-Transfer Err Int
    4-DIR/PER source of PER/MEM
    5- Empty 
    [7:6] - PSIZE/periph size
    8 - dma_trigger_en
    10 - circ
    11 - inc_dest / periph_inc
    12 - inc_source / mem_inc
    13 - dma_interrupt_en
    */

    init->periph->CCR &= ~0x0000FFFF; 
    init->periph->CCR |= (init->mem_size << 8) | (init->periph_size << 6);
    init->periph->CCR |= (init->circular << 10) | (init->dir << 4) | (init->periph_inc << 11) | (init->mem_inc << 12);
    init->periph->CCR |= (init->dma_trigger_en << 7) | (init->dma_interrupt_en << 12);

    init->periph->CPAR = init->dest_addr;
    init->periph->CMAR = init->source_addr;

    DMA_setTxferLength(init, init->tx_size);
}

void startTxfer(dma_init_t* init)
{
    // Channel enable starts txfer
    init->periph->CCR |= 0x1;
}

void stopTxfer(dma_init_t* init) 
{
    // Channel disable stops txfer
    init->periph->CCR &= ~0x1;
}

void DMA_setMemAddress(dma_init_t* init, const uint32_t address)
{
    init->periph->CMAR = address;
}

void DMA_setTxferLength(dma_init_t* init, const uint32_t length)
{
    init->periph->CNDTR &= ~0x0000FFFF;
    init->periph->CNDTR |= length;
}
