    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    # ---------------------------------------------------------
    # 1. Set the trap handler entry
    # ---------------------------------------------------------
    la      x5, trap_handler
    csrw    mtvec, x5
    csrsi   mstatus, 8
    # x10 serves as the test progress marker
    addi    x10, x0, 0
    addi    x2, x0, 0
    li      x1, 0x00010000

Inst_acc_fault_site:
    jalr    x0, 0(x1)

after_mret:
    addi    x2, x0, 5
    addi    x3, x0, 6
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

trap_handler:
    # ---------------------------------------------------------
    # 3. Check mcause
    # ---------------------------------------------------------
    csrr    x20, mcause
    addi    x21, x0, 1
    bne     x20, x21, fail_trampoline

    # ---------------------------------------------------------
    # 4. Check that mepc points to the faulting fetch address
    # ---------------------------------------------------------
    csrr    x22, mepc
    li      x23, 0x00010000
    bne     x22, x23, fail_trampoline

    csrr    x24, mtval
    bne     x24, x1, fail_trampoline
    # ---------------------------------------------------------
    #
    # ---------------------------------------------------------
    la      x5, after_mret
    csrw    mepc, x5

    # indicates that the handler actually ran
    addi    x10, x10, 1

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