#!/usr/bin/env bash
set -e

if [ ! -f "./config.env" ]; then
    echo "ERROR: config.env not found" >&2
    exit 1
fi

source ./config.env

if [ "${LINT_ENABLED:-1}" != "1" ]; then
    echo "Lint disabled by config.env, skipping"
    exit 0
fi

if [ -n "${LINT_CMD:-}" ]; then
    echo "Running custom lint command"
    bash -lc "$LINT_CMD"
    exit 0
fi

if ! command -v verible-verilog-lint >/dev/null 2>&1; then
    echo "ERROR: verible-verilog-lint not found" >&2
    exit 1
fi

echo "Running Verible lint"

# Start with AFT-owned RTL only. Avoid RISCVBusiness, third-party IP,
# generated build dirs, UVM verification, and copied submodule code.
LINT_DIRS=(
    "DMA"
    "digital_io_mux"
    "gpio"
    "interrupt_controller"
    "pwm"
    "sram_controller"
    "timer"
    "top_level"
    "fpga"
)

: > verible_filelist.txt

for dir in "${LINT_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        find "$dir" -type f \
            \( -name "*.sv" -o -name "*.svh" -o -name "*.v" -o -name "*.vh" \) \
            >> verible_filelist.txt
    fi
done

# Optional: include top-level standalone RTL files if they exist.
find . -maxdepth 1 -type f \
    \( -name "*.sv" -o -name "*.svh" -o -name "*.v" -o -name "*.vh" \) \
    >> verible_filelist.txt

sort -u verible_filelist.txt -o verible_filelist.txt

if [ ! -s verible_filelist.txt ]; then
    echo "No Verilog/SystemVerilog files found"
    exit 0
fi

echo "Linting $(wc -l < verible_filelist.txt) files"

if [ -f ".rules.verible_lint" ]; then
    verible-verilog-lint --rules_config=.rules.verible_lint $(cat verible_filelist.txt)
else
    verible-verilog-lint $(cat verible_filelist.txt)
fi