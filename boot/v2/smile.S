.section .text.boot
.global boot
boot:
    li t0, 0xB0000000
    li t1, ':'
    li t2, ')'
    li t3, '\n'
    sb t1, 0(t0)
    sb t2, 0(t0)
    sb t3, 0(t0)

done:
    j done
