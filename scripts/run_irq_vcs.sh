#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CASE_ROOT="$REPO_ROOT/tests/irq"
OUT_ROOT=${OUT_ROOT:-"$REPO_ROOT/out/vcs"}
BUILD_DIR="$OUT_ROOT/build/irq"
RESULT_ROOT=${RESULT_ROOT:-"$OUT_ROOT/results/irq"}
SIMV="$BUILD_DIR/simv_irq"
COVERAGE_DB="$BUILD_DIR/coverage.vdb"

SEED=${SEED:-1}
VCS_JOBS=${VCS_JOBS:-8}
DUMP_FSDB=${DUMP_FSDB:-1}
KEEP_FSDB=${KEEP_FSDB:-auto}
VERDI_HOME=${VERDI_HOME:-/usr/cad/synopsys/verdi/2023.03-sp2}

usage() {
    cat <<'EOF'
Usage:
  ./scripts/run_irq_vcs.sh                 Run all IRQ cases
  ./scripts/run_irq_vcs.sh all             Run all IRQ cases
  ./scripts/run_irq_vcs.sh list            List available cases
  ./scripts/run_irq_vcs.sh CASE [CASE ...] Run selected cases

Environment:
  SEED=N             VCS and DRAM random seed (default: 1)
  VCS_JOBS=N         Parallel VCS compile jobs (default: 8)
  DUMP_FSDB=0|1      Enable FSDB dumping (default: 1)
  KEEP_FSDB=auto|0|1 auto keeps a single-case or failed-case FSDB (default)
  OUT_ROOT=path      Build and result root (default: out/vcs)
  RESULT_ROOT=path   Override only the result root
  VERDI_HOME=path    Verdi installation used by the FSDB dumper
EOF
}

mapfile -t ALL_CASES < <(
    find "$CASE_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort
)

if [[ $# -eq 1 && ( ${1:-} == -h || ${1:-} == --help ) ]]; then
    usage
    exit 0
fi

if [[ $# -eq 1 && ${1:-} == list ]]; then
    printf '%s\n' "${ALL_CASES[@]}"
    exit 0
fi

declare -a CASES=()
if [[ $# -eq 0 || ( $# -eq 1 && ${1:-} == all ) ]]; then
    CASES=("${ALL_CASES[@]}")
else
    CASES=("$@")
fi

for case_name in "${CASES[@]}"; do
    if [[ ! $case_name =~ ^[A-Za-z0-9_]+$ || ! -d "$CASE_ROOT/$case_name" ]]; then
        echo "Unknown IRQ case: $case_name" >&2
        echo "Use '$0 list' to show valid case names." >&2
        exit 2
    fi
    for file in dram.dat goldenReg.txt goldenCsr.txt goldenIRQ.txt irq_args.txt; do
        if [[ ! -f "$CASE_ROOT/$case_name/$file" ]]; then
            echo "Case $case_name is missing $file" >&2
            exit 2
        fi
    done
done

if ! command -v vcs >/dev/null 2>&1; then
    echo "Missing tool on PATH: vcs" >&2
    exit 2
fi

if [[ $DUMP_FSDB != 0 && $DUMP_FSDB != 1 ]]; then
    echo "DUMP_FSDB must be 0 or 1" >&2
    exit 2
fi
if [[ $KEEP_FSDB != auto && $KEEP_FSDB != 0 && $KEEP_FSDB != 1 ]]; then
    echo "KEEP_FSDB must be auto, 0, or 1" >&2
    exit 2
fi

mkdir -p "$BUILD_DIR" "$RESULT_ROOT"

declare -a VCS_ARGS=(
    -full64 -sverilog -timescale=1ns/1ps -Mupdate "-j${VCS_JOBS}"
    -debug_access+all -kdb
    -file "$SCRIPT_DIR/filelist_irq.f"
    -top TESTBENCH
    -o "$SIMV"
    -l "$BUILD_DIR/compile.log"
    "-Mdir=$BUILD_DIR/csrc"
    +define+RTL +define+FUNC +define+ENABLE_SVA_COVERAGE
    +notimingchecks
    -cm line+cond+fsm+tgl+branch+assert
    -cm_dir "$COVERAGE_DB"
)

if [[ $DUMP_FSDB == 1 ]]; then
    PLI_DIR="$VERDI_HOME/share/PLI/VCS/linux64"
    if [[ ! -f "$PLI_DIR/novas.tab" ]]; then
        PLI_DIR="$VERDI_HOME/share/PLI/VCS/LINUX64"
    fi
    if [[ ! -f "$PLI_DIR/novas.tab" || ! -f "$PLI_DIR/pli.a" ]]; then
        echo "Cannot find Verdi FSDB PLI under $VERDI_HOME" >&2
        echo "Set VERDI_HOME correctly or run with DUMP_FSDB=0." >&2
        exit 2
    fi
    VCS_ARGS+=(+define+FSDB -P "$PLI_DIR/novas.tab" "$PLI_DIR/pli.a")
fi

echo "[BUILD] IRQ simv"
set +e
(
    cd "$REPO_ROOT"
    vcs "${VCS_ARGS[@]}"
)
build_status=$?
set -e
if [[ $build_status -ne 0 ]]; then
    echo "[BUILD-FAIL] See $BUILD_DIR/compile.log" >&2
    exit "$build_status"
fi

STAMP=$(date +%Y%m%d_%H%M%S)
RUN_ROOT="$RESULT_ROOT/$STAMP"
mkdir -p "$RUN_ROOT"

declare -a PASS_CASES=()
declare -a FAIL_CASES=()

for case_name in "${CASES[@]}"; do
    case_dir="$CASE_ROOT/$case_name"
    run_dir="$RUN_ROOT/$case_name"
    mkdir -p "$run_dir"
    cp -f "$case_dir/dram.dat" "$run_dir/dram.dat"

    declare -a irq_args
    read -r -a irq_args <<< "$(tr '\r\n' '  ' < "$case_dir/irq_args.txt")"
    declare -a sim_args=(
        +ntb_random_seed="$SEED"
        +RAND_SEED="$SEED"
        +REG_GOLDEN="$case_dir/goldenReg.txt"
        +CSR_GOLDEN="$case_dir/goldenCsr.txt"
        +IRQ_GOLDEN="$case_dir/goldenIRQ.txt"
    )
    sim_args+=("${irq_args[@]}")
    sim_args+=(
        -cm_name "irq_${case_name}"
        -cm_dir "$COVERAGE_DB"
        -l "$run_dir/run.log"
    )

    echo
    echo "================================================================"
    echo "[IRQ] START $case_name seed=$SEED"
    echo "================================================================"

    set +e
    (
        cd "$run_dir"
        "$SIMV" "${sim_args[@]}"
    ) 2>&1 | tee "$run_dir/console.log"
    status=${PIPESTATUS[0]}
    set -e

    if [[ $status -eq 0 ]] && grep -q '^IRQ_REGRESSION_PASS' "$run_dir/run.log"; then
        PASS_CASES+=("$case_name")
        echo "[IRQ] PASS $case_name"
        passed=1
    else
        FAIL_CASES+=("$case_name (exit=$status)")
        echo "[IRQ] FAIL $case_name" >&2
        passed=0
    fi

    fsdb="$run_dir/RV32I_SYSTEM_TOP.fsdb"
    if [[ -f $fsdb ]]; then
        keep=0
        if [[ $passed -eq 0 || $KEEP_FSDB == 1 || ( $KEEP_FSDB == auto && ${#CASES[@]} -eq 1 ) ]]; then
            keep=1
        fi
        if [[ $keep -eq 0 ]]; then
            rm -f "$fsdb"
        fi
    fi
done

SUMMARY_FILE="$RUN_ROOT/summary.txt"
{
    echo "================ IRQ REGRESSION SUMMARY ================"
    echo "Seed    : $SEED"
    echo "Total   : ${#CASES[@]}"
    echo "PASS    : ${#PASS_CASES[@]}"
    echo "FAIL    : ${#FAIL_CASES[@]}"
    echo "Results : $RUN_ROOT"
    echo
    echo "[PASS CASES]"
    if [[ ${#PASS_CASES[@]} -eq 0 ]]; then echo "  (none)"; else printf '  %s\n' "${PASS_CASES[@]}"; fi
    echo
    echo "[FAIL CASES]"
    if [[ ${#FAIL_CASES[@]} -eq 0 ]]; then echo "  (none)"; else printf '  %s\n' "${FAIL_CASES[@]}"; fi
    echo "========================================================"
} | tee "$SUMMARY_FILE"

if [[ ${#FAIL_CASES[@]} -ne 0 ]]; then
    exit 1
fi

echo "IRQ_REGRESSION_ALL_PASS summary=$SUMMARY_FILE"
