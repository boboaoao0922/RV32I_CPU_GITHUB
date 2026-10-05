    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    lui x1, 0x10  
    addi x2,x0, 5
    sw x2, 0(x1)
    sw x2, 0(x1)
    lw x3, 0(x1)
    lw x3, 0(x1)
    bne x2, x3, fail_trampoline
    add x4, x2, x3
    add x4, x2, x1
    add x5, x4, x3
    add x0, x4, x3
    add x0, x3, x2
    add x6, x0 ,x0
    bne x6, x0, fail_trampoline
    la x6, test_pass
    addi x6, x6, 16
    jalr x0, -16(x6)
    jal x0, test_fail


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
