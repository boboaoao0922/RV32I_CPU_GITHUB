# Verification

這個專案的 system-level 驗證以自動檢查的 simulation 為主。Testbench 會把 CPU、兩顆 cache、AXI Arbiter、AXI CDC Bridge 與 pseudo DRAM 接在一起。每個 test case 都有一份 `dram.dat`，simulation 開始時由 pseudo DRAM 讀入，作為 instruction 和 data 的初始 memory image。測試通過與否由 commit trace、最後的 GPR（general-purpose register）/ CSR（control and status register）狀態、SVA 和 IRQ pattern 共同判斷，不需要只靠波形人工確認。

## Testbench Environment

`TESTBED_RV32I_SYSTEM_TOP.sv` 使用兩個不同的 clock：CPU 端週期為 1.0 ns，memory 端週期為 1.4 ns；memory clock 在 simulation 開始後延遲 0.2 ns 啟動，兩個 clock 的週期不是整數倍，又有 0.2 ns 的初始相位差，因此相位關係會不斷變化，讓 AXI CDC Bridge 在一般 regression 中就會遇到非同步 clock。這些數值只用於 functional simulation，不代表合成後的 timing 結果。

外部 memory 使用 `pseudo_DRAM.sv`。它支援 AXI burst 與 outstanding transaction，並依照 seed 改變 response latency，用來讓 cache refill、dirty writeback 與 CDC FIFO 碰到不同的等待時間。相同 seed 可以重現同一組延遲行為。

Testbench 另外接出 CPU 的 commit interface：

| Signal | 用途 |
| --- | --- |
| `commit_fire` | 本 cycle 有 instruction 退休 |
| `commit_PC`、`commit_inst` | 退休 instruction 的 PC 與 encoding |
| `commit_rd`、`commit_we`、`commit_wb_data` | GPR 寫回資訊 |
| `commit_type` | 一般退休、trap 等 commit 類型 |

一般測試的 pattern 只在 `commit_fire=1` 時比較這些欄位，因此 pipeline stall、cache miss 或 clock 比例改變只會影響執行時間，不會改變預期的 architectural result。

## Non-IRQ Tests

一般測試使用 `PATTERN_CPU.sv`。每次 instruction 退休時，pattern 會依序讀取 `goldenPC_inst.txt`，比較 PC、instruction、register write enable、destination register、write data 與 commit type。任何欄位不同都會立即結束 simulation 並顯示錯誤內容。

測試程式最後會跳到固定的 pass address（`0x0000ff00`）。當該位置的 instruction 退休時，pattern 還會使用 `goldenReg.txt` 與 `goldenCsr.txt` 檢查最後的狀態：GPR（`x0` 除外）逐一比對，CSR 則比對 `mepc`、`mtvec`、`mstatus.MPIE`、`mstatus.MIE`、`mie.MEIE` 與 `mip.MEIP`。若退休的是 fail address（`0x0000fe00`）或連續 2000 cycles 沒有 instruction 退休，則判定失敗。這可以同時抓到錯誤結果、少退休一條 instruction、多退休一條 instruction，以及 pipeline 卡住等問題。

Golden 的來源依測試而異：部分是依照測試預期的 architectural 行為建立，部分（例如 `random_c_stress`）則參考 Spike 的 instruction trace 產生。

## IRQ Tests

IRQ 使用獨立的 `PATTERN_CPU_IRQ.sv`。MEIP 會先經過 top level 的 2-FF synchronizer，interrupt 又必須等待較老 instruction 排空。MEIP 完成同步時，pipeline 中的 instruction 可能正好遇到 cache hit、cache miss 或等待 pseudo DRAM response；這些等待時間會改變當下的 pipeline 狀態。因此即使執行同一支 IRQ 測試，不同 seed 或 memory response timing 下，interrupt trap 對應的 `mepc` 也可能落在不同但合法的 instruction boundary。這類測試不使用固定的完整 commit trace。

每個 IRQ case 會用 `irq_args.txt` 指定 case 編號，以及該 case 允許的 wait loop PC 或 `mepc` 範圍，再由 `goldenIRQ.txt` 設定預期的 trap 次數、`MRET` 次數、`mcause` 與 `mtval`。Pattern 同時檢查：

- `mepc` 位於該 case 允許的 instruction boundary。
- MEIP 持續為高時，第一次 `MRET` 後必須再次接受 interrupt。
- 最後的 GPR 與 CSR 狀態符合 `goldenReg.txt` 和 `goldenCsr.txt`。

因此 pattern 不要求每次都在同一個 cycle 進入 trap，但仍會限制 architectural behavior 與 precise interrupt 規則。

## SystemVerilog Assertions

`CPU_checker.sv` 在每個 system test 中一起執行。Assertions 主要檢查下列行為：

- Pipeline register 在 `HOLD` 時保持內容，在 `ADVANCE` 時接收前級 payload，在 `BUBBLE` 後清除 `reg_valid`。
- Memory hold 期間 pipeline 不會前進，也不會多產生 commit、trap 或 `MRET`。
- Redirect、trap、`MRET` 與 IRQ drain 期間不會錯誤接受新的 instruction。
- 同一時間若有多個 exception，只有較老 instruction 的 exception 可以存活；MEM stage fault 會取消較年輕的 branch / jump redirect、阻止較年輕的 load / store handshake，並禁止其寫入 GPR 或 CSR。
- Misaligned access 與 access fault 不會產生不該出現的 cache handshake 或 GPR / CSR 寫入。
- I-cache access fault 回來但 pipeline 暫時無法接收時，FetchUnit 會先保留 fault，等到可以接收時再送進 pipeline；若先遇到較老的 redirect、trap 或 `MRET`，則會將它丟棄。
- IRQ drain 遇到同步 exception 時會停止，interrupt trap 只會在 pipeline 排空後發生。
- Exception 或 interrupt trap 發生後，會在下一拍檢查 `mepc`、`mcause`、`mtval` 及 `mstatus.MIE/MPIE` 的更新；`MRET` 則檢查 `mstatus.MIE/MPIE` 是否正確恢復。

這些 assertion 主要用來檢查逐 cycle 控制；commit trace 則負責檢查完整程式執行後的 architectural result。兩者抓到的問題不同，因此 regression 中會同時啟用。

## Functional Coverage

`CPU_coverage.sv` 記錄目前測試實際碰到的功能與時序組合，包括：

- RV32I 與 Zicsr instruction 的 commit 種類與 branch taken 結果。
- Load、store 與不同 memory access size。
- FetchUnit 和四組 pipeline register 的狀態與 state transition。
- Exception cause、IRQ 接受、MEIP transition 與各類 stall。
- MEM fault 清除較年輕事件、IRQ drain 與 exception / redirect / `MRET` 的碰撞。
- Fetch fault 在 global hold、data hazard、IRQ drain 中的保留，以及被 redirect、trap 或 `MRET` 丟棄的情況。

Simulation 結束時會印出各 covergroup 與 overall coverage。VCS 也會把不同 case 的 code coverage、assertion coverage 與 functional coverage 存入共用的 coverage database。Coverage 用來找尚未出現的情境，不單獨作為測試通過的判定條件。

## Performance Monitor

`CPU_perf_monitor.sv` 不參與 pass / fail 判定，只負責統計執行特性。輸出包含 cycle、commit、CPI、IPC、I-cache / D-cache request 與 miss、refill beat、stall cycle、dirty writeback 與 shared AXI transaction 數量。

## Regression Flow

公開 repository 將測試分成 non-IRQ 與 IRQ 兩組。兩支 script 都會先 compile 一次，再讓選定的 case 共用同一個 `simv`：

```bash
./scripts/run_non_irq_vcs.sh branch_taken load_use_alu
./scripts/run_irq_vcs.sh irq_single_sync
```

不帶 case name 時會執行該分類的完整 regression。每次執行會建立 timestamped result directory，保存各 case 的 log 並產生 `summary.txt`，列出通過與失敗的 case。單支測試預設保留 FSDB；多支 regression 預設只保留失敗 case 的波形。

目前公開測試共有 30 支 non-IRQ case 與 3 支 IRQ case，涵蓋基本 RV32I、Zicsr、pipeline hazard、exception、access fault、interrupt、cache dirty eviction 與 CDC 整合。各 case 的目的與 golden file 格式列在[`tests/README.md`](../tests/README.md)，執行參數則列在[`scripts/README.md`](../scripts/README.md)。

這套測試著重目前實作的 architectural behavior 與跨模組 corner case，並不等同完整的 RISC-V compliance suite 或 formal proof。Regression 狀態以實際執行後產生的 `summary.txt` 為準。
