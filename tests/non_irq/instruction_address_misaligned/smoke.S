    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start

_start:
    # ---------------------------------------------------------
    # 1. Set the trap handler entry
    # ---------------------------------------------------------
    la      x5, trap_handler_jalr
    csrw    mtvec, x5
    csrsi   mstatus, 8
    # x10 serves as the test progress marker
    addi    x10, x0, 0
    addi    x2, x0, 0
    li      x1, 0x00010000
    addi    x1, x1, 2

Inst_misaliment_site_jalr:
    jalr    x0, 0(x1)

after_mret_jalr_test:
    la      x5, trap_handler_jal
    csrw    mtvec, x5

Inst_misaliment_site_jal:
    .insn 4, 0x0020006f    # jal x0, PC+2

after_mret_jal_test:
    la      x5, trap_handler_branch
    csrw    mtvec, x5

Inst_misaliment_site_branch:
    .insn 4, 0x00000163    # beq x0, x0, PC+2; always taken

after_mret_branch_test:
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

trap_handler_jalr:
    # ---------------------------------------------------------
    # 3. Check mcause
    # ---------------------------------------------------------
    csrr    x20, mcause
    addi    x21, x0, 0
    bne     x20, x21, fail_trampoline

    # ---------------------------------------------------------
    # 4. Check that mepc points to Inst_misaliment_site_jalr
    # ---------------------------------------------------------
    csrr    x22, mepc
    la      x23, Inst_misaliment_site_jalr
    bne     x22, x23, fail_trampoline

    csrr    x24, mtval
    bne     x24, x1, fail_trampoline
    # ---------------------------------------------------------
    #
    # ---------------------------------------------------------
    add     x5, x22, 4 
    csrw    mepc, x5

    # indicates that the handler actually ran
    addi    x10, x10, 1

    # ---------------------------------------------------------
    # 6. Return via mepc
    # ---------------------------------------------------------
    mret

trap_handler_jal:
    # ---------------------------------------------------------
    # 3. Check mcause
    # ---------------------------------------------------------
    csrr    x20, mcause
    addi    x21, x0, 0
    bne     x20, x21, fail_trampoline

    # ---------------------------------------------------------
    # 4. Check that mepc points to Inst_misaliment_site_jal
    # ---------------------------------------------------------
    csrr    x22, mepc
    la      x23, Inst_misaliment_site_jal 
    bne     x22, x23, fail_trampoline

    csrr    x24, mtval
    li      x6,  0x32   
    bne     x24, x6, fail_trampoline
    # ---------------------------------------------------------
    #
    # ---------------------------------------------------------
    add     x5, x22, 4 
    csrw    mepc, x5

    # indicates that the handler actually ran
    addi    x10, x10, 1

    # ---------------------------------------------------------
    # 6. Return via mepc
    # ---------------------------------------------------------
    mret

trap_handler_branch:
    # ---------------------------------------------------------
    # 3. Check mcause
    # ---------------------------------------------------------
    csrr    x20, mcause
    addi    x21, x0, 0
    bne     x20, x21, fail_trampoline

    # ---------------------------------------------------------
    # 4. Check that mepc points to Inst_misaliment_site_branch
    # ---------------------------------------------------------
    csrr    x22, mepc
    la      x23, Inst_misaliment_site_branch 
    bne     x22, x23, fail_trampoline

    csrr    x24, mtval
    li      x6,  0x42
    bne     x24, x6, fail_trampoline
    # ---------------------------------------------------------
    #
    # ---------------------------------------------------------
    add     x5, x22, 4 
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
