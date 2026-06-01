#ifndef _DMA_H_
#define _DMA_H_

#include <stdbool.h>

#define DMA_BASE (0x80050000)
#define DMA_CMAR (0x80050004)
#define DMA_CPAR (0x80050008)
#define DMA_CNDTR (0x8005000C)
#define DMA_CCR (0x80050010)
#define DMA_CSR (0x80050014)

//When defining DMA Transfer
//DMA_TypeDef* periph = (DMA_TypeDef*) DMA_BASE;
//Since we only have a single channel I can define these all under DMA_TypeDef
typedef struct
{
    volatile const uint32_t RES1;  //Reserve
    volatile uint32_t CMAR;        //Source Address 
    volatile uint32_t CPAR;        //Destination Address      
    volatile uint32_t CNDTR;       //Transfer Size  
    volatile uint32_t CCR;         //configuration register  
    volatile const uint32_t CSR;   //Status Registers
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

    DMA_TypeDef* periph;
} dma_init_t;

/*
 Initialize DMA peripheral to set m2m, p2p, or p2m with set size and length of txfer

 param init -> Address of initialization structure
 return true -> Successful init (no clashing params)
 return false -> Init not complete (parameters clash)
 */
bool initDMA(dma_init_t* init);
//Start txfer after sucessful DMA peripheral initialization
void startTxfer(dma_init_t* init);
//Stop txfer
void stopTxfer(dma_init_t* init);
//Set memory address for DMA transfer. In Mem to Mem this acts as the source address
void DMA_setMemAddress(dma_init_t* init, const uint32_t address);
//Set transfer length for DMA transaction
void DMA_setTxferLength(dma_init_t* init, const uint32_t length);

#endif