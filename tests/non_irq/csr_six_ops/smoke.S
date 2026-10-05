    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start
_start:
    la      x5, unexpected_trap
    csrw    mtvec, x5
    li      x1, 0xf0
    li      x2, 0x0f
    li      x3, 0x03

    # All six Zicsr forms use a nonzero rd, so each must return the old
    # mtval while updating it according to its own operation.
    csrrw   x10, mtval, x1     # old 0x00; new 0xf0
    csrrs   x11, mtval, x2     # old 0xf0; new 0xff
    csrrc   x12, mtval, x3     # old 0xff; new 0xfc
    csrrwi  x13, mtval, 5      # old 0xfc; new 0x05
    csrrsi  x14, mtval, 2      # old 0x05; new 0x07
    csrrci  x15, mtval, 1      # old 0x07; new 0x06
    csrr    x16, mtval         # old 0x06; read only

    # Zero source in CSRRS/CSRRC does not write, whereas CSRRWI zimm=0 does.
    csrrs   x17, mtval, x0
    csrrc   x18, mtval, x0
    csrrsi  x19, mtval, 0
    csrrci  x20, mtval, 0
    csrrwi  x21, mtval, 0      # old 0x06; new 0x00
    csrr    x22, mtval         # observe the final zero

    li      x23, 0
    bne     x10, x23, test_fail
    li      x23, 0xf0
    bne     x11, x23, test_fail
    li      x23, 0xff
    bne     x12, x23, test_fail
    li      x23, 0xfc
    bne     x13, x23, test_fail
    li      x23, 5
    bne     x14, x23, test_fail
    li      x23, 7
    bne     x15, x23, test_fail
    li      x23, 6
    bne     x16, x23, test_fail
    bne     x17, x23, test_fail
    bne     x18, x23, test_fail
    bne     x19, x23, test_fail
    bne     x20, x23, test_fail
    bne     x21, x23, test_fail
    li      x23, 0
    bne     x22, x23, test_fail
    jal     x0, test_pass

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
