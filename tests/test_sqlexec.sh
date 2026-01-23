#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: oracle_sql.sh Basic Validation Tests
#
# Validates oracle_sql.sh syntax and basic function availability.
# Simple tests that don't require Oracle installation.
#
# Usage:
#   ./test_sqlexec.sh
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

    if ! ("$@") 2>/dev/null; then
        echo "[PASS] ${name} (expected failure)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "[FAIL] ${name} (should have failed)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

#===============================================================================
# SETUP: Source oracle_sql.sh
#===============================================================================

echo "=== Loading oracle_sql.sh ==="
source "${SCRIPT_DIR}/../lib/oracle_sql.sh"
echo "Library loaded successfully"
echo

#===============================================================================
# TEST: Function Availability
#===============================================================================

echo "=== Testing Function Availability ==="

# Connection management
run_test "oracle_sql_set_connection function exists" type -t oracle_sql_set_connection >/dev/null
run_test "oracle_sql_test_connection function exists" type -t oracle_sql_test_connection >/dev/null

# Script execution
run_test "oracle_sql_execute_file function exists" type -t oracle_sql_execute_file >/dev/null
run_test "oracle_sql_execute_batch function exists" type -t oracle_sql_execute_batch >/dev/null

# Query execution
run_test "oracle_sql_query function exists" type -t oracle_sql_query >/dev/null
run_test "oracle_sql_query_timeout function exists" type -t oracle_sql_query_timeout >/dev/null
run_test "oracle_sql_run function exists" type -t oracle_sql_run >/dev/null

# SYSDBA operations
run_test "oracle_sql_sysdba_exec function exists" type -t oracle_sql_sysdba_exec >/dev/null
run_test "oracle_sql_sysdba_query function exists" type -t oracle_sql_sysdba_query >/dev/null
run_test "oracle_sql_sysdba_file function exists" type -t oracle_sql_sysdba_file >/dev/null
run_test "oracle_sql_sysdba_exec_sid function exists" type -t oracle_sql_sysdba_exec_sid >/dev/null
run_test "oracle_sql_sysdba_exec_verbose function exists" type -t oracle_sql_sysdba_exec_verbose >/dev/null

# SYSDBA SID-specific operations
run_test "oracle_sql_sysdba_query_sid function exists" type -t oracle_sql_sysdba_query_sid >/dev/null
run_test "oracle_sql_sysdba_ping_sid function exists" type -t oracle_sql_sysdba_ping_sid >/dev/null
run_test "oracle_sql_sysdba_exec_sid_capture function exists" type -t oracle_sql_sysdba_exec_sid_capture >/dev/null
run_test "oracle_sql_sysdba_exec_sid_timeout function exists" type -t oracle_sql_sysdba_exec_sid_timeout >/dev/null

# Spool operations
run_test "oracle_sql_spool function exists" type -t oracle_sql_spool >/dev/null
run_test "oracle_sql_spool_sid function exists" type -t oracle_sql_spool_sid >/dev/null
run_test "oracle_sql_spool_formatted function exists" type -t oracle_sql_spool_formatted >/dev/null

# Structured output operations
run_test "oracle_sql_query_to_array function exists" type -t oracle_sql_query_to_array >/dev/null
run_test "oracle_sql_query_delimited function exists" type -t oracle_sql_query_delimited >/dev/null

# Output parsing utilities
run_test "oracle_sql_parse_section function exists" type -t oracle_sql_parse_section >/dev/null
run_test "oracle_sql_count_section function exists" type -t oracle_sql_count_section >/dev/null
run_test "oracle_sql_parse_kv function exists" type -t oracle_sql_parse_kv >/dev/null
run_test "oracle_sql_validate_output function exists" type -t oracle_sql_validate_output >/dev/null

#===============================================================================
# TEST: Default Configuration
#===============================================================================

echo
echo "=== Testing Default Configuration ==="

# Test directly in same shell since variables are set here
if [[ -n "${SQL_CONTINUE_ON_ERROR:-}" ]]; then
    echo "[PASS] SQL_CONTINUE_ON_ERROR has default value"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "[FAIL] SQL_CONTINUE_ON_ERROR has default value"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
TEST_COUNT=$((TEST_COUNT + 1))

if [[ -n "${SQL_DEFAULT_TIMEOUT:-}" ]]; then
    echo "[PASS] SQL_DEFAULT_TIMEOUT has default value"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "[FAIL] SQL_DEFAULT_TIMEOUT has default value"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
TEST_COUNT=$((TEST_COUNT + 1))

if [[ -n "${SQL_RETRY_COUNT:-}" ]]; then
    echo "[PASS] SQL_RETRY_COUNT has default value"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "[FAIL] SQL_RETRY_COUNT has default value"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
TEST_COUNT=$((TEST_COUNT + 1))

if [[ -n "${SQL_RETRY_DELAY:-}" ]]; then
    echo "[PASS] SQL_RETRY_DELAY has default value"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "[FAIL] SQL_RETRY_DELAY has default value"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
TEST_COUNT=$((TEST_COUNT + 1))

#===============================================================================
# TEST: Configuration Defaults
#===============================================================================

echo
echo "=== Testing Configuration Defaults ==="

if [[ "${SQL_CONTINUE_ON_ERROR}" == "0" ]]; then
    echo "[PASS] SQL_CONTINUE_ON_ERROR defaults to 0"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "[FAIL] SQL_CONTINUE_ON_ERROR defaults to 0"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
TEST_COUNT=$((TEST_COUNT + 1))

if [[ "${SQL_DEFAULT_TIMEOUT}" == "0" ]]; then
    echo "[PASS] SQL_DEFAULT_TIMEOUT defaults to 0"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "[FAIL] SQL_DEFAULT_TIMEOUT defaults to 0"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
TEST_COUNT=$((TEST_COUNT + 1))

if [[ "${SQL_RETRY_COUNT}" == "1" ]]; then
    echo "[PASS] SQL_RETRY_COUNT defaults to 1"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "[FAIL] SQL_RETRY_COUNT defaults to 1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
TEST_COUNT=$((TEST_COUNT + 1))

if [[ "${SQL_RETRY_DELAY}" == "5" ]]; then
    echo "[PASS] SQL_RETRY_DELAY defaults to 5"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "[FAIL] SQL_RETRY_DELAY defaults to 5"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
TEST_COUNT=$((TEST_COUNT + 1))

#===============================================================================
# TEST: Double-Source Protection
#===============================================================================

echo
echo "=== Testing Double-Source Protection ==="

if [[ -n "${__ORACLE_SQL_LOADED:-}" ]]; then
    echo "[PASS] oracle_sql.sh double-source protection"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "[FAIL] oracle_sql.sh double-source protection"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
TEST_COUNT=$((TEST_COUNT + 1))

#===============================================================================
# TEST: oracle_core.sh integration
#===============================================================================

echo
echo "=== Testing oracle_core.sh Integration ==="

if [[ -n "${__ORACLE_CORE_LOADED:-}" ]]; then
    echo "[PASS] oracle_core.sh loaded as dependency"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "[FAIL] oracle_core.sh should be loaded as dependency"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
TEST_COUNT=$((TEST_COUNT + 1))

run_test "oracle_core_get_binary function available" type -t oracle_core_get_binary >/dev/null
run_test "oracle_core_skip_oracle_cmds function available" type -t oracle_core_skip_oracle_cmds >/dev/null
run_test "oracle_core_exec function available" type -t oracle_core_exec >/dev/null

#===============================================================================
# TEST: runtime.sh integration
#===============================================================================

echo
echo "=== Testing runtime.sh Integration ==="

if [[ -n "${__RUNTIME_LOADED:-}" ]]; then
    echo "[PASS] runtime.sh loaded as dependency"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "[FAIL] runtime.sh should be loaded as dependency"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
TEST_COUNT=$((TEST_COUNT + 1))

run_test "runtime_capture function available" type -t runtime_capture >/dev/null
run_test "runtime_retry function available" type -t runtime_retry >/dev/null
run_test "runtime_timeout function available" type -t runtime_timeout >/dev/null
run_test "runtime_with_tempfile function available" type -t runtime_with_tempfile >/dev/null
run_test "rt_assert_nonempty function available" type -t rt_assert_nonempty >/dev/null
run_test "rt_assert_file_exists function available" type -t rt_assert_file_exists >/dev/null

#===============================================================================
# TEST: Test Mode Support
#===============================================================================

echo
echo "=== Testing Test Mode Support ==="

# Enable test mode
SKIP_ORACLE_CMDS=1

run_test "SYSDBA exec skips in test mode" bash -c "
    source '${SCRIPT_DIR}/../lib/oracle_sql.sh'
    SKIP_ORACLE_CMDS=1
    oracle_sql_sysdba_exec 'SELECT 1;'
"

run_test "SYSDBA query skips in test mode" bash -c "
    source '${SCRIPT_DIR}/../lib/oracle_sql.sh'
    SKIP_ORACLE_CMDS=1
    oracle_sql_sysdba_query 'SELECT 1;'
"

# Disable test mode (exported for any subsequent test suites)
export SKIP_ORACLE_CMDS=0

#===============================================================================
# CLEANUP
#===============================================================================

echo
echo "=== Cleanup ==="
echo "Tests completed."

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
    echo "All tests passed."
    exit 0
fi
