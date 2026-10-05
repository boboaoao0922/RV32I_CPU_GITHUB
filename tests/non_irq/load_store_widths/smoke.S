    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    lui  x1, 0x10 
    li x2, 0x5678ABCD
    sw   x2, 0(x1)
    lw   x3, 0(x1)
    lh   x4, 0(x1)
    lh   x5, 2(x1)
    lb   x6, 0(x1)
    lb   x7, 1(x1)
    lb   x8, 2(x1)
    lb   x9, 3(x1)
    lhu  x10,0(x1)
    lhu  x11,2(x1)
    lbu  x12,0(x1)
    lbu  x13,1(x1)
    lbu  x14,2(x1)
    lbu  x15,3(x1)
    sw   x0, 0(x1)
    sh   x2, 0(x1)
    lw   x16,0(x1)
    sw   x0, 0(x1)
    sh   x2, 2(x1)
    lw   x17,(x1)
    sw   x0, 0(x1)
    sb   x2, 0(x1)
    lw   x18,0(x1)
    sw   x0, 0(x1)
    sb   x2, 1(x1)
    lw   x19,0(x1)
    sw   x0, 0(x1)
    sb   x2, 2(x1)
    lw   x20,0(x1)
    sw   x0, 0(x1)
    sb   x2, 3(x1)
    lw   x21,0(x1)
    jal  x0, test_pass   
    jal  x3, test_fail       # wrong path, must never commit

branch_taken:
    jal  x1, test_pass

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
