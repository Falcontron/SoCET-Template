#!/usr/bin/env bash
set -e

# ============================================================
# Generic build.sh
# ============================================================
# This script is intended to work across repos.
# Behavior is controlled by config.env.
# ============================================================

if [ ! -f "./config.env" ]; then
    echo "ERROR: config.env not found" >&2
    exit 1
fi

source ./config.env

# Master build toggle
if [ "${BUILD_ENABLED:-1}" != "1" ]; then
    echo "Build disabled by config.env, skipping"
    exit 0
fi

echo "Starting build for ${PROJECT_NAME:-project}"

# ============================================================
# Optional custom pre-build command
# ============================================================

if [ -n "${PRE_BUILD_CMD:-}" ]; then
    echo "Running custom pre-build command"
    bash -lc "$PRE_BUILD_CMD"
fi

# ============================================================
# Config step
# ============================================================

if [ "${CONFIG_STEP_ENABLED:-1}" = "1" ]; then
    echo "Running config step"

    if [ -z "${RISCV_CONFIG_DIR:-}" ]; then
        echo "ERROR: CONFIG_STEP_ENABLED=1 but RISCV_CONFIG_DIR is empty" >&2
        exit 1
    fi

    if [ -z "${RISCV_CONFIG_SCRIPT:-}" ]; then
        echo "ERROR: CONFIG_STEP_ENABLED=1 but RISCV_CONFIG_SCRIPT is empty" >&2
        exit 1
    fi

    if [ -z "${RISCV_CONFIG_FILE:-}" ]; then
        echo "ERROR: CONFIG_STEP_ENABLED=1 but RISCV_CONFIG_FILE is empty" >&2
        exit 1
    fi

    pushd "$RISCV_CONFIG_DIR"
    python3 "$RISCV_CONFIG_SCRIPT" "$RISCV_CONFIG_FILE"
    popd
fi

# ============================================================
# Version header generation
# ============================================================

if [ "${VERSION_HEADER_ENABLED:-0}" = "1" ]; then
    if [ -z "${GENERATE_VERSION_HEADER_SCRIPT:-}" ]; then
        echo "ERROR: VERSION_HEADER_ENABLED=1 but GENERATE_VERSION_HEADER_SCRIPT is empty" >&2
        exit 1
    fi

    "$GENERATE_VERSION_HEADER_SCRIPT"
fi

# ============================================================
# FuseSoC build
# ============================================================

if [ "${FUSESOC_BUILD_ENABLED:-1}" = "1" ]; then
    if [ -n "${FUSESOC_BUILD_CMD:-}" ]; then
        echo "Running custom FuseSoC build command"
        bash -lc "$FUSESOC_BUILD_CMD"
    else
        echo "Using fusesoc to build ${FUSESOC_TOOL:-verilator} model"

        if [ -z "${FUSESOC_BUILD_ROOT:-}" ]; then
            echo "ERROR: FUSESOC_BUILD_ENABLED=1 but FUSESOC_BUILD_ROOT is empty" >&2
            exit 1
        fi

        if [ -z "${FUSESOC_TARGET:-}" ]; then
            echo "ERROR: FUSESOC_BUILD_ENABLED=1 but FUSESOC_TARGET is empty" >&2
            exit 1
        fi

        if [ -z "${FUSESOC_TOOL:-}" ]; then
            echo "ERROR: FUSESOC_BUILD_ENABLED=1 but FUSESOC_TOOL is empty" >&2
            exit 1
        fi

        if [ -z "${FUSESOC_CORE:-}" ]; then
            echo "ERROR: FUSESOC_BUILD_ENABLED=1 but FUSESOC_CORE is empty" >&2
            exit 1
        fi

        eval "EXTRA_ARGS=( ${FUSESOC_EXTRA_ARGS:-} )"

        fusesoc --cores-root . run --setup --build --build-root "$FUSESOC_BUILD_ROOT" \
            --target "$FUSESOC_TARGET" --tool "$FUSESOC_TOOL" \
            "$FUSESOC_CORE" \
            "${EXTRA_ARGS[@]}"
    fi
fi

# ============================================================
# Optional Xcelium build
# ============================================================

if [ "${XCELIUM_BUILD_ENABLED:-0}" = "1" ]; then
    if [ -n "${XCELIUM_BUILD_CMD:-}" ]; then
        echo "Running custom Xcelium build command"
        bash -lc "$XCELIUM_BUILD_CMD"
    else
        if [ -z "${XCELIUM_BUILD_ROOT:-}" ]; then
            echo "ERROR: XCELIUM_BUILD_ENABLED=1 but XCELIUM_BUILD_ROOT is empty" >&2
            exit 1
        fi

        if [ -z "${FUSESOC_TARGET:-}" ]; then
            echo "ERROR: XCELIUM_BUILD_ENABLED=1 but FUSESOC_TARGET is empty" >&2
            exit 1
        fi

        if [ -z "${XCELIUM_TOOL:-}" ]; then
            echo "ERROR: XCELIUM_BUILD_ENABLED=1 but XCELIUM_TOOL is empty" >&2
            exit 1
        fi

        if [ -z "${FUSESOC_CORE:-}" ]; then
            echo "ERROR: XCELIUM_BUILD_ENABLED=1 but FUSESOC_CORE is empty" >&2
            exit 1
        fi

        eval "XCELIUM_ARGS=( ${XCELIUM_EXTRA_ARGS:-} )"

        if [ "${XCELIUM_TOOL:-}" = "xcelium" ]; then
            if hash xrun 2>/dev/null; then
                fusesoc --cores-root . run --setup --build --build-root "$XCELIUM_BUILD_ROOT" \
                    --target "$FUSESOC_TARGET" --tool "$XCELIUM_TOOL" \
                    "$FUSESOC_CORE" \
                    "${XCELIUM_ARGS[@]}"
            else
                echo "No xrun, skipping xcelium build"
            fi
        else
            echo "Using fusesoc to build Xcelium/secondary ${XCELIUM_TOOL} model"
            fusesoc --cores-root . run --setup --build --build-root "$XCELIUM_BUILD_ROOT" \
                --target "$FUSESOC_TARGET" --tool "$XCELIUM_TOOL" \
                "$FUSESOC_CORE" \
                "${XCELIUM_ARGS[@]}"
        fi
    fi
fi

# ============================================================
# Optional custom post-build command
# ============================================================

if [ -n "${POST_BUILD_CMD:-}" ]; then
    echo "Running custom post-build command"
    bash -lc "$POST_BUILD_CMD"
fi

echo "Build complete"