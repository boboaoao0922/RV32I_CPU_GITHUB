    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    # ---------------------------------------------------------
    # 1. Set the trap handler entry
    # ---------------------------------------------------------
    la      x5, trap_handler_lw_acc_fault
    csrw    mtvec, x5
    csrsi   mstatus, 8
    addi    x1, x0, 0
    li      x3, 0
    li      x2, 6
lw_acc_fault:
    lw      x3, 4(x1)

lw_acc_check:
    bne     x1, x3, fail_trampoline

modify_mtvec:
    la      x5, trap_handler_sw_acc_fault
    csrw    mtvec, x5

sw_acc_fault:
    sw      x2, 8(x1)

after_mret:
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

trap_handler_lw_acc_fault:
    # ---------------------------------------------------------
    # 3. Check mcause
    # ---------------------------------------------------------
    csrr    x20, mcause
    addi    x21, x0, 5
    bne     x20, x21, fail_trampoline

    # ---------------------------------------------------------
    # 4. Check that mepc points to illegal_site
    # ---------------------------------------------------------
    csrr    x22, mepc
    la      x23, lw_acc_fault
    bne     x22, x23, fail_trampoline

    csrr    x24, mtval
    li      x25, 4
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

trap_handler_sw_acc_fault:
    # ---------------------------------------------------------
    # 3. Check mcause
    # ---------------------------------------------------------
    csrr    x20, mcause
    addi    x21, x0, 7
    bne     x20, x21, fail_trampoline

    # ---------------------------------------------------------
    # 4. Check that mepc points to illegal_site
    # ---------------------------------------------------------
    csrr    x22, mepc
    la      x23, sw_acc_fault
    bne     x22, x23, fail_trampoline

    csrr    x24, mtval
    li      x25, 8
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
