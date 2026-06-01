#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdarg.h>

void vformat(const char *fmt, char *buf, va_list args);
void vprint(const char *fmt, va_list args);
//void format(const char *fmt, char *buf, ...);
void print(const char *fmt, ...);
//void dprint(const char *fmt, ...);
//void kprint(const char *fmt, ...);

#ifdef DEBUG
    #define dprint print
#else
    #define dprint(fmt, ...)
#endif

#ifdef __cplusplus
}
#endif