    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start
_start:
    la      x5, unexpected_trap
    csrw    mtvec, x5
    addi    x1, x0, 0

    # This redirect collides with an ordinary stale fall-through response.
    jal     x0, edge_branch
wrong_path:
    jal     x0, test_fail

good_target:
    addi    x1, x1, 1
    jal     x0, test_pass

    .section .text.trap, "ax", @progbits
    .balign 4
unexpected_trap:
    jal     x0, test_fail

    # The branch itself is legal, but fetching its fall-through PC faults.
    # Its older EX redirect must discard that younger fetch fault.
    .section .edge, "ax", @progbits
    .balign 4
edge_branch:
    jal     x0, good_target

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
