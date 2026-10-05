    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start
_start:
    la      x5, trap_handler
    csrw    mtvec, x5
    li      x7, 8
    li      x8, 0x5a

bad_csr:
    csrrw   x8, 0x340, x7     # mscratch is unsupported in this V2 CPU

after_bad:
    li      x9, 0x5a
    bne     x8, x9, test_fail # illegal CSR must not write x8
    csrr    x10, mstatus
    andi    x10, x10, 8
    bne     x10, x0, test_fail # must not enable MIE through bad decode
    li      x11, 1
    jal     x0, test_pass

    .section .text.trap, "ax", @progbits
    .balign 4
trap_handler:
    csrr    x20, mcause
    li      x21, 2
    bne     x20, x21, trap_fail
    csrr    x22, mepc
    la      x23, bad_csr
    bne     x22, x23, trap_fail
    csrr    x24, mtval
    li      x25, 0x34039473  # exact encoding checked after assembly
    bne     x24, x25, trap_fail
    addi    x22, x22, 4
    csrw    mepc, x22
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
