
.text
.globl __aftx07_init
.section .text.__aftx07_init
__aftx07_init:
    la sp, __stack_top
    jal main

.globl __inf_loop
__inf_loop:
    j __inf_loop
