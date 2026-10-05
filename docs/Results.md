# Results

這份文件整理目前 `RV32I_SYSTEM_TOP` 的 synthesis、gate-level simulation 和 PrimeTime PX 結果。數字是一次完成的 flow report，不代表 APR 或 sign-off 結果。

## Synthesis

Synthesis 使用 Synopsys Design Compiler，製程為 TSMC 16 nm，在 `ssgnp0p9v125c` corner（0.9 V、125 °C）下執行。CPU 與 memory clock 的 SDC constraint 都是 1 ns。SRAM 以製程 macro library/black box 方式加入，沒有把 simulation behavior model 拿去合成。

| 項目 | 結果 |
| --- | ---: |
| Macro/black-box area | 47,973.00 µm² |
| Total cell area | 57,236.09 µm² |
| Clock-gated registers | 93.74%（4,284 / 4,570） |
| Max-path slack（report） | ≥ 0 ns (MET) |
| Min/hold slack（report） | -0.20 ns (VIOLATED) |

`Total cell area` 包含 macro area；因為這次使用 zero-wire-load，report 沒有提供實際 net interconnect area。合成工具自動插入 clock gating，所有 register 中有 93.74%（4,284 / 4,570）被 gate 住，其餘 6.26%（286 個）未被 gate。Max-path 沒有 setup violation，只表示這份 synthesis report 的結果，不能當成完整 setup sign-off。

Min/hold report 仍有 -0.20 ns violation。Hold timing 通常會在 APR 與 clock tree 建立後，依照實際的 clock skew 和 routing delay 進行修正；本專案沒有進行 APR，因此保留這項結果，沒有繼續做 hold closure。

## Gate-level simulation

Gate-level simulation 的功能測試通過。目前實際使用的版本沒有做 SDF annotation；annotate SDF 的版本會 fail，因此這個結果只用來確認 gate netlist 的功能，不代表 timing closure。

Gate testbench 使用 1.0 ns CPU clock 和 1.4 ns memory clock，這是功能模擬的設定。

## PrimeTime PX

PTPX 讀入 synthesis netlist、SDC 和 gate VCD。這是 pre-layout activity-based estimate；沒有 APR、CTS 或 extracted parasitics。

這裡的 VCD 來自沒有 SDF annotation 的 gate-level simulation（見上一節），等同 zero-delay 的 switching activity：toggle 次數是功能正確的，但不包含 glitch。PTPX report 的 `Glitching Power` 也是 0。因此 dynamic power 可能略為偏低；不過這份 design 的功耗主要來自 SRAM macro 和 clock network，combinational 的比例很小（見下方各功耗分組的比較），所以影響有限。

下表比較同一份 RTL 在合成時有無啟用 clock gating 的功耗差異：

- **Clock gating**：合成時加上 clock gating 指令，由工具自動插入 clock gating（見 Synthesis 一節）。
- **No clock gating**：合成時不加該指令，其他設定（RTL、testbench workload、VCD 取樣方式）完全相同。

| Run | Total power (W) | Peak power (W) |
| --- | ---: | ---: |
| Clock gating | 0.0205 | 4.3283 |
| No clock gating | 0.0340 | 5.0695 |

Total power 是整段 VCD 的平均功耗，單位為 W（例如 0.0205 W = 20.5 mW）；PTPX report 沒有標示 unit，這裡依照 library 預設單位解讀。Peak power 是 PTPX 在 0.001 ns 取樣間隔下的瞬間峰值，不是平均功耗，因此會遠大於 Total power，不代表實際功耗表現。

下表把 Total power 依 PTPX 的功耗分組（power group）拆開，單位為 mW。其中 `memory` 是 SRAM macro。

| 功耗分組 | Clock gating | No clock gating |
| --- | ---: | ---: |
| clock_network | 3.67 | 17.1 |
| memory（SRAM macro） | 16.5 | 16.5 |
| register | 0.19 | 0.20 |
| combinational | 0.12 | 0.15 |
| **Total** | **20.5** | **34.0** |

SRAM macro 的功耗在兩種設定下相同，兩者的差距幾乎全部來自 clock network：clock gating 讓 clock network 的功耗從 17.1 mW 降到 3.67 mW。register 與 combinational 合計不到 0.4 mW，因此上面提到的 glitch power 對整體結果的影響有限。

## Limitations

- 目前沒有 APR、CTS、extracted parasitics，因此不能宣稱 timing 或 power sign-off。
- synthesis min/hold report 仍有 -0.20 ns violation；本專案沒有進行 APR，因此未做 post-layout hold closure。目前 gate simulation 也沒有做 SDF annotation，不能用來判斷 hold timing。
- synthesis SDC 對 CPU 與 memory clock 都使用 1 ns constraint，gate simulation 的 memory clock 則是 1.4 ns。兩者設定不同，而且 gate simulation 沒有 annotate SDF，因此不能直接拿來做 timing closure 比較。
- PTPX 使用的 VCD 沒有 SDF delay，不含 glitch power；功耗數字為 pre-layout 估計，不含 clock tree 與 routing parasitics。
- 因為沒有 CTS，PTPX 的 `clock_network` 只包含 ideal clock 與 register clock pin 的功耗，不含實際 clock tree buffer。有無 clock gating 的功耗差異（17.1 mW 對 3.67 mW）是 pre-layout 的比較，CTS 之後的絕對數字與差距可能不同。
- SRAM macro 的 area、leakage 和 dynamic power 取決於使用的 library model；公開 repository 不包含製程 `.db`/macro model。
