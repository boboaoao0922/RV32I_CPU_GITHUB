    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    addi x1, x0, 16
    addi x2, x0, 4
    sub  x3, x1, x2
    addi x4, x0, 1
    addi x26,x0, 31
    sll  x5, x1, x26
    li   x6, 0xFFFFFFFF
    slt  x7, x4, x6
    slt  x8, x6, x4
    sltu x7, x4, x6
    sltu x8, x6, x4
    xor  x9, x4, x6
    xor  x10,x6, x4
    srl  x10,x6, x2
    li   x11,0xFFF0FFFF
    sra  x11,x11,x2
    or   x12,x1,x2
    and  x13,x6,x11
    slti x14,x4, 1
    slti x14,x4, 0
    slti x14,x4, 2
    sltiu x15,x4, -1
    sltiu x15,x4, 1
    xori x16, x4, 1
    xori x17, x6, 0xf
    ori x17, x0, 6
    andi x18, x6, -241
    slli x19, x4, 0
    slli x19, x4, 1
    slli x19, x4, 31
    srli x20, x11, 4
    srli x20, x11, 31
    srai x21, x11, 4
    srai x21, x11, 31
    lui  x22, 0x10
    auipc x23, 0x10
    jal x0, test_pass


fail_trampoline:
    jal  x0, test_fail


    # The testbench reports FAIL when the commit PC == 0x0000_FE00.
    .section .test.fail, "ax", @progbits
    .globl test_fail

test_fail:
    addi x0, x0, 0
    jal  x0, test_fail


    # The testbench reports PASS when the commit PC == 0x0000_FF00.
    .section .test.pass, "ax", @progbits
    .globl test_pass

test_pass:
    addi x0, x0, 0
    jal  x0, test_pass
