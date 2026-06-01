.extern main

.section .text.boot
.global boot
boot:
    .option push
    .option norelax
    la sp, __stack_top
    la gp, __global_pointer$
clear_bss:
    la t0, __bss_start
    la t1, __bss_end
    bge t0, t1, clear_bss_done

clear_bss_loop:
    sb zero, 0(t0)
    addi t0, t0, 1
    blt t0, t1, clear_bss_loop

clear_bss_done:
    jal main
    .option pop

retry:
    j boot

.section .text
.global entry_point
entry_point:
    fence.i
    # Reset interrupt registers, leave handler for exceptions
    csrw mie, 0
    csrw mstatus, 0
    jr a0