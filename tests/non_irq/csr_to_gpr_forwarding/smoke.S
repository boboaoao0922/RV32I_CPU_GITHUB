    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    la      x5, unexpected_trap
    csrw    mtvec, x5

    # Set a nonzero CSR old value; leave enough independent instructions so
    # the tests below isolate CSR-result -> GPR forwarding, not CSR RAW stalls.
    csrwi   mtval, 21
    li      x1, 0x00010000
    addi    x2, x0, 21
    addi    x3, x0, 7

    # CSR result in EX/MEM, consumed through rs1 and rs2 respectively.
    csrr    x10, mtval
exmem_rs1:
    addi    x11, x10, 1
    csrr    x12, mtval
exmem_rs2:
    add     x13, x0, x12

    # One independent instruction makes the CSR result come from MEM/WB.
    csrr    x14, mtval
    addi    x15, x0, 7
memwb_rs1:
    add     x16, x14, x0
    csrr    x17, mtval
    addi    x18, x0, 9
memwb_rs2:
    add     x19, x0, x17

    # Store data uses the same rs2 forwarding mux. Loads check actual memory.
    csrr    x20, mtval
exmem_store:
    sw      x20, 0(x1)
    lw      x21, 0(x1)

    csrr    x22, mtval
    addi    x23, x0, 1
memwb_store:
    sw      x22, 4(x1)
    lw      x24, 4(x1)

    addi    x25, x0, 22
    bne     x11, x25, fail_trampoline
    bne     x13, x2, fail_trampoline
    bne     x16, x2, fail_trampoline
    bne     x19, x2, fail_trampoline
    bne     x21, x2, fail_trampoline
    bne     x24, x2, fail_trampoline
    jal     x0, test_pass

fail_trampoline:
    jal     x0, test_fail

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
