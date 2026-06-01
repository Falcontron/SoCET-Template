#pragma once

#include <stddef.h>
#include <stdint.h>

void *memcpy(void *dst, void *src, size_t n);
void *memset(void *dst, int c, size_t n);
void set_sda(uint8_t level);
void set_scl(uint8_t level);
void delay_us(uint32_t us);
uint8_t read_sda();
void init_platform();
uint8_t read_pin(uint8_t);
