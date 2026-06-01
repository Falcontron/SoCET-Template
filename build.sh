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
# Primary build
# ============================================================

if [ "${PRIMARY_BUILD_ENABLED:-1}" = "1" ]; then
    if [ -n "${PRIMARY_BUILD_CMD:-}" ]; then
        echo "Running custom primary build command"
        bash -lc "$PRIMARY_BUILD_CMD"
    else
        echo "Using fusesoc to build ${FUSESOC_TOOL:-verilator} model"

        if [ -z "${BUILD_ROOT:-}" ]; then
            echo "ERROR: PRIMARY_BUILD_ENABLED=1 but BUILD_ROOT is empty" >&2
            exit 1
        fi

        if [ -z "${FUSESOC_TARGET:-}" ]; then
            echo "ERROR: PRIMARY_BUILD_ENABLED=1 but FUSESOC_TARGET is empty" >&2
            exit 1
        fi

        if [ -z "${FUSESOC_TOOL:-}" ]; then
            echo "ERROR: PRIMARY_BUILD_ENABLED=1 but FUSESOC_TOOL is empty" >&2
            exit 1
        fi

        if [ -z "${FUSESOC_CORE:-}" ]; then
            echo "ERROR: PRIMARY_BUILD_ENABLED=1 but FUSESOC_CORE is empty" >&2
            exit 1
        fi

        eval "EXTRA_ARGS=( ${FUSESOC_EXTRA_ARGS:-} )"

        fusesoc --cores-root . run --setup --build --build-root "$BUILD_ROOT" \
            --target "$FUSESOC_TARGET" --tool "$FUSESOC_TOOL" \
            "$FUSESOC_CORE" \
            "${EXTRA_ARGS[@]}"
    fi
fi

# ============================================================
# Secondary build
# ============================================================

if [ "${SECONDARY_BUILD_ENABLED:-0}" = "1" ]; then
    if [ -n "${SECONDARY_BUILD_CMD:-}" ]; then
        echo "Running custom secondary build command"
        bash -lc "$SECONDARY_BUILD_CMD"
    else
        if [ "${SECONDARY_FUSESOC_TOOL:-}" = "xcelium" ]; then
            if hash xrun; then
                fusesoc --cores-root . run --setup --build --build-root "$SECONDARY_BUILD_ROOT" \
                    --target "$FUSESOC_TARGET" --tool "$SECONDARY_FUSESOC_TOOL" \
                    "$FUSESOC_CORE" \
                    ${SECONDARY_FUSESOC_EXTRA_ARGS:-}
            else
                echo "No xrun, skipping xcelium build"
            fi
        else
            echo "Using fusesoc to build secondary ${SECONDARY_FUSESOC_TOOL} model"
            fusesoc --cores-root . run --setup --build --build-root "$SECONDARY_BUILD_ROOT" \
                --target "$FUSESOC_TARGET" --tool "$SECONDARY_FUSESOC_TOOL" \
                "$FUSESOC_CORE" \
                ${SECONDARY_FUSESOC_EXTRA_ARGS:-}
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