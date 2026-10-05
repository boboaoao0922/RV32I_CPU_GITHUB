    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    la      x5, unexpected_trap
    csrw    mtvec, x5

    addi    x10, x0, 4
    addi    x11, x0, 13

    # INT-09: ID must wait for each older same-address CSR writer to commit.
    csrwi   mepc, 4
read_mepc_after_write:
    csrr    x6, mepc
    csrwi   mtval, 13
read_mtval_after_write:
    csrr    x7, mtval

    # A read-only CSR instruction is not a CSR writer.
read_mtval_after_read:
    csrr    x8, mtval

    # A younger read of a different CSR address must not wait for mepc.
    csrwi   mepc, 8
read_other_csr:
    csrr    x9, mtval

    bne     x6, x10, fail_trampoline
    bne     x7, x11, fail_trampoline
    bne     x8, x11, fail_trampoline
    bne     x9, x11, fail_trampoline
    jal     x0, test_pass

fail_trampoline:
    jal     x0, test_fail

    .section .text.trap, "ax", @progbits
    .balign 4
unexpected_trap:
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
