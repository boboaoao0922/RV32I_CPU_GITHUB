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

ebreak_site:
    # ---------------------------------------------------------
    # 2. Trigger a machine-mode EBREAK
    # ---------------------------------------------------------
    ebreak

after_ecall:
    # The handler should first increment x10 from 0 to 1,
    # and after MRET returns, x10 is incremented from 1 to 2 here.
    addi    x10, x10, 1

    addi    x11, x0, 2
    bne     x10, x11, fail_trampoline
    
    csrr    x25, mstatus
    andi     x1, x25, 0x80
    andi     x2, x25, 8
    li       x3, 0x80
    bne      x1, x3, fail_trampoline
    beq      x2, x0, fail_trampoline

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
    # Breakpoint should be 3
    # ---------------------------------------------------------
    csrr    x20, mcause
    addi    x21, x0, 3
    bne     x20, x21, fail_trampoline

    # ---------------------------------------------------------
    # 4. Check that mepc points to the EBREAK itself
    # ---------------------------------------------------------
    csrr    x22, mepc
    la      x23, ebreak_site
    bne     x22, x23, fail_trampoline

    # mtval should be 0 for EBREAK
    csrr    x24, mtval
    bne     x24, x0, fail_trampoline

    csrr    x25, mstatus
    andi     x1, x25, 0x80
    andi     x2, x25, 8
    li       x3, 0x80
    bne      x1, x3, fail_trampoline
    bne      x2, x0, fail_trampoline
    # ---------------------------------------------------------
    #
    # ---------------------------------------------------------
    addi    x22, x22, 4
    csrw    mepc, x22

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