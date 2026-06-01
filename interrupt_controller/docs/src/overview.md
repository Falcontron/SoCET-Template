# Overview

The AFTx series of microcontrollers provides programmable interrupt support
through the use of the RISC-V specifications for a Core Local Interruptor
(CLINT) and a Platform Level Interrupt Controller (PLIC). The CLINT is used for
controlling interrupts which can be targeted and local to a core. For example,
inter-processor interrupts are facilitated through the CLINT. The PLIC is used
to allow for SoC peripherals to interrupt harts in implementation specific
fashions. For example, UART interrupts can be set to be edge detected pulses
sent to the PLIC when a byte is recieved. These interrupts are broadcast to all
cores and provides per-hart level interrupt prioritization and configuration.
