#include <stdint.h>
#include <stdbool.h>

#include "alloc.h"
#include "format.h"

#define BLOCK_SIZE (16)
#define NUM_BLOCKS (HEAP_SIZE / BLOCK_SIZE)
#define BITMAP_SIZE (NUM_BLOCKS / 8)

extern uint8_t *__heap_start;

static uint8_t bitmap[BITMAP_SIZE] = {0};
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-variable"
static uint8_t *heap_start = (uint8_t *)&__heap_start;
static uint8_t *heap_end = (uint8_t *)(&__heap_start + HEAP_SIZE);
#pragma GCC diagnostic pop

typedef struct {
    uint32_t nblocks;
    uint8_t *data_start;
} malloc_info_t;

static inline
bool get_bit_idx(unsigned idx) {
    unsigned bitmap_pos = idx / 8;
    unsigned bit_pos = idx % 8;

    return (bitmap[bitmap_pos] & (1 << (7 - bit_pos))) != 0;
}

static inline
void set_bit_idx(unsigned idx) {
    unsigned bitmap_pos = idx / 8;
    unsigned bit_pos = idx % 8;
    bitmap[bitmap_pos] |= (1 << (7 - bit_pos));
}

static inline
void clear_bit_idx(unsigned idx) {
    unsigned bitmap_pos = idx / 8;
    unsigned bit_pos = idx % 8;
    bitmap[bitmap_pos] &= ~(1 << (7 - bit_pos));
}

static inline
uint8_t *block_to_addr(unsigned block) {
    uint32_t base = (uint32_t)heap_start;
    uint32_t offset = block * BLOCK_SIZE;
    return (uint8_t *)(base + offset);
}

static inline
unsigned addr_to_block(uint8_t *addr) {
    uint32_t base = (uint32_t)heap_start;
    uint32_t offset = (uint32_t)addr - base;
    return offset / BLOCK_SIZE;
}

uint32_t find_consecutive_bits(unsigned n) {
    bool found = false;
    uint32_t index = NUM_BLOCKS;

    // This really would be cleaner with a GOTO
    // i.e. if FOUND, GOTO end instead of break...
    for(unsigned i = 0; i < BITMAP_SIZE*8; i++) {
        if(!get_bit_idx(i)) { // free bit found
            found = true;
            index = i;
            for(unsigned j = i + 1; j < i + n; j++) {
                if(get_bit_idx(j)) {
                    // Skip to next potential spot
                    found = false;
                    index = NUM_BLOCKS;
                    i = j + 1;
                    break;
                }
            }

            if(found) {
                break;
            }
        }
    }

    return index;
}

void *malloc(uint32_t sz) {

    // DEBUG
    dprint("Heap start: %x\n", (uint32_t)heap_start);

    // round to nearest BLOCK_SIZE
    sz = ((sz + BLOCK_SIZE/2) / BLOCK_SIZE) * BLOCK_SIZE;
    uint32_t nblocks = sz / BLOCK_SIZE;
    nblocks += 1; // bookkeeping space
    uint32_t idx = find_consecutive_bits(nblocks);
    if(idx >= NUM_BLOCKS) {
        dprint("No blocks found, NULL\n");
        return NULL;
    }

    for(unsigned i = 0; i < nblocks; i++) {
        set_bit_idx(idx + i);
    }

    uint8_t *start = block_to_addr(idx);
    // 16B space available
    malloc_info_t *info = (malloc_info_t *)start;
    info->nblocks = nblocks;
    info->data_start = block_to_addr(idx + 1);

    dprint("Returning block %x\n", (uint32_t)info->data_start);
    dprint("\tAllocated %d blocks\n", info->nblocks);
    dprint("\tFreelist: ");
    for(int i = 0; i < BITMAP_SIZE; i++) {
        if(i % 8 == 0) {
            dprint("\n");
        }
        dprint("%b ", bitmap[i]);
    }
    dprint("\n");

    return info->data_start;
}

void free(void *ptr) {
    unsigned idx = addr_to_block((uint8_t *)ptr);
    if(idx == 0) {
        print("[Kernel]: Free error: bad index\n");
        print("[Kernel]: Memory was probably lost!\n");
        return;
    }

    idx -= 1;
    malloc_info_t *info = (malloc_info_t *)block_to_addr(idx);
    for(unsigned i = idx; i < idx + info->nblocks; i++) {
        clear_bit_idx(i);
    }
}
