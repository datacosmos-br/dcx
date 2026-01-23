#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: runtime.sh Unit Tests
#
# Validates all generic runtime.sh functions without Oracle dependencies.
# Can run on any system with bash 4.0+.
#
# Usage:
#   ./test_runtime.sh
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/runtime.sh"

#===============================================================================
# TEST FRAMEWORK
#===============================================================================

TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

run_test() {
    local name="$1"
    shift
    TEST_COUNT=$((TEST_COUNT + 1))

    # Run in subshell to isolate exit calls
    if ("$@") 2>/dev/null; then
        echo "[PASS] ${name}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "[FAIL] ${name}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

run_test_expect_fail() {
    local name="$1"
    shift
    TEST_COUNT=$((TEST_COUNT + 1))

    # Run in subshell to isolate exit calls (die/exit won't kill test runner)
    if ! ("$@") 2>/dev/null; then
        echo "[PASS] ${name} (expected failure)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "[FAIL] ${name} (should have failed)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

#===============================================================================
# TEST: Logging Functions
#===============================================================================

echo
echo "=== Testing Logging Functions ==="

run_test "ts returns timestamp" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    ts | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"
'

run_test "log outputs message" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    log "test message" | grep -q "test message"
'

run_test "warn outputs to stderr" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    warn "warning" 2>&1 | grep -q "WARN"
'

#===============================================================================
# TEST: Validators - rt_assert_nonempty
#===============================================================================

echo
echo "=== Testing rt_assert_nonempty ==="

run_test "nonempty accepts value" rt_assert_nonempty "TEST" "some_value"
run_test_expect_fail "nonempty rejects empty" rt_assert_nonempty "TEST" ""

#===============================================================================
# TEST: Validators - rt_assert_abs_path
#===============================================================================

echo
echo "=== Testing rt_assert_abs_path ==="

run_test "abs_path accepts /path" rt_assert_abs_path "PATH" "/absolute/path"
run_test "abs_path accepts /" rt_assert_abs_path "PATH" "/"
run_test_expect_fail "abs_path rejects relative" rt_assert_abs_path "PATH" "relative/path"
run_test_expect_fail "abs_path rejects ./path" rt_assert_abs_path "PATH" "./path"

#===============================================================================
# TEST: Validators - rt_assert_dir_exists
#===============================================================================

echo
echo "=== Testing rt_assert_dir_exists ==="

run_test "dir_exists accepts /tmp" rt_assert_dir_exists "DIR" "/tmp"
run_test "dir_exists accepts /" rt_assert_dir_exists "DIR" "/"
run_test_expect_fail "dir_exists rejects nonexistent" rt_assert_dir_exists "DIR" "/nonexistent_dir_12345"

#===============================================================================
# TEST: Validators - rt_assert_file_exists
#===============================================================================

echo
echo "=== Testing rt_assert_file_exists ==="

run_test "file_exists accepts /etc/passwd" rt_assert_file_exists "FILE" "/etc/passwd"
run_test_expect_fail "file_exists rejects nonexistent" rt_assert_file_exists "FILE" "/nonexistent_file_12345"
run_test_expect_fail "file_exists rejects directory" rt_assert_file_exists "FILE" "/tmp"

#===============================================================================
# TEST: Validators - rt_assert_enum
#===============================================================================

echo
echo "=== Testing rt_assert_enum ==="

run_test "enum accepts valid value" rt_assert_enum "MODE" "read" "read" "write" "append"
run_test "enum accepts any valid" rt_assert_enum "MODE" "append" "read" "write" "append"
run_test_expect_fail "enum rejects invalid" rt_assert_enum "MODE" "delete" "read" "write" "append"

#===============================================================================
# TEST: Validators - rt_assert_bool01
#===============================================================================

echo
echo "=== Testing rt_assert_bool01 ==="

run_test "bool01 accepts 0" rt_assert_bool01 "FLAG" "0"
run_test "bool01 accepts 1" rt_assert_bool01 "FLAG" "1"
run_test_expect_fail "bool01 rejects 2" rt_assert_bool01 "FLAG" "2"
run_test_expect_fail "bool01 rejects yes" rt_assert_bool01 "FLAG" "yes"
run_test_expect_fail "bool01 rejects true" rt_assert_bool01 "FLAG" "true"

#===============================================================================
# TEST: Validators - rt_assert_uint
#===============================================================================

echo
echo "=== Testing rt_assert_uint ==="

run_test "uint accepts 0" rt_assert_uint "NUM" "0"
run_test "uint accepts 123" rt_assert_uint "NUM" "123"
run_test "uint accepts large" rt_assert_uint "NUM" "999999999"
run_test_expect_fail "uint rejects negative" rt_assert_uint "NUM" "-1"
run_test_expect_fail "uint rejects float" rt_assert_uint "NUM" "1.5"
run_test_expect_fail "uint rejects text" rt_assert_uint "NUM" "abc"

#===============================================================================
# TEST: Validators - rt_assert_sid_token
#===============================================================================

echo
echo "=== Testing rt_assert_sid_token ==="

run_test "sid_token accepts ORCL" rt_assert_sid_token "SID" "ORCL"
run_test "sid_token accepts orcl19c" rt_assert_sid_token "SID" "orcl19c"
run_test "sid_token accepts TEST_DB" rt_assert_sid_token "SID" "TEST_DB"
run_test_expect_fail "sid_token rejects spaces" rt_assert_sid_token "SID" "TEST DB"
run_test_expect_fail "sid_token rejects dash" rt_assert_sid_token "SID" "TEST-DB"
run_test_expect_fail "sid_token rejects dot" rt_assert_sid_token "SID" "TEST.DB"

#===============================================================================
# TEST: Validators - rt_assert_regex
#===============================================================================

echo
echo "=== Testing rt_assert_regex ==="

run_test "regex matches pattern" rt_assert_regex "VAL" "abc123" '^[a-z]+[0-9]+$'
run_test "regex matches email-like" rt_assert_regex "VAL" "test@example" '^[a-z]+@[a-z]+$'
run_test_expect_fail "regex rejects non-match" rt_assert_regex "VAL" "123abc" '^[a-z]+[0-9]+$'

#===============================================================================
# TEST: Output Capture
#===============================================================================

echo
echo "=== Testing runtime_capture ==="

run_test "capture stores output" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    runtime_capture out echo "hello"
    [[ "${out}" == "hello" ]]
'

run_test "capture returns exit code" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    # Must handle non-zero return without set -e killing the subshell
    if runtime_capture out false; then
        exit 1  # Should have returned non-zero
    else
        exit 0  # Correctly returned non-zero
    fi
'

run_test "capture handles multiline" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    runtime_capture out printf "line1\nline2"
    [[ "${out}" == "line1
line2" ]]
'

#===============================================================================
# TEST: Configuration Loading (config_load in config.sh)
#===============================================================================

echo
echo "=== Testing config_load (from config.sh) ==="

TEMP_CONFIG="/tmp/test_config_$$.conf"
cat > "${TEMP_CONFIG}" <<'EOF'
# Comment line
KEY1=value1
KEY2="quoted value"
KEY3='single quoted'

# Another comment
NUMBER=42
EOF

run_test "load_config sets KEY1" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/config.sh"
    config_load "'"${TEMP_CONFIG}"'"
    [[ "${KEY1}" == "value1" ]]
'

run_test "load_config handles quoted" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/config.sh"
    config_load "'"${TEMP_CONFIG}"'"
    [[ "${KEY2}" == "quoted value" ]]
'

run_test "load_config handles single quoted" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/config.sh"
    config_load "'"${TEMP_CONFIG}"'"
    [[ "${KEY3}" == "single quoted" ]]
'

run_test "load_config handles numbers" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/config.sh"
    config_load "'"${TEMP_CONFIG}"'"
    [[ "${NUMBER}" == "42" ]]
'

rm -f "${TEMP_CONFIG}"

#===============================================================================
# TEST: Filesystem Utilities
#===============================================================================

echo
echo "=== Testing Filesystem Utilities ==="

run_test "fs_available_gb returns number" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    result=$(runtime_fs_available_gb "/tmp")
    [[ "${result}" =~ ^[0-9]+$ ]]
'

run_test "fs_used_percent returns number" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    result=$(runtime_fs_used_percent "/tmp")
    [[ "${result}" =~ ^[0-9]+$ ]]
'

#===============================================================================
# TEST: Display Utilities
#===============================================================================

echo
echo "=== Testing Display Utilities ==="

run_test "print_kv outputs formatted" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    runtime_print_kv "Key" "Value" | grep -q "Key"
'

run_test "print_section outputs header" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    runtime_print_section "Test Section" | grep -q "Test Section"
'

run_test "print_separator outputs line" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    runtime_print_separator | grep -qF -- "---"
'

#===============================================================================
# TEST: Retry Logic
#===============================================================================

echo
echo "=== Testing runtime_retry ==="

run_test "retry succeeds on first try" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    runtime_retry 3 1 true
'

run_test "retry fails after max attempts" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    ! runtime_retry 2 1 false
'

#===============================================================================
# TEST: Command Execution with Logging
#===============================================================================

echo
echo "=== Testing runtime_exec_logged ==="

run_test "exec_logged runs command and returns exit code" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    runtime_exec_logged "Test echo" "echo" "hello" > /dev/null
'

run_test "exec_logged returns non-zero on failure" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    ! runtime_exec_logged "Test false" "false" 2>/dev/null
'

run_test "exec_logged_to_file writes output to file" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    TMPFILE=$(mktemp)
    runtime_exec_logged_to_file "Test output" "${TMPFILE}" "echo" "test_output" >/dev/null 2>&1
    grep -q "test_output" "${TMPFILE}"
    rc=$?
    rm -f "${TMPFILE}"
    exit ${rc}
'

run_test "exec_silent succeeds silently" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    runtime_exec_silent "Test true" "true" 2>/dev/null
'

run_test "exec_silent logs on failure" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    runtime_exec_silent "Test false" "false" 2>&1 | grep -q "falhou"
'

#===============================================================================
# TEST: Temporary File Utilities
#===============================================================================

echo
echo "=== Testing Temporary File Utilities ==="

run_test "runtime_with_tempfile creates and passes temp file" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    callback() {
        local tmpfile="$1"
        [[ -f "${tmpfile}" ]] || exit 1
        echo "content" > "${tmpfile}"
        [[ -f "${tmpfile}" ]]
    }
    runtime_with_tempfile callback
'

run_test "runtime_with_tempdir creates and passes temp dir" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    callback() {
        local tmpdir="$1"
        [[ -d "${tmpdir}" ]] || exit 1
        touch "${tmpdir}/test_file"
        [[ -f "${tmpdir}/test_file" ]]
    }
    runtime_with_tempdir callback
'

#===============================================================================
# TEST: Time Utilities
#===============================================================================

echo
echo "=== Testing Time Utilities ==="

run_test "format_duration formats seconds" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    [[ "$(runtime_format_duration 45)" == "45s" ]]
'

run_test "format_duration formats minutes" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    [[ "$(runtime_format_duration 125)" == "2m 5s" ]]
'

run_test "format_duration formats hours" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    [[ "$(runtime_format_duration 3665)" == "1h 1m 5s" ]]
'

run_test "elapsed_since calculates time" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    start=$(date +%s)
    sleep 1
    elapsed=$(runtime_elapsed_since ${start})
    [[ ${elapsed} -ge 1 ]]
'

#===============================================================================
# SUMMARY
#===============================================================================

echo
echo "========================================"
echo "Test Summary: ${PASS_COUNT}/${TEST_COUNT} passed"
if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    echo "FAILURES: ${FAIL_COUNT}"
    exit 1
else
    echo "All tests passed!"
    exit 0
fi
