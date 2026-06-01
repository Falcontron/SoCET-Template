
.global memset
memset:
    # void *memset(void *s, int c, size_t n)
    mv a4, a0
    add a3, a0, a2
memset_loop:
    sb a1, 0(a0)
    addi a0, a0, 1
    blt a0, a3, memset_loop
memset_done:
    mv a4, a0
    ret


