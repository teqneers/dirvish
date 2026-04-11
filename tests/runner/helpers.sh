#!/bin/bash
# Minimal test framework: pass/fail tracking with clear output.

TESTS_PASS=0
TESTS_FAIL=0
CURRENT_SUITE=""

suite() {
    CURRENT_SUITE="$1"
    echo ""
    echo "=== $1 ==="
}

pass() {
    TESTS_PASS=$((TESTS_PASS + 1))
    printf "  PASS  %s\n" "$1"
}

fail() {
    TESTS_FAIL=$((TESTS_FAIL + 1))
    printf "  FAIL  %s\n" "$1"
    [ -n "$2" ] && printf "        %s\n" "$2"
}

assert_eq() {
    local actual="$1" expected="$2" msg="$3"
    if [ "$actual" = "$expected" ]; then
        pass "$msg"
    else
        fail "$msg" "expected: '$expected'  got: '$actual'"
    fi
}

assert_ne() {
    local actual="$1" unexpected="$2" msg="$3"
    if [ "$actual" != "$unexpected" ]; then
        pass "$msg"
    else
        fail "$msg" "should not be: '$unexpected'"
    fi
}

assert_file_exists() {
    if [ -f "$1" ]; then
        pass "${2:-file exists: $1}"
    else
        fail "${2:-file exists: $1}" "not found: $1"
    fi
}

assert_dir_exists() {
    if [ -d "$1" ]; then
        pass "${2:-dir exists: $1}"
    else
        fail "${2:-dir exists: $1}" "not found: $1"
    fi
}

assert_not_exists() {
    if [ ! -e "$1" ]; then
        pass "${2:-not present: $1}"
    else
        fail "${2:-not present: $1}" "unexpectedly exists: $1"
    fi
}

assert_contains() {
    local file="$1" pattern="$2" msg="$3"
    if [ ! -f "$file" ]; then
        fail "$msg" "file not found: $file"
    elif grep -q "$pattern" "$file" 2>/dev/null; then
        pass "$msg"
    else
        fail "$msg" "'$pattern' not in $file"
    fi
}

# Run a command; assert it exits 0.
assert_cmd_ok() {
    local msg="$1"; shift
    if "$@" >/dev/null 2>&1; then
        pass "$msg"
    else
        fail "$msg" "command failed (exit $?): $*"
    fi
}

# Run a command; assert it exits non-zero.
assert_cmd_fails() {
    local msg="$1"; shift
    if ! "$@" >/dev/null 2>&1; then
        pass "$msg"
    else
        fail "$msg" "expected failure but succeeded: $*"
    fi
}

summary() {
    echo ""
    echo "---"
    printf "Results for '%s': %d passed, %d failed\n" \
        "${CURRENT_SUITE}" "$TESTS_PASS" "$TESTS_FAIL"
    echo "---"
    [ "$TESTS_FAIL" -eq 0 ]
}