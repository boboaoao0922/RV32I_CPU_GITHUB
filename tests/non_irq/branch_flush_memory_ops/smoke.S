    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    lui x1, 0x10
    addi x2, x0, 8
    addi x3, x0, 10
    addi x4, x0, 10
    addi x5, x0, 20
    add x8, x5, x5
    sw x5, 0(x1)
    sw x4, 4(x1)
    lw x6, 0(x1)
    sw x3, 8(x1)
    lw x7, 4(x1)
    beq x3, x4, test2
    lw x9, 8(x1)
    sw x8, 4(x1)
    jal x0, test_fail

test2: 
    lw  x10, 4(x1)
    lw  x10, 4(x1)
    add x11, x10, x10
    beq x8, x10, fail_trampoline
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
