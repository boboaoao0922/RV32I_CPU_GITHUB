    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    # x1 = 5
    addi x1, x0, 5

    # BNE can only compare two registers, so x2 is first set to 5.
    addi x2, x0, 5

    # Go to FAIL when x1 != 5; go to PASS when x1 == 5.
    # Jump to a nearby label first, so BNE does not target 0xFE00 directly and exceed the branch range.
    bne  x1, x2, fail_trampoline
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
