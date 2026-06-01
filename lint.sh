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
    echo "Running configured lint command"
    bash -lc "$LINT_CMD"
    exit 0
fi

mapfile -d '' lint_files < <(find . -type f \( -name '*.sv' -o -name '*.v' -o -name '*.svh' \) -print0)

if [ "${#lint_files[@]}" -eq 0 ]; then
    echo "No Verilog/SystemVerilog sources found; skipping lint"
    exit 0
fi

if command -v verible-verilog-lint >/dev/null 2>&1; then
    echo "Running verible lint over ${#lint_files[@]} file(s)"
    verible-verilog-lint --rules_config .rules.verible_lint "${lint_files[@]}"
else
    echo "verible-verilog-lint not found; skipping lint"
fi
