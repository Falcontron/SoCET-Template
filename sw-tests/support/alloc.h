#pragma once

#include <stdint.h>

#define HEAP_SIZE (2*1024)
#define NULL ((void *)0)

void *malloc(uint32_t);
void *calloc(uint32_t);
void free(void *);
