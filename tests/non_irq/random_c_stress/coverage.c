#include <stdint.h>

// This is a normal RV32I program. The inline assembly makes the instruction
// and branch bins deterministic; only the DRAM latency varies with the seed.
static volatile int8_t signed_bytes[4];
static volatile uint8_t unsigned_bytes[4];
static volatile int16_t signed_halves[4];
static volatile uint16_t unsigned_halves[4];
static volatile uint32_t words[8];
static volatile uint32_t signature;

#define CHECK_R(OP, A, B, WANT) do {                                    \
    uint32_t got;                                                        \
    __asm__ volatile(OP " %0, %1, %2" : "=r"(got)                         \
                     : "r"((uint32_t)(A)), "r"((uint32_t)(B)));          \
    if (got != (uint32_t)(WANT)) ++errors;                               \
} while (0)

#define CHECK_I(OP, A, IMM, WANT) do {                                   \
    uint32_t got;                                                        \
    __asm__ volatile(OP " %0, %1, " #IMM : "=r"(got)                      \
                     : "r"((uint32_t)(A)));                              \
    if (got != (uint32_t)(WANT)) ++errors;                               \
} while (0)

#define CHECK_BRANCH(OP, A, B, WANT) do {                               \
    uint32_t taken;                                                      \
    __asm__ volatile(                                                   \
        "addi %0, zero, 0\n\t"                                           \
        OP " %1, %2, 1f\n\t"                                             \
        "jal zero, 2f\n\t"                                              \
        "1: addi %0, zero, 1\n\t"                                       \
        "2:\n\t"                                                       \
        : "=&r"(taken)                                                  \
        : "r"((uint32_t)(A)), "r"((uint32_t)(B)));                       \
    if (taken != (uint32_t)(WANT)) ++errors;                             \
} while (0)

__attribute__((noinline))
static uint32_t exercise_alu(uint32_t pos, uint32_t small,
                             uint32_t neg, uint32_t shift) {
    uint32_t errors = 0;

    CHECK_R("add",  pos, small, pos + small);
    CHECK_R("sub",  pos, small, pos - small);
    CHECK_R("sll",  pos, shift, pos << shift);
    CHECK_R("slt",  neg, pos, 1);
    CHECK_R("sltu", pos, neg, 1);
    CHECK_R("xor",  pos, small, pos ^ small);
    CHECK_R("srl",  pos, shift, pos >> shift);
    CHECK_R("sra",  neg, shift, 0xfffffff8u);
    CHECK_R("or",   pos, small, pos | small);
    CHECK_R("and",  pos, small, pos & small);

    CHECK_I("addi",  pos, 17, pos + 17u);
    CHECK_I("slti",  neg, 0, 1);
    CHECK_I("sltiu", small, 2047, 1);
    CHECK_I("xori",  pos, 85, pos ^ 85u);
    CHECK_I("ori",   pos, 85, pos | 85u);
    CHECK_I("andi",  pos, 255, pos & 255u);
    CHECK_I("slli",  pos, 4, pos << 4);
    CHECK_I("srli",  pos, 4, pos >> 4);
    CHECK_I("srai",  neg, 3, 0xfffffff8u);

    return errors;
}

__attribute__((noinline))
static uint32_t exercise_branches(uint32_t negative, uint32_t positive) {
    uint32_t errors = 0;

    CHECK_BRANCH("beq",  negative, negative, 1);
    CHECK_BRANCH("beq",  negative, positive, 0);
    CHECK_BRANCH("bne",  negative, positive, 1);
    CHECK_BRANCH("bne",  positive, positive, 0);
    CHECK_BRANCH("blt",  negative, positive, 1);
    CHECK_BRANCH("blt",  positive, negative, 0);
    CHECK_BRANCH("bge",  positive, negative, 1);
    CHECK_BRANCH("bge",  negative, positive, 0);
    CHECK_BRANCH("bltu", positive, negative, 1);
    CHECK_BRANCH("bltu", negative, positive, 0);
    CHECK_BRANCH("bgeu", negative, positive, 1);
    CHECK_BRANCH("bgeu", positive, negative, 0);

    return errors;
}

int main(void) {
    uint32_t errors = 0;
    uint32_t mix = 0x12345678u;

    signed_bytes[0] = -7;
    unsigned_bytes[0] = 0xd2u;
    signed_halves[0] = -12345;
    unsigned_halves[0] = 0x8123u;
    words[0] = 0x1234u;
    words[1] = 0x100u;
    words[2] = 0xffffffc0u;

    if ((int32_t)signed_bytes[0] != -7) ++errors;
    if ((uint32_t)unsigned_bytes[0] != 0xd2u) ++errors;
    if ((int32_t)signed_halves[0] != -12345) ++errors;
    if ((uint32_t)unsigned_halves[0] != 0x8123u) ++errors;

    // GCC may implement signed narrow reads with LBU/LHU plus shifts.
    // Exercise the architectural LB/LH sign extension explicitly as well.
    uint32_t signed_load;
    __asm__ volatile("lb %0, 0(%1)" : "=r"(signed_load)
                     : "r"(&signed_bytes[0]) : "memory");
    if ((int32_t)signed_load != -7) ++errors;
    __asm__ volatile("lh %0, 0(%1)" : "=r"(signed_load)
                     : "r"(&signed_halves[0]) : "memory");
    if ((int32_t)signed_load != -12345) ++errors;

    uint32_t pos = words[0];
    uint32_t small = words[1];
    uint32_t neg = words[2];
    uint32_t shift = 3;
    errors += exercise_alu(pos, small, neg, shift);
    errors += exercise_branches(neg, small);

    for (uint32_t i = 3; i < 8; ++i) {
        uint32_t value = (i << 9) ^ (i + 0x5a5u);
        words[i] = value;
        if (words[i] != value) ++errors;
        mix ^= (value << (i & 7u)) | (value >> (32u - (i & 7u)));
    }

    __asm__ volatile("fence rw, rw" ::: "memory");
    signature = mix ^ errors;
    return errors == 0 ? 0 : 1;
}
