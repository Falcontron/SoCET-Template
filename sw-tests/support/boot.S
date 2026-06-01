.text
.globl boot
.section .text.boot
boot:
    .option push
    .option norelax
    la sp, __stack_top
    la gp, __global_pointer$
    .option pop
    la s4, bss_cleared
    li t0, 0x800
    csrr t1, mhartid
    addi t2, t1, 1
    mul t3, t2, t0
    sub sp, sp, t3
    bnez t1, wait_for_setup_done

clr_bss:
    la t0, __bss_start
    la t1, __bss_end
    beq t0, t1, do_preinit_arr

clr_bss_loop:
    sb zero, 0(t0)
    addi t0, t0, 1
    ble t0, t1, clr_bss_loop

do_preinit_arr:
    la s0, __preinit_array_start
    la s1, __preinit_array_end
    beq s0, s1, do_init_arr

preinit_arr_calls:
    lw s2, 0(s0)
    jalr ra, s2
    addi s0, s0, 4
    bne s0, s1, preinit_arr_calls

do_init_arr:
    la s0, __init_array_start
    la s1, __init_array_end
    beq s0, s1, indicate_setup_done

init_arr_calls:
    lw s2, 0(s0)
    jalr ra, s2
    addi s0, s0, 4
    bne s0, s1, init_arr_calls

indicate_setup_done:
    addi t0, zero, 1
    fence rw, rw
    sw t0, 0(s4)

wait_for_setup_done:
    lw t0, 0(s4)
    beqz t0, wait_for_setup_done
    fence rw, rw

enter_kernel:
    j kmain

.global __sim_wfi
__sim_wfi:
    wfi
    ret

.global __sim_halt
__sim_halt:
    j __sim_halt

.data
.p2align 2
.global bss_cleared
bss_cleared: .word 0x00
