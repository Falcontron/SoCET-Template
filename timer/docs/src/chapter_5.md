# Register Map

# Register map description
 - The timer has the TCR, TCNT, TPSC, and TARR. Each of the 8 channels has its own TCCMR and TCCR, meaning there are 8*2 + 4 = 20 registers in total
 - Each register is 32-bits (4-bytes) wide, meaning the byte-address to access each register should be in increments of 0x4
 - All registers are readable-writeable
 - TARR has a reset value of 0xFFFF_FFFF and all other registers have a reset value of 0x0000_0000


# Register map: Register name | Address offset | Description

TCNT | 0x0 | Timer count

TCR | 0x4 | Timer control register
 - Bit [7]: TCEN - Timer enable
    - 0: Disable 
    - 1: Enable 
 - Bit [1]: UIE - Update Interrupt Enable 
    - 0: Update interrupt disabled
    - 1: Update interrupt enabled 
 - Bit [0]: TCRST (Timer Control Reset) 
    - 0: Disable 
    - 1: Reset the counter to 0, it is recommended to set bit[7] TCREN to 0 so the counter is disable while resetting. Then when enabling the timer  
	again, remember to turn off bit[0] so the counter will count from 0 again.

TPSC | 0x8 | Timer Prescaler - Counter frequency is system clk divided by (TPSC[31:0] + 1)

TARR | 0xC | Timer Auto-Reload Register - Maximum value up-counter reaches before resetting to 0

TCCMR0 through TCCMR7 | 0x10 - 0x2C | Timer Capture-Compare Mode Register
 - Bit [8]: Capture/Compare Interrupt enable
    - 0: CC interrupt disabled
    - 1: CC interrupt enabled 
 - Bits [7:5]: OC1M: Output Compare 1 mode
    - 000: Frozen
    - 001: MATCH HIGH
    - 010: MATCH LOW
    - 011: TOGGLE
    - 100: FORCE LOW
    - 101: FORCE HIGH
    - 110: PWM1
    - 111: PWM2
 - Bits [4:3]: CC1S: Capture-Compare 1 Selection
    - 00: OUTPUT (output-compare mode)
    - 01: TI1_IN (input-compare mode)
 - Bits [2:1]: CC1P: Capture-Compare 1 Output Polarity
    - 00: RISING - triggers on rising edge
    - 01: FALLING - triggers on falling edge
    - 10: RESERVED (undefined state)
    - 11: BOTH - triggers on both rising and falling edges
 - Bit [0]: CC1E: Capture-Compare 1 output enable
    - 0: If input-capture mode, capture disabled. If output-compare, output pin inactive
    - 1: If input-capture mode, capture enabled. If output-compare, output pin active

TCCR0 through TCCR7 | 0x30 - 0x4C | Timer Capture-Compare Register

