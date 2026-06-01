#pragma once

extern void __attribute__((weak)) __attribute__((interrupt)) exception_handler(void);
extern void __attribute__((weak)) __attribute__((interrupt)) default_handler(void);
extern void __attribute__((weak)) __attribute__((interrupt)) mswi_handler(void);
extern void __attribute__((weak)) __attribute__((interrupt)) mtime_handler(void);
extern void __attribute__((weak)) __attribute__((interrupt)) mext_handler(void);
void __attribute((naked)) __attribute((aligned(4))) handler_dispatch( );