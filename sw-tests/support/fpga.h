#pragma once
#include <stdint.h>

void wait(int t);
void clear_oled_display();
void init_oled();
void oled_display1(const char *str);
void oled_display2(const char *str);
void oled_print(const char *fmt, ...);
