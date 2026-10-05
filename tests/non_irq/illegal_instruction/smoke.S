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
    li      x7, 0x55
    .option push
    .option arch, +m
illegal_site:
    mul x7, x0, x0
    .option pop

after_mret:
    beq x7, x0, fail_trampoline
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
    addi    x21, x0, 2
    bne     x20, x21, fail_trampoline

    # ---------------------------------------------------------
    # 4. Check that mepc points to illegal_site
    # ---------------------------------------------------------
    csrr    x22, mepc
    la      x23, illegal_site
    bne     x22, x23, fail_trampoline

    csrr    x24, mtval
    li      x25, 0x020003b3
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
