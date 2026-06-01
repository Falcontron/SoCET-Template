#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "./config.env" ]; then
    echo "ERROR: config.env not found" >&2
    exit 1
fi

source ./config.env

if [ "${SYNTH_ENABLED:-1}" != "1" ]; then
    echo "Synthesis disabled by config.env, skipping"
    exit 0
fi

if [ -n "${SYNTH_CMD:-}" ]; then
    echo "Running configured synthesis command"
    bash -lc "$SYNTH_CMD"
    exit 0
fi

if [ -z "${SYNTH_TOP:-}" ] || [ -z "${SYNTH_SRCS:-}" ]; then
    echo "No synthesis target configured (SYNTH_TOP/SYNTH_SRCS); skipping synthesis"
    exit 0
fi

if ! command -v sv2v >/dev/null 2>&1 || ! command -v yosys >/dev/null 2>&1; then
    echo "sv2v or yosys not found; skipping synthesis"
    exit 0
fi

mkdir -p .synth-out

sv2v ${SYNTH_SRCS} > .synth-out/${SYNTH_TOP}.v

yosys -q -p "
  read_verilog .synth-out/${SYNTH_TOP}.v
  synth -top ${SYNTH_TOP}
  stat -top ${SYNTH_TOP}
" 

echo "Synthesis step completed (placeholder flow)"
