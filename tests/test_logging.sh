#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: logging.sh Unit Tests
#
# Validates all logging.sh functions without Oracle dependencies.
# Can run on any system with bash 4.0+.
#
# Usage:
#   ./test_logging.sh
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/logging.sh"

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

    # Run in subshell to isolate exit calls
    if ! ("$@") 2>/dev/null; then
        echo "[PASS] ${name} (expected failure)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "[FAIL] ${name} (should have failed)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

#===============================================================================
# TEST: Timestamp Function
#===============================================================================

echo
echo "=== Testing ts() ==="

run_test "ts returns ISO timestamp" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    ts | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"
'

#===============================================================================
# TEST: Basic Logging Functions
#===============================================================================

echo
echo "=== Testing Basic Logging ==="

run_test "log outputs INFO message" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log "test message" | grep -q "INFO"
'

run_test "log includes message content" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log "test message" | grep -q "test message"
'

run_test "warn outputs WARN to stderr" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    warn "warning" 2>&1 | grep -q "WARN"
'

run_test_expect_fail "die exits with code 1" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    die "fatal error"
'

#===============================================================================
# TEST: Structured Log Levels
#===============================================================================

echo
echo "=== Testing Log Levels ==="

run_test "log_debug hidden at LOG_LEVEL=2" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    export LOG_LEVEL=2
    output=$(log_debug "debug message")
    [[ -z "${output}" ]]
'

run_test "log_debug shown at LOG_LEVEL=3" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    export LOG_LEVEL=3
    log_debug "debug message" | grep -q "DEBUG"
'

run_test "log_success outputs SUCCESS" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_success "completed" | grep -q "SUCCESS"
'

run_test "log_error outputs ERROR" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_error "failed" 2>&1 | grep -q "ERROR"
'

#===============================================================================
# TEST: Command Logging
#===============================================================================

echo
echo "=== Testing Command Logging ==="

run_test "log_cmd outputs CMD" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_cmd "impdp" "user/pass@db par=x.par" | grep -q "CMD"
'

run_test "log_cmd masks passwords" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    output=$(log_cmd "impdp" "admin/secret123@prod parfile=x.par")
    echo "${output}" | grep -qF "***" && ! echo "${output}" | grep -q "secret123"
'

run_test "log_cmd_start shows command" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_cmd_start "rman" "Starting restore" | grep -q "rman"
'

run_test "log_cmd_end shows success" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_cmd_end "impdp" 0 "45s" | grep -q "completed"
'

run_test "log_cmd_end shows failure" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_cmd_end "impdp" 1 "10s" | grep -q "failed"
'

run_test "log_cmd respects LOG_SHOW_CMD=0" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    export LOG_SHOW_CMD=0
    output=$(log_cmd "test" "args")
    [[ -z "${output}" ]]
'

#===============================================================================
# TEST: SQL Logging
#===============================================================================

echo
echo "=== Testing SQL Logging ==="

run_test "log_sql outputs SQL operation" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_sql "SELECT" "SELECT * FROM dual" | grep -q "SQL"
'

run_test "log_sql truncates long SQL" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    long_sql=$(printf "a%.0s" {1..200})
    log_sql "SELECT" "${long_sql}" | grep -qF "..."
'

run_test "log_sql_file shows script name" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_sql_file "grants.sql" "/path/to/grants.sql" | grep -q "grants.sql"
'

run_test "log_sql_result shows success" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_sql_result 0 "42" | grep -q "42"
'

run_test "log_sql_result shows failure" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_sql_result 1 2>&1 | grep -q "FAILED"
'

run_test "log_sql respects LOG_SHOW_SQL=0" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    export LOG_SHOW_SQL=0
    output=$(log_sql "SELECT" "SELECT 1")
    [[ -z "${output}" ]]
'

#===============================================================================
# TEST: Blocking Operations Logging
#===============================================================================

echo
echo "=== Testing Blocking Operations ==="

run_test "log_block_start shows BLOCK" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_block_start "WAIT" "Waiting for export" | grep -q "BLOCK"
'

run_test "log_block_end shows completion" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_block_end "WAIT" "Export completed" | grep -q "BLOCK"
'

run_test "log_confirm shows question" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_confirm "Proceed?" "YES" | grep -q "Proceed?"
'

run_test "log_lock ACQUIRE message" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_lock "ACQUIRE" "/tmp/test.lock" | grep -q "Acquiring"
'

run_test "log_lock RELEASE message" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_lock "RELEASE" "/tmp/test.lock" | grep -q "Releasing"
'

run_test "log_lock BLOCKED message" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_lock "BLOCKED" "/tmp/test.lock" | grep -q "Blocked"
'

#===============================================================================
# TEST: Progress & Status Display
#===============================================================================

echo
echo "=== Testing Progress Display ==="

run_test "log_progress shows percentage" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_progress 5 10 "Processing" | grep -q "50%"
'

run_test "log_progress shows count" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_progress 3 10 "Importing" | grep -qF "[3/10]"
'

run_test "log_step shows step number" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_step 3 "Validating" | grep -q "Step 3"
'

run_test "log_phase shows phase header" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_phase "A" "Discovery" | grep -q "PHASE A"
'

#===============================================================================
# TEST: Display Utilities
#===============================================================================

echo
echo "=== Testing Display Utilities ==="

run_test "runtime_print_kv formats output" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    output=$(runtime_print_kv "Database" "PRODDB")
    echo "${output}" | grep -q "Database" && echo "${output}" | grep -q "PRODDB"
'

run_test "runtime_print_section outputs header" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    runtime_print_section "Test Section" | grep -q "Test Section"
'

run_test "runtime_print_separator outputs line" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    runtime_print_separator | grep -qF -- "---"
'

run_test "runtime_print_header outputs prominent header" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    runtime_print_header "MIGRATION" | grep -q "MIGRATION"
'

run_test "runtime_print_step outputs step" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    runtime_print_step "Validating" | grep -q "Validating"
'

#===============================================================================
# TEST: runtime_print_vars
#===============================================================================

echo
echo "=== Testing runtime_print_vars ==="

run_test "print_vars outputs title" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    runtime_print_vars "Config" "KEY=val" | grep -q "Config"
'

run_test "print_vars outputs key-value" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    runtime_print_vars "Test" "USER=admin" "HOST=localhost" | grep -q "USER" && \
    runtime_print_vars "Test" "USER=admin" "HOST=localhost" | grep -q "admin"
'

#===============================================================================
# TEST: Summary Tables
#===============================================================================

echo
echo "=== Testing Summary Tables ==="

run_test "log_summary_table outputs title" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_summary_table "SUMMARY" "Total|10" | grep -q "SUMMARY"
'

run_test "log_summary_table outputs rows" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    output=$(log_summary_table "Results" "Success|8" "Failed|2")
    echo "${output}" | grep -q "Success" && echo "${output}" | grep -q "8"
'

#===============================================================================
# TEST: File Display
#===============================================================================

echo
echo "=== Testing show_file ==="

TEMP_FILE="/tmp/test_show_file_$$.txt"
echo -e "line1\nline2\nline3" > "${TEMP_FILE}"

run_test "show_file displays file header" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    show_file "'"${TEMP_FILE}"'" 10 | grep -q "FILE:"
'

run_test "show_file displays file content" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    show_file "'"${TEMP_FILE}"'" 10 | grep -q "line1"
'

run_test "show_file handles missing file" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    show_file "/nonexistent_12345" 10 | grep -q "does not exist"
'

rm -f "${TEMP_FILE}"

#===============================================================================
# TEST: NO_COLOR Support
#===============================================================================

echo
echo "=== Testing NO_COLOR Support ==="

run_test "NO_COLOR disables ANSI codes" bash -c '
    export NO_COLOR=1
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    output=$(log_success "test")
    ! echo "${output}" | grep -qE "\\\\033\\["
'

#===============================================================================
# TEST: Timestamp Toggle
#===============================================================================

echo
echo "=== Testing Timestamp Toggle ==="

run_test "LOG_SHOW_TIMESTAMP=0 hides timestamp" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    export LOG_SHOW_TIMESTAMP=0
    output=$(_log_prefix INFO)
    ! echo "${output}" | grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2}"
'

run_test "LOG_SHOW_TIMESTAMP=1 shows timestamp" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    export LOG_SHOW_TIMESTAMP=1
    _log_prefix INFO | grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2}"
'

#===============================================================================
# TEST: Legacy Aliases
#===============================================================================

echo
echo "=== Testing Legacy Aliases ==="

run_test "log_info works" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_info "test" | grep -q "INFO"
'

run_test "log_success works" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_success "test" | grep -q "SUCCESS"
'

run_test "log_error works" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    log_error "test" 2>&1 | grep -q "ERROR"
'

run_test "warn works" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/logging.sh"
    warn "test" 2>&1 | grep -q "WARN"
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
