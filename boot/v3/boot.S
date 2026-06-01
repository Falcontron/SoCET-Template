
.extern main

#
# s0 - memory pointer
# s1 - UART pointer
# s2 - GPIO pointer
# t0
.global boot
.section .text.boot
boot:
    .option push
    .option norelax
    la sp, __stack_top
    la gp, __global_pointer$
    .option pop
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

1:
    j 1b
