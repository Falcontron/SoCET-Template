#!/bin/bash

BUILD_DIR=${1:-build}

if [ ! -d "$BUILD_DIR" ]; then
    echo "Build directory '$BUILD_DIR' does not exist!"
    echo "Run 'make' first to build the tests."
    exit 1
fi

echo "Running all tests in $BUILD_DIR..."
echo

failed=0
total=0

for test in "$BUILD_DIR"/*; do
    # Skip if no files match the pattern
    [ -e "$test" ] || continue
    
    # Skip if not executable
    [ -x "$test" ] || continue
    
    total=$((total + 1))
    echo "Running $(basename "$test")..."
    
    if "$test"; then
        echo "✓ $(basename "$test") passed"
    else
        echo "✗ $(basename "$test") failed"
        failed=$((failed + 1))
    fi
    echo
done

echo "Results: $((total - failed))/$total tests passed"

if [ $failed -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "$failed test(s) failed!"
    exit 1
fi
