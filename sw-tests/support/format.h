#pragma once
#include <stdarg.h>

void vformat(const char *fmt, char *buf, va_list args);
void vprint(const char *fmt, va_list args);
void format(const char *fmt, char *buf, ...);
void print(const char *fmt, ...);
void dprint(const char *fmt, ...);
void kprint(const char *fmt, ...);
