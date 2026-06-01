# Top-level

## Top-level Description
32-bit up counter with software R/W APB peripheral. Has 8 independent channels for input capture, output compare, or PWM generation

## Block Diagram
![Timer Top-Level Diagram](./figures/top-level.png)

## Main Features
- Software configurable time-base to provide up-counting
  - generate interrupts on overflow (tc_irq)
- Software configurable capture-compare channels
  - operates based on counter in time-base
  - generate interrupts on input edge(s) and output comparison matches (t_irq)

## Bus interface
- Generic bus / APB interface with timer to:
  - Write to registers and configure time-base / capture-compare channels
  - Read from registers for information (e.g. timing calculations)

## Pin interface
- timer_in pins for each capture-compare channel
  - connect external signal to corresponding pin for input capture
- timer_out pins for each capture-compare channel
  - outputs high or low depending on output mode
- timer output enable pins for each capture-compare channel
  - if high, then channel is in output-mode
  - if low, then channel is not in output-mode. Disregard timer_out pin value


