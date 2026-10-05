    .option norvc
    .option norelax

    .section .text.start, "ax", @progbits
    .globl _start
_start:
    jal     zero, dirty_eviction_test

    .section .text.test, "ax", @progbits
    .globl dirty_eviction_test
dirty_eviction_test:
    # D-cache geometry in this project:
    #   16-byte line, 64 sets, 4 ways
    # Therefore addresses separated by 0x400 have the same set index [9:4].
    # Five dirty lines in one set force at least one dirty eviction.
    .globl perf_region_begin
perf_region_begin:
    lui     x5, 0x10              # x5 = 0x0001_0000
    addi    x6, zero, 5           # five conflicting cache lines
    addi    x10, zero, 1          # distinct word signature: 1..20

write_conflicting_lines:
    sw      x10, 0(x5)
    addi    x10, x10, 1
    sw      x10, 4(x5)
    addi    x10, x10, 1
    sw      x10, 8(x5)
    addi    x10, x10, 1
    sw      x10, 12(x5)
    addi    x10, x10, 1

    addi    x5, x5, 1024          # next tag, same D-cache set
    addi    x6, x6, -1
    bne     x6, zero, write_conflicting_lines

    # Reload every word from all five lines. This deliberately does not assume
    # which way the LRU policy selected first. At least one line must come back
    # through DRAM after a dirty writeback, and every value is checked.
    lui     x5, 0x10
    addi    x6, zero, 5
    addi    x10, zero, 1
    addi    x12, zero, 0          # checksum of 1..20

read_and_check_lines:
    lw      x11, 0(x5)
    bne     x11, x10, fail_near
    add     x12, x12, x11
    addi    x10, x10, 1

    lw      x11, 4(x5)
    bne     x11, x10, fail_near
    add     x12, x12, x11
    addi    x10, x10, 1

    lw      x11, 8(x5)
    bne     x11, x10, fail_near
    add     x12, x12, x11
    addi    x10, x10, 1

    lw      x11, 12(x5)
    bne     x11, x10, fail_near
    add     x12, x12, x11
    addi    x10, x10, 1

    addi    x5, x5, 1024
    addi    x6, x6, -1
    bne     x6, zero, read_and_check_lines

    addi    x13, zero, 210        # 1 + 2 + ... + 20
    bne     x12, x13, fail_near

    .globl perf_region_end
perf_region_end:
    addi    x14, zero, 0
    jal     zero, test_pass

fail_near:
    jal     zero, test_fail

    .section .test.fail, "ax", @progbits
    .globl test_fail
test_fail:
    addi    zero, zero, 0
    jal     zero, test_fail

    .section .test.pass, "ax", @progbits
    .globl test_pass
test_pass:
    addi    zero, zero, 0
    jal     zero, test_pass
