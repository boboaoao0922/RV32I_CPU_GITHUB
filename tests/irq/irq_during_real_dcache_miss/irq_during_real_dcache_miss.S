    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start
_start:
    la      x5, trap_handler
    csrw    mtvec, x5
    li      x6, 0x800
    csrw    mie, x6
    li      x8, 0
    csrsi   mstatus, 8
    la      x1, data_word

    .globl irq_load
irq_load:
    lw      x12, 0(x1)

    .globl after_load
after_load:
    .globl irq_wait
irq_wait:
    addi    x14, x14, 0
    jal     x0, irq_wait

    .globl after_irq
after_irq:
    li      x13, 0x13579bdf
    bne     x12, x13, test_fail
    addi    x6, x0, 1
    bne     x8, x6, test_fail
    jal     x0, test_pass

    .section .text.trap, "ax", @progbits
    .balign 4
    .globl trap_handler
trap_handler:
    addi    x8, x8, 1
    addi    x6, x0, 1
    bne     x8, x6, test_fail
    csrr    x20, mcause
    li      x21, 0x8000000b
    bne     x20, x21, test_fail
    csrr    x22, mepc
    csrr    x24, mtval
    bne     x24, x0, test_fail
    la      x25, after_irq
    csrw    mepc, x25
    mret

    .section .data, "aw", @progbits
    .balign 4
data_word:
    .word   0x13579bdf

    .section .test.fail, "ax", @progbits
test_fail:
    addi    x0, x0, 0
    jal     x0, test_fail

    .section .test.pass, "ax", @progbits
test_pass:
    addi    x0, x0, 0
    jal     x0, test_pass

