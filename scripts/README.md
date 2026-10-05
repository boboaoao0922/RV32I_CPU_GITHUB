# VCS Regression Scripts / VCS Regression 腳本

- [中文說明](#中文說明)
- [English](#english)

## 中文說明

這個目錄包含 VCS 的 filelist 與兩支 regression script：

- `run_non_irq_vcs.sh`：執行 `tests/non_irq/` 的一般測試。
- `run_irq_vcs.sh`：執行 `tests/irq/` 的 interrupt 測試。

### 使用方式

請在 repository 根目錄執行：

```bash
chmod +x scripts/run_non_irq_vcs.sh scripts/run_irq_vcs.sh

./scripts/run_non_irq_vcs.sh list
./scripts/run_non_irq_vcs.sh branch_taken
./scripts/run_non_irq_vcs.sh branch_taken load_use_alu
./scripts/run_non_irq_vcs.sh

./scripts/run_irq_vcs.sh list
./scripts/run_irq_vcs.sh irq_single_sync
./scripts/run_irq_vcs.sh
```

| 指令 | 說明 |
| --- | --- |
| `list` | 只列出該分類所有可用的 case 名稱，然後結束；不會 compile，也不會執行任何測試。想單跑某支測試但忘記名稱時可以先用它查詢。 |
| `CASE [CASE ...]` | 執行指定的一個或多個 case。`CASE` 是 case 名稱，可一次指定多個並以空格隔開（不需要輸入中括號），例如 `branch_taken load_use_alu`。輸入不存在的名稱時，script 會報錯並提示使用 `list`。 |
| `all` 或不帶參數 | 執行該分類的所有 case。 |
| `-h`、`--help` | 顯示用法與可用的環境變數。 |

每次執行只會 compile 一次，所選的 case 共用同一個 `simv`。

### 環境變數

| 變數 | 預設值 | 說明 |
| --- | --- | --- |
| `SEED` | `1` | VCS 與 DRAM model 的 random seed。 |
| `DUMP_FSDB` | `1` | 是否輸出 FSDB 波形（`0` 為關閉）。 |
| `KEEP_FSDB` | `auto` | `auto` 表示單支測試保留波形、多支 regression 只保留失敗 case 的波形；`1` 保留全部；`0` 只保留失敗 case。 |

### 輸出

結果會寫在 `out/vcs/results/non_irq/` 或 `out/vcs/results/irq/` 底下，每次執行建立一個以時間命名的資料夾，內含各 case 的 log 和 `summary.txt`。`summary.txt` 會列出 seed、case 總數、通過與失敗的數量與名稱。

CPU 的 SVA 與 functional coverage 在兩個流程中都會啟用。

---

## English

This directory contains the VCS filelists and two regression scripts:

- `run_non_irq_vcs.sh`: runs the regular tests under `tests/non_irq/`.
- `run_irq_vcs.sh`: runs the interrupt tests under `tests/irq/`.

### Usage

Run the commands from the repository root:

```bash
chmod +x scripts/run_non_irq_vcs.sh scripts/run_irq_vcs.sh

./scripts/run_non_irq_vcs.sh list
./scripts/run_non_irq_vcs.sh branch_taken
./scripts/run_non_irq_vcs.sh branch_taken load_use_alu
./scripts/run_non_irq_vcs.sh

./scripts/run_irq_vcs.sh list
./scripts/run_irq_vcs.sh irq_single_sync
./scripts/run_irq_vcs.sh
```

| Command | Description |
| --- | --- |
| `list` | Prints the names of all available cases in that category and exits. It does not compile or run any test. Use it to look up a case name before running a single test. |
| `CASE [CASE ...]` | Runs the selected case or cases. `CASE` is a case name; give several separated by spaces (do not type the brackets), e.g. `branch_taken load_use_alu`. An unknown name makes the script fail and suggests using `list`. |
| `all` or no argument | Runs every case in the category. |
| `-h`, `--help` | Prints usage and the supported environment variables. |

Compilation is performed once per invocation, and all selected cases reuse the
same `simv`.

### Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `SEED` | `1` | Random seed for VCS and the DRAM model. |
| `DUMP_FSDB` | `1` | Enable FSDB dumping (`0` disables it). |
| `KEEP_FSDB` | `auto` | `auto` keeps the waveform of a single-case run and only failed-case waveforms in a multi-case regression; `1` keeps all; `0` keeps only failed cases. |

### Output

Results are written under `out/vcs/results/non_irq/` or
`out/vcs/results/irq/`. Each run creates a timestamped directory that contains
the log of every case and a `summary.txt`. The summary lists the seed, the
total number of cases, and the names and counts of passed and failed cases.

The CPU SVA and functional coverage are enabled in both flows.
