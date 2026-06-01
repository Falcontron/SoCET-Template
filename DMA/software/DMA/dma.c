#include "dma.h"

bool initDMA(dma_init_t* init) 
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

    DMA_setTxferLength(init, init->tx_size);

    init->periph->CPAR = init->dest_addr;
    init->periph->CMAR = init->source_addr;
    
    return true;
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
    init->channel->CNDTR &= ~0x0000FFFF;
    init->channel->CNDTR |= length;
}