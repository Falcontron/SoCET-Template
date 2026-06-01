#pragma once

#include <stdint.h>

#define LIMIT_HARTS(n) \
    uint32_t _femtokernel_test_max_hart = n;

void enter_user_mode();
void interrupt_disable();
void interrupt_enable();
void swi_interrupt_enable();
void swi_interrupt_disable();

uint32_t get_mcause();
uint32_t get_mtval();
uint32_t get_mepc();
uint32_t get_mhartid();

extern const char *exception_names[];
