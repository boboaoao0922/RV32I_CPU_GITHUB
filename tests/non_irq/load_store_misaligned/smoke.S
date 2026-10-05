    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    # ---------------------------------------------------------
    # 1. Set the trap handler entry
    # ---------------------------------------------------------
    la      x5, trap_handler_lw_misalignment
    csrw    mtvec, x5
    csrsi   mstatus, 8
    li      x1, 0x00010000
    li      x2, 666
    li      x3, 0
    li      x4, 41
    sw      x2, 0(x1)
    sw      x3, 4(x1)
lw_misalignment:
    lw      x3, 1(x1)

check_lw_result:
    beq     x2, x3, fail_trampoline

modify_mtvec:
    la      x5, trap_handler_sw_misalignment
    csrw    mtvec, x5

sw_misalignment:
    sw      x4, 2(x1)

after_mret:
    lw      x4, 0(x1)
    bne     x4, x2, fail_trampoline
    lw      x4, 4(x1)
    bne     x4, x3, fail_trampoline
    jal     x0, test_pass

fail_trampoline:
    # A conditional branch cannot reach 0xFE00, so jump to a nearby trampoline first.
    jal     x0, test_fail


    # ---------------------------------------------------------
    # Trap handler
    # The linker script collects this section through *(.text.*).
    # ---------------------------------------------------------
    .section .text.trap, "ax", @progbits
    .balign 4
    .globl trap_handler

trap_handler_lw_misalignment:
    # ---------------------------------------------------------
    # 3. Check mcause
    # ---------------------------------------------------------
    csrr    x20, mcause
    addi    x21, x0, 4
    bne     x20, x21, fail_trampoline

    # ---------------------------------------------------------
    # 4. Check that mepc points to illegal_site
    # ---------------------------------------------------------
    csrr    x22, mepc
    la      x23, lw_misalignment
    bne     x22, x23, fail_trampoline

    csrr    x24, mtval
    li      x25, 0x00010001
    bne     x24, x25 , fail_trampoline
    # ---------------------------------------------------------
    #
    # ---------------------------------------------------------
    add     x5, x22, 4 
    csrw    mepc, x5
    # ---------------------------------------------------------
    # 6. Return via mepc
    # ---------------------------------------------------------
    mret

trap_handler_sw_misalignment:
    # ---------------------------------------------------------
    # 3. Check mcause
    # ---------------------------------------------------------
    csrr    x20, mcause
    addi    x21, x0, 6
    bne     x20, x21, fail_trampoline

    # ---------------------------------------------------------
    # 4. Check that mepc points to illegal_site
    # ---------------------------------------------------------
    csrr    x22, mepc
    la      x23, sw_misalignment
    bne     x22, x23, fail_trampoline

    csrr    x24, mtval
    li      x25, 0x00010002
    bne     x24, x25 , fail_trampoline
    # ---------------------------------------------------------
    #
    # ---------------------------------------------------------
    add     x5, x22, 4 
    csrw    mepc, x5
    # ---------------------------------------------------------
    # 6. Return via mepc
    # ---------------------------------------------------------
    mret


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
