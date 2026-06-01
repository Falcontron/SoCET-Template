#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "./config.env" ]; then
    echo "ERROR: config.env not found" >&2
    exit 1
fi

source ./config.env

if [ "${TEST_ENABLED:-1}" != "1" ]; then
    echo "Test disabled by config.env, skipping"
    exit 0
fi

mkdir -p logs

case "${TEST_MODE:-none}" in
    sim)
        if [ -z "${SIM_BIN:-}" ]; then
            echo "ERROR: TEST_MODE=sim but SIM_BIN is empty" >&2
            exit 1
        fi

        if [ ! -x "$SIM_BIN" ]; then
            echo "ERROR: simulator binary not found or not executable: $SIM_BIN" >&2
            echo "Did you run ./build.sh first?" >&2
            exit 1
        fi

        echo "Running simulator smoke test"
        timeout "${TEST_TIMEOUT_SECONDS:-60}" "$SIM_BIN" | tee logs/sim.log

        if [ -n "${PASS_REGEX:-}" ]; then
            echo "Checking simulation output for PASS_REGEX: $PASS_REGEX"

            if ! grep -E "$PASS_REGEX" logs/sim.log >/dev/null; then
                echo "ERROR: simulation completed, but pass regex was not found" >&2
                exit 1
            fi
        else
            echo "No PASS_REGEX set; clean simulator exit counts as pass"
        fi
        ;;

    command)
        if [ -z "${TEST_CMD:-}" ]; then
            echo "ERROR: TEST_MODE=command but TEST_CMD is empty" >&2
            exit 1
        fi

        echo "Running custom test command"
        bash -lc "$TEST_CMD" | tee logs/test.log
        ;;

    none)
        echo "TEST_MODE=none, skipping tests"
        ;;

    *)
        echo "ERROR: unknown TEST_MODE='${TEST_MODE}'" >&2
        echo "Valid options: sim, command, none" >&2
        exit 1
        ;;
esac

echo "Test complete"