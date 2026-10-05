    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start
_start:
    li      x1, 0x00010000
    li      x2, 0x155
    sw      x2, 0(x1)

fence_after_store:
    fence   rw, rw            # V2 contract: ordinary no-op retire

    lw      x3, 0(x1)
    li      x4, 0x155
    bne     x3, x4, test_fail

fence_after_load:
    fence   rw, rw
    li      x10, 1
    jal     x0, test_pass

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
