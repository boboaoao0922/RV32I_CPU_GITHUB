    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    # x1 = 5
    lui  x4, 0x10
    addi x1, x0, 5
    addi x2, x0, 6
    add  x3, x1, x2
    sw   x3, 0(x4)
    lw   x5, 0(x4)
    sub  x6, x5, x3
    beq  x0, x6, branch_taken 
    jal  x0, fail_trampoline

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
