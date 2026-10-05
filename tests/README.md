# Test Programs / 測試程式

- [中文說明](#中文說明)
- [English](#english)

## 中文說明

這個目錄保存 system-level CPU 測試使用的程式、DRAM image 與預期結果，
目前共有 30 支一般測試及 3 支 interrupt 測試。

### 目錄結構

```text
tests/
|-- non_irq/   # 使用固定 commit trace 的一般測試
`-- irq/       # 由專用 pattern 驅動 MEIP 的 interrupt 測試
```

測試程式本身放在這裡；testbench、pattern、checker 與 coverage 放在
`verification/`。

### 常用檔案

`non_irq/` 內的大部分 case 包含：

- `smoke.S`、其他 `.S` 或 `.c`：測試程式原始碼。
- `*.dump`：反組譯結果，方便核對指令與位址。
- `dram.dat`：pseudo DRAM 載入的 memory image。
- `goldenPC_inst.txt`：預期的 retirement trace，包含 PC、instruction、rd、
  write enable、write data 與 commit type。
- `goldenReg.txt`：程式結束時預期的 GPR 狀態。
- `goldenCsr.txt`：程式結束時預期的 CSR 狀態。

IRQ case 不使用固定的 commit trace，而是使用 `goldenReg.txt`、
`goldenCsr.txt`、`goldenIRQ.txt` 與 `irq_args.txt`。MEIP 會經過兩級同步器，
cache 與 DRAM latency 也會影響 pipeline occupancy，因此 interrupt 的精確
trap boundary 允許在指定範圍內變動。這三支測試主要檢查合法的 interrupt
boundary、trap/MRET 次數以及最後的 architectural state。

IRQ case 同樣包含原始碼、`.dump` 與 `dram.dat`，另有 `.elf`、`.map` 可用來
查詢符號位址。

### 測試檔案的來源

`dram.dat` 是由各 case 的 `.S` 或 `.c` 編譯後轉換出來的 memory image。
golden 檔案則依測試而異：部分依照測試預期的 architectural 行為建立，
部分（例如 `random_c_stress`）參考 Spike 的 instruction trace 產生。
產生這些檔案的 toolchain 與轉換腳本不包含在這個 repository 中，
repository 提供的是已經產生好、可直接執行的檔案。

### 基本 RV32I 測試

| Case | 測試內容 |
| --- | --- |
| [`branch_not_taken`](non_irq/branch_not_taken/) | `BNE` 不成立時沿 sequential path 執行。 |
| [`branch_taken`](non_irq/branch_taken/) | `BNE` 成立後 redirect，並清除 wrong-path instruction。 |
| [`basic_load_store`](non_irq/basic_load_store/) | 基本 word store 與 load。 |
| [`store_load_back_to_back`](non_irq/store_load_back_to_back/) | Store 後緊接著 load，確認能讀回正確資料。 |
| [`load_use_alu`](non_irq/load_use_alu/) | Load 結果立刻被 ALU instruction 使用時的 load-use hazard。 |
| [`jal_link_register`](non_irq/jal_link_register/) | `JAL` redirect 與寫入 `rd` 的 link address。 |
| [`load_store_widths`](non_irq/load_store_widths/) | Byte、halfword、word access，以及 signed/unsigned load。 |
| [`partial_store_preserve`](non_irq/partial_store_preserve/) | Byte/halfword store 不會破壞同一個 word 中未被寫入的 byte。 |
| [`branch_conditions`](non_irq/branch_conditions/) | Signed/unsigned branch 的 taken 與 not-taken 組合。 |
| [`jalr_target`](non_irq/jalr_target/) | `JALR` target、redirect 與 link address。 |
| [`integer_alu_ops`](non_irq/integer_alu_ops/) | Integer arithmetic、logic、shift、compare、`LUI` 與 `AUIPC`。 |
| [`pipeline_hazards`](non_irq/pipeline_hazards/) | Load 對 ALU、branch、`JALR`、store address/data 的 dependency，以及 wrong-path suppression。 |
| [`back_to_back_memory`](non_irq/back_to_back_memory/) | Back-to-back memory access、forwarding、寫入 `x0` 與 `JALR` sequence。 |
| [`branch_flush_memory_ops`](non_irq/branch_flush_memory_ops/) | Branch redirect 清除較年輕的 memory operation，同時保留較老指令的 effect。 |

### CSR 與 exception 測試

| Case | 測試內容 |
| --- | --- |
| [`csr_six_ops`](non_irq/csr_six_ops/) | 六種 Zicsr 指令：`CSRRW`、`CSRRS`、`CSRRC`、`CSRRWI`、`CSRRSI`、`CSRRCI`。 |
| [`csr_raw_hazard`](non_irq/csr_raw_hazard/) | 較年輕 CSR read 等待同一個 CSR 的較老 write。 |
| [`csr_to_gpr_forwarding`](non_irq/csr_to_gpr_forwarding/) | CSR 指令讀出的舊值（即將寫入 `rd`）在尚未寫回 GPR 之前，就從 EX/MEM 與 MEM/WB forward 給後續指令的 rs1、rs2 與 store data 使用（這是一般 GPR forwarding，與 CSR 本身的 RAW stall 不同）。 |
| [`unsupported_csr_illegal`](non_irq/unsupported_csr_illegal/) | 不支援的 CSR address 產生 illegal-instruction exception，且不誤改 GPR/CSR。 |
| [`ecall_mret`](non_irq/ecall_mret/) | Machine-mode `ECALL`、trap entry、handler 與 `MRET`。 |
| [`ebreak_mret`](non_irq/ebreak_mret/) | `EBREAK`、trap entry、handler 與 `MRET`。 |
| [`illegal_instruction`](non_irq/illegal_instruction/) | 不支援的 instruction encoding 產生 illegal-instruction exception。 |
| [`instruction_address_misaligned`](non_irq/instruction_address_misaligned/) | Branch、`JAL`、`JALR` 的 misaligned target 與對應 exception metadata。 |
| [`load_store_misaligned`](non_irq/load_store_misaligned/) | Misaligned load/store trap，且不得誤改 destination register 或 memory。 |
| [`fetch_access_fault`](non_irq/fetch_access_fault/) | Fetch 超出支援的 memory range 時產生 instruction access fault。 |
| [`load_store_access_fault`](non_irq/load_store_access_fault/) | Load/store 超出支援範圍時產生 access fault，且沒有額外 side effect。 |
| [`exception_age_priority`](non_irq/exception_age_priority/) | Exception 同時出現時保留最老的 surviving instruction，抑制較年輕 exception 與 side effect。 |
| [`redirect_kills_fetch_fault`](non_irq/redirect_kills_fetch_fault/) | 較老 branch/jump redirect 丟棄 wrong path 上較年輕的 fetch fault。 |

### Memory 與 system 測試

| Case | 測試內容 |
| --- | --- |
| [`fence_nop`](non_irq/fence_nop/) | `FENCE` 依本 core 的約定視為 NOP，不產生 illegal trap 或額外 memory request。 |
| [`dirty_eviction_cdc`](non_irq/dirty_eviction_cdc/) | Dirty cache-line eviction、AXI writeback、refill，以及通過 AXI CDC bridge 的完整路徑。 |
| [`random_c_stress`](non_irq/random_c_stress/) | 較廣泛的 C workload，涵蓋 integer operation、branch、loop 與 load/store；執行時間會隨 DRAM latency（由 seed 決定）而變動。 |

### Interrupt 測試

| Case | 測試內容與環境需求 |
| --- | --- |
| [`irq_single_sync`](irq/irq_single_sync/) | 一次 level-sensitive external interrupt 經過同步器後被接受，接著完成一次 trap 與一次 `MRET`。 |
| [`irq_during_real_dcache_miss`](irq/irq_during_real_dcache_miss/) | 在真實 D-cache refill 的 AXI AR handshake 發生後拉高 MEIP，確認較老的 load 先退休，再進入 interrupt trap。這支測試需要真實的 D-cache、AXI interconnect 與 DRAM model。 |
| [`irq_level_retrigger`](irq/irq_level_retrigger/) | 第一次 `MRET` 後 MEIP 仍保持為高，因此必須再次進入 interrupt；第二次 trap 時才將來源拉低。 |

### 測試範圍

這些 case 用來驗證 architectural behavior 與關鍵的跨模組 corner case，並搭配 SVA 與 functional coverage 使用。
它們不是完整的 formal proof，也不等同於完整的 RISC-V compliance suite。

---

## English

This directory contains the programs, DRAM images, and expected results used by
the system-level CPU tests. It currently contains 30 non-interrupt cases and 3
interrupt cases.

### Directory layout

```text
tests/
|-- non_irq/   # Tests that use a fixed commit trace
`-- irq/       # Tests that drive MEIP with a dedicated pattern
```

The test programs are stored here. The testbench, patterns, checkers, and
coverage code are kept under `verification/`.

### Common files

Most cases under `non_irq/` contain:

- `smoke.S`, another `.S` file, or a `.c` file: test source.
- `*.dump`: disassembly used to check instructions and addresses.
- `dram.dat`: memory image loaded by the pseudo DRAM.
- `goldenPC_inst.txt`: expected retirement trace, including PC, instruction,
  destination register, write enable, write data, and commit type.
- `goldenReg.txt`: expected final GPR state.
- `goldenCsr.txt`: expected final CSR state.

The IRQ cases use `goldenReg.txt`, `goldenCsr.txt`, `goldenIRQ.txt`, and
`irq_args.txt` instead of a fixed commit trace. MEIP passes through a two-flop
synchronizer, and cache/DRAM latency changes pipeline occupancy, so the exact
interrupt boundary may move within a legal range. These cases check legal
boundaries, trap/MRET counts, and the final architectural state.

Each IRQ case also contains its source, `.dump` and `dram.dat`, plus `.elf` and
`.map` files for looking up symbol addresses.

### Where the files come from

`dram.dat` is the memory image converted from the `.S` or `.c` source of
each case after compilation. The golden files depend on the test: some are
built from the expected architectural behavior, and some (for example
`random_c_stress`) are generated with reference to a Spike instruction trace.
The toolchain and conversion scripts that produce these files are not part of
this repository; it provides the generated files, which can be run directly.

### Basic RV32I cases

| Case | What it checks |
| --- | --- |
| [`branch_not_taken`](non_irq/branch_not_taken/) | A not-taken `BNE` follows the sequential path. |
| [`branch_taken`](non_irq/branch_taken/) | A taken `BNE` redirects fetch and kills the wrong-path instruction. |
| [`basic_load_store`](non_irq/basic_load_store/) | Basic word store and load behavior. |
| [`store_load_back_to_back`](non_irq/store_load_back_to_back/) | A load immediately following a store observes the stored value. |
| [`load_use_alu`](non_irq/load_use_alu/) | Load-use handling when an ALU instruction immediately consumes loaded data. |
| [`jal_link_register`](non_irq/jal_link_register/) | `JAL` redirect behavior and the link value written to `rd`. |
| [`load_store_widths`](non_irq/load_store_widths/) | Byte, halfword, and word accesses, including signed and unsigned loads. |
| [`partial_store_preserve`](non_irq/partial_store_preserve/) | Byte and halfword stores preserve the untouched bytes of an existing word. |
| [`branch_conditions`](non_irq/branch_conditions/) | Signed and unsigned branch variants in taken and not-taken cases. |
| [`jalr_target`](non_irq/jalr_target/) | `JALR` target calculation, redirect, and link value. |
| [`integer_alu_ops`](non_irq/integer_alu_ops/) | Integer arithmetic, logic, shifts, comparisons, `LUI`, and `AUIPC`. |
| [`pipeline_hazards`](non_irq/pipeline_hazards/) | Load dependencies involving ALU, branch, `JALR`, and store operands, plus wrong-path suppression. |
| [`back_to_back_memory`](non_irq/back_to_back_memory/) | Back-to-back memory operations, forwarding, writes to `x0`, and a `JALR` sequence. |
| [`branch_flush_memory_ops`](non_irq/branch_flush_memory_ops/) | A branch redirect flushes younger memory operations without losing older effects. |

### CSR and exception cases

| Case | What it checks |
| --- | --- |
| [`csr_six_ops`](non_irq/csr_six_ops/) | All six Zicsr forms: `CSRRW`, `CSRRS`, `CSRRC`, `CSRRWI`, `CSRRSI`, and `CSRRCI`. |
| [`csr_raw_hazard`](non_irq/csr_raw_hazard/) | A CSR read waits for an older write to the same CSR. |
| [`csr_to_gpr_forwarding`](non_irq/csr_to_gpr_forwarding/) | The old CSR value destined for `rd` is forwarded from EX/MEM and MEM/WB to later rs1, rs2, and store-data consumers before it is written back to the GPR (ordinary GPR forwarding, as opposed to the CSR RAW stall). |
| [`unsupported_csr_illegal`](non_irq/unsupported_csr_illegal/) | An unsupported CSR address raises an illegal-instruction exception without an unintended GPR or CSR update. |
| [`ecall_mret`](non_irq/ecall_mret/) | Machine-mode `ECALL`, trap entry, handler execution, and return through `MRET`. |
| [`ebreak_mret`](non_irq/ebreak_mret/) | `EBREAK`, trap entry, handler execution, and return through `MRET`. |
| [`illegal_instruction`](non_irq/illegal_instruction/) | An unsupported instruction encoding raises an illegal-instruction exception. |
| [`instruction_address_misaligned`](non_irq/instruction_address_misaligned/) | Misaligned branch, `JAL`, and `JALR` targets report the correct exception metadata. |
| [`load_store_misaligned`](non_irq/load_store_misaligned/) | Misaligned loads and stores trap without changing the destination register or memory. |
| [`fetch_access_fault`](non_irq/fetch_access_fault/) | A fetch outside the supported memory range produces an instruction access fault. |
| [`load_store_access_fault`](non_irq/load_store_access_fault/) | Out-of-range loads and stores produce access faults without unintended architectural side effects. |
| [`exception_age_priority`](non_irq/exception_age_priority/) | When exceptions overlap, the oldest surviving instruction wins and younger exceptions or side effects are suppressed. |
| [`redirect_kills_fetch_fault`](non_irq/redirect_kills_fetch_fault/) | An older branch or jump redirect discards a younger fetch fault on the wrong path. |

### Memory and system cases

| Case | What it checks |
| --- | --- |
| [`fence_nop`](non_irq/fence_nop/) | `FENCE` follows this core's no-op contract and retires without an illegal trap or extra memory request. |
| [`dirty_eviction_cdc`](non_irq/dirty_eviction_cdc/) | Dirty cache-line eviction, AXI writeback, refill, and traversal through the AXI CDC bridge. |
| [`random_c_stress`](non_irq/random_c_stress/) | A broader C workload covering integer operations, branches, loops, loads and stores, with DRAM latency that varies with the seed. |

### Interrupt cases

| Case | What it checks and requires |
| --- | --- |
| [`irq_single_sync`](irq/irq_single_sync/) | One synchronized level-sensitive external interrupt, one trap, and one `MRET`. |
| [`irq_during_real_dcache_miss`](irq/irq_during_real_dcache_miss/) | MEIP is asserted after a real D-cache refill AR handshake. The older load must retire before the interrupt trap. This case requires the real D-cache, AXI interconnect, and DRAM model. |
| [`irq_level_retrigger`](irq/irq_level_retrigger/) | MEIP remains high across the first `MRET`, causing a second interrupt before the source is lowered. |

### Scope

These directed tests cover architectural behavior and important cross-module
corner cases. They complement the assertions and functional coverage. They are not an
exhaustive formal proof or a complete RISC-V compliance suite.
