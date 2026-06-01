#include <stddef.h>
#include <stdint.h>

#define BOOT_SDA (1)
#define BOOT_SCL (0)

#ifdef FPGA
#define CLK_MHZ (25)
#else
#define CLK_MHZ (30)
#endif

#define BOOT_BASE (0x80006000)

__attribute__((used)) void *memcpy(void *dst, void *src, size_t n) {
    uint8_t *dstt = (uint8_t *)dst;
    uint8_t *srct = (uint8_t *)src;

    for(int i = 0; i < n; i++) {
        dstt[i] = srct[i];
    }
    return dst;
}

__attribute__((used)) void *memset(void *dst, int c, size_t n) {
    uint8_t *dstt = (uint8_t *)dst;

    for(int i = 0; i < n; i++) {
        dstt[i] = c;
    }
    return dst;
}

static inline uint32_t
read_cycle() {
    uint32_t cycle;
    asm volatile("csrr %0, cycle" : "=r"(cycle));
    return cycle;
}

static inline void
write_volatile(uint32_t addr, uint32_t value) {
    *(volatile uint32_t *)(addr) = value;
}

static inline uint32_t
read_volatile(uint32_t addr) {
    return *(volatile uint32_t *)(addr);
}

static void
set_pin(uint8_t pin, uint8_t value) {
    // To pull down, write a 1 to the bit (set to output mode)
    // To pull up, write a 0 to the bit (set to input mode to float)
    volatile uint32_t *ptr = (volatile uint32_t *)(BOOT_BASE + 4);
    uint32_t bitmask = (1 << pin) & 0x7;
    if (value == 0) {
        *ptr |= bitmask;
    } else {
        *ptr &= ~bitmask;
    }
}


uint8_t read_pin(uint8_t pin) {
    return (uint8_t)(read_volatile(BOOT_BASE + 0x0) & (1 << pin)) != 0;
}

void set_sda(uint8_t level) {
    set_pin(BOOT_SDA, level);
}

void set_scl(uint8_t level) {
    set_pin(BOOT_SCL, level);
}

uint8_t read_sda() {
    return read_pin(BOOT_SDA);
}

uint8_t read_scl() {
    return read_pin(BOOT_SCL);
}

void init_platform() {
    // Set all to input
    write_volatile(BOOT_BASE + 0x4, 0);
    // Preload output values with 0
    write_volatile(BOOT_BASE + 0x0, 0x0);
}

void delay_us(uint32_t us) {
    uint32_t cycles = us * CLK_MHZ;
    uint32_t cycle_start = read_cycle();
    uint32_t diff = 0;

    while ((diff = (read_cycle() - cycle_start)) < cycles);
    (void)diff;
}
