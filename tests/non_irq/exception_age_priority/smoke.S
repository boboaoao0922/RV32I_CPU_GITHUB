    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    la      x5, trap_handler
    csrw    mtvec, x5

    li      x1, 0x00020000      # first address beyond the D-cache's legal data window
    li      x2, 0x123
    li      x4, 0x00010000
    sw      x2, 0(x4)           # prove killed younger stores do not change it
    li      x3, 0x33
    li      x5, 0x55
    li      x6, 0x66
    li      x8, 0x88
    li      x9, 2               # JALR target: instruction-misaligned

    # Three older MEM access faults each suppress a different younger EX
    # exception and a different younger ID exception.
    li      x30, 1
case1_fault:
    lw      x3, 0(x1)           # older load access fault
    sw      x2, 1(x4)           # younger store-misaligned EX fault
    .word   0xffffffff         # younger illegal instruction in ID
after_case1:
    li      x30, 2
case2_fault:
    lw      x5, 0(x1)
    lw      x6, 1(x4)           # younger load-misaligned EX fault
    ecall                       # younger ECALL in ID
after_case2:
    li      x30, 3
case3_fault:
    lw      x8, 0(x1)
    jalr    x0, 0(x9)           # younger instruction-misaligned EX fault
    ebreak                      # younger EBREAK in ID
after_case3:
    lw      x7, 0(x4)
    li      x10, 0x33
    li      x11, 0x55
    li      x12, 0x66
    li      x13, 0x88
    bne     x3, x10, fail_trampoline
    bne     x5, x11, fail_trampoline
    bne     x6, x12, fail_trampoline
    bne     x8, x13, fail_trampoline
    bne     x7, x2, fail_trampoline
    jal     x0, test_pass

fail_trampoline:
    jal     x0, test_fail

    .section .text.trap, "ax", @progbits
    .balign 4
trap_handler:
    csrr    x20, mcause
    li      x21, 5
    bne     x20, x21, trap_fail
    csrr    x22, mepc
    csrr    x24, mtval
    bne     x24, x1, trap_fail

    li      x25, 1
    beq     x30, x25, handle_case1
    li      x25, 2
    beq     x30, x25, handle_case2
    li      x25, 3
    bne     x30, x25, trap_fail

handle_case3:
    la      x26, case3_fault
    bne     x22, x26, trap_fail
    la      x29, after_case3
    csrw    mepc, x29
    mret

handle_case1:
    la      x26, case1_fault
    bne     x22, x26, trap_fail
    la      x29, after_case1
    csrw    mepc, x29
    mret

handle_case2:
    la      x26, case2_fault
    bne     x22, x26, trap_fail
    la      x29, after_case2
    csrw    mepc, x29
    mret

trap_fail:
    jal     x0, test_fail

    .section .test.fail, "ax", @progbits
    .globl test_fail
test_fail:
    addi    x0, x0, 0
    jal     x0, test_fail

    .section .test.pass, "ax", @progbits
    .globl test_pass
test_pass:
    addi    x0, x0, 0
    jal     x0, test_pass
