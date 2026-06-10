#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# test.sh
# ============================================================
#
# This script runs repository tests in CI and locally.
#
# Supported modes:
#
#   TEST_MODE="sim"
#       Run a pre-built simulator executable, such as the Verilator
#       binary produced by build.sh.
#
#   TEST_MODE="command"
#       Run TEST_CMD exactly as provided.
#
#   TEST_MODE="sources"
#       Discover source files under TEST_SOURCE_DIRS and run basic tests:
#
#           .c   -> compile with gcc and run
#           .cc  -> compile with g++ and run
#           .cpp -> compile with g++ and run
#           .sv  -> run Verilator lint/smoke check
#           .v   -> run Verilator lint/smoke check
#
#       This is useful for repos like AFT-dev where software tests live
#       under sw-tests/ and should be picked up automatically by the
#       template CI.
#
#   TEST_MODE="none"
#       Skip tests.
#
# ============================================================

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

check_tool() {
    local tool="$1"

    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: $tool not found" >&2
        exit 1
    fi
}

run_sim_test() {
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
}

run_command_test() {
    if [ -z "${TEST_CMD:-}" ]; then
        echo "ERROR: TEST_MODE=command but TEST_CMD is empty" >&2
        exit 1
    fi

    echo "Running custom test command"
    bash -lc "$TEST_CMD" | tee logs/test.log
}

has_ext() {
    local ext="$1"
    local allowed_ext

    for allowed_ext in ${TEST_SOURCE_EXTS:-c cc cpp sv v}; do
        if [ "$ext" = "$allowed_ext" ]; then
            return 0
        fi
    done

    return 1
}

discover_source_tests() {
    local out_file="$1"
    local dir
    local ext

    : > "$out_file"

    for dir in ${TEST_SOURCE_DIRS:-tests}; do
        if [ ! -d "$dir" ]; then
            echo "WARNING: test source directory not found, skipping: $dir"
            continue
        fi

        while IFS= read -r -d '' file; do
            ext="${file##*.}"

            if has_ext "$ext"; then
                echo "$file" >> "$out_file"
            fi
        done < <(find "$dir" -type f \( \
            -name "*.c" -o \
            -name "*.cc" -o \
            -name "*.cpp" -o \
            -name "*.sv" -o \
            -name "*.v" \
        \) -print0 | sort -z)
    done
}

should_skip_file() {
    local file="$1"
    local pattern

    for pattern in ${TEST_SOURCE_EXCLUDE_PATTERNS:-}; do
        if [[ "$file" == $pattern ]]; then
            return 0
        fi
    done

    return 1
}

run_c_test() {
    local src="$1"
    local name="$2"
    local exe="$3"
    local log="$4"

    check_tool "${CC:-gcc}"

    echo "Compiling C test: $src"
    "${CC:-gcc}" ${TEST_CFLAGS:-"-Wall -Wextra -O2"} $TEST_C_INCLUDE_FLAGS "$src" ${TEST_C_LDFLAGS:-} -o "$exe"

    echo "Running C test: $src"
    timeout "${TEST_TIMEOUT_SECONDS:-60}" "$exe" | tee "$log"
}

run_cpp_test() {
    local src="$1"
    local name="$2"
    local exe="$3"
    local log="$4"

    check_tool "${CXX:-g++}"

    echo "Compiling C++ test: $src"
    "${CXX:-g++}" ${TEST_CXXFLAGS:-"-Wall -Wextra -O2 -std=c++20"} $TEST_CXX_INCLUDE_FLAGS "$src" ${TEST_CXX_LDFLAGS:-} -o "$exe"

    echo "Running C++ test: $src"
    timeout "${TEST_TIMEOUT_SECONDS:-60}" "$exe" | tee "$log"
}

run_sv_test() {
    local src="$1"
    local name="$2"
    local log="$3"

    check_tool verilator

    echo "Running SystemVerilog smoke/lint test: $src"

    # For source-discovery tests, SystemVerilog defaults to lint-only.
    # Real RTL simulation usually needs a top module, clock/reset behavior,
    # plus a C++ or SystemVerilog testbench, so that should remain in
    # TEST_MODE="sim" or TEST_MODE="command".
    #
    # TEST_SV_FLAGS can add repo-specific defines/includes, for example:
    #
    #   TEST_SV_FLAGS="-Irtl -Itop_level +define+SYNTHESIS"
    #
    verilator --lint-only -Wall ${TEST_SV_FLAGS:-} "$src" 2>&1 | tee "$log"
}

check_test_log_for_pass_regex() {
    local log="$1"

    if [ -n "${PASS_REGEX:-}" ]; then
        echo "Checking $log for PASS_REGEX: $PASS_REGEX"

        if ! grep -E "$PASS_REGEX" "$log" >/dev/null; then
            echo "ERROR: pass regex was not found in $log" >&2
            exit 1
        fi
    fi
}

run_source_tests() {
    local test_list="logs/source_tests.f"
    local build_dir="${TEST_BUILD_DIR:-test_out}"
    local total=0
    local passed=0
    local skipped=0
    local failed=0
    local file
    local ext
    local safe_name
    local exe
    local log

    mkdir -p "$build_dir"

    # Build include flags from TEST_INCLUDE_DIRS.
    TEST_C_INCLUDE_FLAGS=""
    TEST_CXX_INCLUDE_FLAGS=""

    for inc_dir in ${TEST_INCLUDE_DIRS:-}; do
        TEST_C_INCLUDE_FLAGS="$TEST_C_INCLUDE_FLAGS -I$inc_dir"
        TEST_CXX_INCLUDE_FLAGS="$TEST_CXX_INCLUDE_FLAGS -I$inc_dir"
    done

    echo "Discovering source tests"
    echo "  Directories: ${TEST_SOURCE_DIRS:-tests}"
    echo "  Extensions:  ${TEST_SOURCE_EXTS:-c cc cpp sv v}"

    discover_source_tests "$test_list"

    if [ ! -s "$test_list" ]; then
        if [ "${TEST_ALLOW_EMPTY:-0}" = "1" ]; then
            echo "No source tests found, but TEST_ALLOW_EMPTY=1, passing"
            return 0
        fi

        echo "ERROR: no source tests found" >&2
        echo "Set TEST_ALLOW_EMPTY=1 if this is expected." >&2
        exit 1
    fi

    echo "Discovered source tests:"
    cat "$test_list"

    while IFS= read -r file; do
        [ -z "$file" ] && continue

        if should_skip_file "$file"; then
            echo "Skipping excluded test source: $file"
            skipped=$((skipped + 1))
            continue
        fi

        total=$((total + 1))
        ext="${file##*.}"
        safe_name="$(echo "$file" | sed 's#[^A-Za-z0-9_.-]#_#g')"
        exe="$build_dir/$safe_name.exe"
        log="logs/$safe_name.log"

        echo
        echo "============================================================"
        echo "Running source test: $file"
        echo "============================================================"

        if [ "$ext" = "c" ]; then
            if run_c_test "$file" "$safe_name" "$exe" "$log"; then
                check_test_log_for_pass_regex "$log"
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
            fi

        elif [ "$ext" = "cc" ] || [ "$ext" = "cpp" ]; then
            if run_cpp_test "$file" "$safe_name" "$exe" "$log"; then
                check_test_log_for_pass_regex "$log"
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
            fi

        elif [ "$ext" = "sv" ] || [ "$ext" = "v" ]; then
            if run_sv_test "$file" "$safe_name" "$log"; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
            fi

        else
            echo "Skipping unsupported extension: $file"
            skipped=$((skipped + 1))
        fi
    done < "$test_list"

    echo
    echo "============================================================"
    echo "Source test summary"
    echo "============================================================"
    echo "Total attempted: $total"
    echo "Passed:          $passed"
    echo "Failed:          $failed"
    echo "Skipped:         $skipped"

    if [ "$failed" -ne 0 ]; then
        echo "ERROR: one or more source tests failed" >&2
        exit 1
    fi
}

case "${TEST_MODE:-none}" in
    sim)
        run_sim_test
        ;;

    command)
        run_command_test
        ;;

    sources)
        run_source_tests
        ;;

    none)
        echo "TEST_MODE=none, skipping tests"
        ;;

    *)
        echo "ERROR: unknown TEST_MODE='${TEST_MODE}'" >&2
        echo "Valid options: sim, command, sources, none" >&2
        exit 1
        ;;
esac

echo "Test complete"