    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    # x1 = 5
    addi x1, x0, 5

    # BNE can only compare two registers, so x2 is first set to 5.
    addi x2, x0, 6

    bne  x1, x2, branch_taken
    addi x3, x0, 3
    addi x4, x0, 4
    jal  x0, fail_trampoline

branch_taken:
    jal  x0, test_pass

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
