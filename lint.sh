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

find . \
    \( -path "./aft_out" \
    -o -path "./aft_out_xcelium" \
    -o -path "./fusesoc_libraries" \
    -o -path "./.git" \
    -o -path "./.venv" \) -prune \
    -o \( -name "*.sv" -o -name "*.svh" -o -name "*.v" -o -name "*.vh" \) \
    -print > verible_filelist.txt

if [ ! -s verible_filelist.txt ]; then
    echo "No Verilog/SystemVerilog files found"
    exit 0
fi

verible-verilog-lint --rules_config=.rules.verible_lint $(cat verible_filelist.txt)