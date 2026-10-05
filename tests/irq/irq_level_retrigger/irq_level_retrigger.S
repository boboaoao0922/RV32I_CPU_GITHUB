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
    li      x10, 0
    csrsi   mstatus, 8

    .globl irq_wait
irq_wait:
    addi    x10, x10, 0
    jal     x0, irq_wait

    .globl retrigger_wait
retrigger_wait:
    addi    x10, x10, 0
    jal     x0, retrigger_wait

    .globl after_irq
after_irq:
    addi    x10, x0, 0x53
    addi    x6, x0, 2
    bne     x8, x6, test_fail
    jal     x0, test_pass

    .section .text.trap, "ax", @progbits
    .balign 4
    .globl trap_handler
trap_handler:
    addi    x8, x8, 1
    csrr    x20, mcause
    li      x21, 0x8000000b
    bne     x20, x21, test_fail
    csrr    x22, mepc
    csrr    x24, mtval
    bne     x24, x0, test_fail

    addi    x9, x0, 1
    beq     x8, x9, first_return
    addi    x9, x0, 2
    beq     x8, x9, second_return
    jal     x0, test_fail

first_return:
    la      x23, irq_wait
    beq     x22, x23, 1f
    addi    x23, x23, 4
    bne     x22, x23, test_fail
1:
    la      x25, retrigger_wait
    csrw    mepc, x25
    mret

second_return:
    la      x23, retrigger_wait
    beq     x22, x23, 2f
    addi    x23, x23, 4
    bne     x22, x23, test_fail
2:
    la      x25, after_irq
    csrw    mepc, x25
    mret

    .section .test.fail, "ax", @progbits
test_fail:
    addi    x0, x0, 0
    jal     x0, test_fail

    .section .test.pass, "ax", @progbits
test_pass:
    addi    x0, x0, 0
    jal     x0, test_pass

