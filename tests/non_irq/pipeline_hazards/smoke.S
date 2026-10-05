    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    lui x1, 0x10  
    la x2, test_load_branch_rs1
    sw x2, 0(x1)
    lw x3, 0(x1)
    jalr x4, 0(x3)
    jal x0, test_fail

test_load_branch_rs1:
    addi x4, x0, 4
    addi x5, x0, 5
    sw x4, 0(x1)
    sw x5, 4(x1)
    lw x6, 0(x1)
    lw x7, 4(x1)
    bne x7, x6, test_alu_store_addr
    jal x0, test_fail

test_alu_store_addr:
    addi x3, x1, 4
    sw x4, 0(x3)
    jal x0, test_load_store_data

test_load_store_data:
    lw x5, 0(x3)
    sw x5, 4(x3)
    lw x6, 4(x3)
    beq x6, x4, test_load_store_addr
    jal x0, test_fail

test_load_store_addr:
    sw x1, 0(x1)
    lw x6, 0(x1)
    sw x4, 0(x6)
    lw x5, 0(x6)
    beq x5, x4, test_store_wrong_path
    jal x0, test_fail

test_store_wrong_path:
    addi x8, x0, 11
    addi x9, x0, 11
    sw x0, 0(x1)
    sw x0, 4(x1)
    beq x5, x4, test_store_wrong_path_conti
    sw x8, 0(x1)
    sw x9, 4(x1)
    jal x0, test_fail

test_store_wrong_path_conti:
    lw x10, 0(x1)
    lw x11, 4(x1)
    beq x10, x8, fail_trampoline
    beq x11, x8, fail_trampoline
    jal x0, test_WB_ID_same_addr

test_WB_ID_same_addr:
    addi x1, x0, 1
    addi x0, x0, 0
    addi x0, x0, 0
    add x2, x1, x1
    addi x3, x0, 2
    bne x2, x3, fail_trampoline
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
