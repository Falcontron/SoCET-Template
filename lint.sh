#!/usr/bin/env bash
set -euo pipefail

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

echo "Collecting RTL files for lint"

: > verilog_filelist.txt

if [ -d "rtl" ]; then
    find rtl -type f \
        \( -name "*.sv" -o -name "*.svh" -o -name "*.v" -o -name "*.vh" \) \
        >> verilog_filelist.txt
fi

sort -u verilog_filelist.txt -o verilog_filelist.txt

if [ ! -s verilog_filelist.txt ]; then
    echo "No Verilog/SystemVerilog files found"
    exit 0
fi

echo "Linting $(wc -l < verilog_filelist.txt) files"
cat verilog_filelist.txt

if ! command -v verible-verilog-lint >/dev/null 2>&1; then
    echo "ERROR: verible-verilog-lint not found" >&2
    exit 1
fi

echo "Running Verible lint"

if [ -f ".rules.verible_lint" ]; then
    verible-verilog-lint --rules_config=.rules.verible_lint $(cat verilog_filelist.txt)
else
    verible-verilog-lint $(cat verilog_filelist.txt)
fi

if ! command -v svlint >/dev/null 2>&1; then
    echo "ERROR: svlint not found" >&2
    exit 1
fi

echo "Running svlint"

if [ -f ".svlint.toml" ]; then
    svlint -c .svlint.toml $(cat verilog_filelist.txt)
else
    svlint $(cat verilog_filelist.txt)
fi

echo "Lint complete"