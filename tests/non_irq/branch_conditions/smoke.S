    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    addi x1, x0, 0
    addi x2, x0, 0
    beq  x1, x2, beq_0_0_taken # 0 == 0, taken
    jal  x0, test_fail       # wrong path, must never commit

beq_0_0_taken:
    addi x1, x1, 1
    beq  x1, x2, fail_trampoline   #1 != 0 , not taken
    jal  x0, test_bne  #jump to test bne

test_bne:
    bne x0, x2, fail_trampoline # 0 == 0 , not taken
    bne x1, x2, test_blt # 1 != 0 , taken 

test_blt:
    li  x2, 0xFFFFFFFF
    blt x1, x2, fail_trampoline # 1 is not less than signed -1, not taken
    blt x2, x1, test_bltu # -1 is less than 1, taken

test_bltu:
    bltu x2, x1, fail_trampoline # 0xFFFF_FFFF is not less than 1, not taken
    bltu x1, x2, test_bge # 1 is less than 0xFFFF_FFFF, taken

test_bge:
    li   x2, 0x80000000
    addi x1, x0, 0
    bge  x2, x1, fail_trampoline # -2147483648 < 0, not taken
    bge  x1, x2, test_bge2 # 0 > -2147483648, taken

test_bge2:
    li  x1, 0x7fffffff
    bge x2, x1, fail_trampoline # -2147483648 < 2147483647, not taken
    bge x1, x2, test_bge3 # 2147483647 >= -2147483648, taken
test_bge3:
    bge x0, x0, test_bgeu # 0 >= 0, taken
    jal x0, test_fail 

test_bgeu:
    bgeu x1, x2, fail_trampoline # 2147483647 < 2147483648, not taken
    bgeu x2, x1, test_bgeu2  # 2147483648 >= 2147483647, taken

test_bgeu2:
    bgeu x0, x0, test_pass # 0 >= 0, taken
    jal  x0, test_fail

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
