#pragma once

#include <cstdint>

#define __IO volatile

#define CLINT_BASE (0x90000000)

typedef struct {
    __IO uint32_t msip;
    __IO uint32_t mtime;
    __IO uint32_t mtimeh;
    __IO uint32_t mtimecmp;
    __IO uint32_t mtimecmph;
} CLINT;