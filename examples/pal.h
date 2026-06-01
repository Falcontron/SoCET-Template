#ifndef PALH_H_
#define PALH_H_

#include <stdint.h>

// IO definitions
#define __I  volatile const // Defines 'read-only' permissions
#define __O  volatile       // Defines 'write-only' permissions
#define __IO volatile       // Defines 'read/write' permissions

// Possible logic levels settings
enum LogicLevel {
    Low,
    High
};

// Peripheral memory map
#define BOTTOMRAM_BASE      ((uint32_t)0x00000000)
#define SELFTEST_BASE       ((uint32_t)0x00000200)
#define TOPRAM_BASE         ((uint32_t)0x00008000)
#define SRAM_BASE           ((uint32_t)0x00008400)
#define GPIO_BASE           ((uint32_t)0x80000000)
#define PWM_BASE            ((uint32_t)0x80001000)
#define SPI_BASE            ((uint32_t)0x80004000)
#define CLINT_BASE          ((uint32_t)0x90000000)
#define PLIC_BASE           ((uint32_t)0xA0000000)
#define DIG_MUX_BASE        ((uint32_t)0x80005000) //io mux base address

typedef struct{
    __IO uint32_t Func_Select_Reg_0; //pin0 - pin15, RW
    __IO uint32_t Func_Select_Reg_1; //pin16 - pin31, RW
}IOmuxRegBlk;


// GPIO register block
typedef struct {
    __IO uint32_t data;
    __IO uint32_t ddr;
    __IO uint32_t ier;
    __IO uint32_t per;
    __IO uint32_t ner;
    __IO uint32_t icr;
    __IO uint32_t isr;
} GPIORegBlk;

// Available GPIOs
enum GPIOPort {
    A = GPIO_BASE
};

// Availale GPIO pins
enum GPIOPin {
    Pin0 = 1 << 0,
    Pin1 = 1 << 1,
    Pin2 = 1 << 2,
    Pin3 = 1 << 3,
    Pin4 = 1 << 4,
    Pin5 = 1 << 5,
    Pin6 = 1 << 6,
    Pin7 = 1 << 7
};

//SPI register block
typedef struct {
    __IO uint32_t cr0;
    __IO uint32_t blr0;
    __IO uint32_t brr0;
    __O uint8_t txdr0;
    uint8_t reserved0;
    uint16_t reserved1;
    __I uint8_t rcdr0;
    uint8_t reserved2;
    uint16_t reserved3;
    __IO uint32_t sr0;
}SPIRegBlk;

// PWM register block
typedef struct {
    __IO uint32_t per0;
    __IO uint32_t duty0;
    __IO uint8_t ctrl0;
    uint8_t reserved0;
    uint16_t reserved1;
    __IO uint32_t per1;
    __IO uint32_t duty1;
    __IO uint8_t ctrl1;
    uint8_t reserved2;
    uint16_t reserved3;
    __IO uint32_t per2;
    __IO uint32_t duty2;
    __IO uint8_t ctrl2;
    uint8_t reserved4;
    uint16_t reserved5;
    __IO uint32_t per3;
    __IO uint32_t duty3;
    __IO uint8_t ctrl3;
    uint8_t reserved6;
    uint16_t reserved7;
    __IO uint32_t per4;
    __IO uint32_t duty4;
    __IO uint8_t ctrl4;
    uint8_t reserved8;
    uint16_t reserved9;
    __IO uint32_t per5;
    __IO uint32_t duty5;
    __IO uint8_t ctrl5;
    uint8_t reserved10;
    uint16_t reserved11;
    __IO uint32_t per6;
    __IO uint32_t duty6;
    __IO uint8_t ctrl6;
    uint8_t reserved12;
    uint16_t reserved13;
    __IO uint32_t per7;
    __IO uint32_t duty7;
    __IO uint8_t ctrl7;
} PWMRegBlk;

// IRQ mappings
enum IRQMap {
    Dflt  = 0,
    Exc   = 1,
    MSoft = 2,
    MTim  = 3,
    MExt  = 4
};

// CLINT register block
typedef struct {
    __IO uint32_t msip;
    __IO uint32_t mtime;
    __IO uint32_t mtimeh;
    __IO uint32_t mtimecmp;
    __IO uint32_t mtimecmph;
} CLINTRegBlk;

#define N_INTS 15

// PLIC register block
typedef struct {
    uint32_t reserved0;
    __IO uint32_t iprior[N_INTS];
    __IO uint32_t ipndgr;
    __IO uint32_t ier;
    uint32_t reserved1;
    __IO uint32_t ptr;
    __IO uint32_t ccr;
} PLICRegBlk;

#endif /* PAL_H_ */
