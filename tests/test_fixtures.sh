#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: Fixture Validation Tests
#
# Validates that all fixtures exist and contain expected content.
# These tests use real outputs captured from Oracle XE.
#
# Usage:
#   ./test_fixtures.sh
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures/oracle_xe"

# Source report.sh for parsing functions
source "${SCRIPT_DIR}/../lib/report.sh" 2>/dev/null || true

#===============================================================================
# TEST FRAMEWORK
#===============================================================================

TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
FAILED_TESTS=()

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
        FAILED_TESTS+=("${name}")
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
        FAILED_TESTS+=("${name}")
    fi
}

#===============================================================================
# TEST: Fixture Files Exist
#===============================================================================

echo
echo "=== Testing Fixture File Existence ==="

run_test "v_instance.txt exists" test -f "${FIXTURES_DIR}/v_instance.txt"
run_test "v_database.txt exists" test -f "${FIXTURES_DIR}/v_database.txt"
run_test "v_datafile.txt exists" test -f "${FIXTURES_DIR}/v_datafile.txt"
run_test "v_tempfile.txt exists" test -f "${FIXTURES_DIR}/v_tempfile.txt"
run_test "v_logfile.txt exists" test -f "${FIXTURES_DIR}/v_logfile.txt"
run_test "discovery_map.txt exists" test -f "${FIXTURES_DIR}/discovery_map.txt"
run_test "dba_users.txt exists" test -f "${FIXTURES_DIR}/dba_users.txt"
run_test "dba_tablespaces.txt exists" test -f "${FIXTURES_DIR}/dba_tablespaces.txt"
run_test "ora_errors.txt exists" test -f "${FIXTURES_DIR}/ora_errors.txt"
run_test "datapump_success.txt exists" test -f "${FIXTURES_DIR}/datapump_success.txt"
run_test "datapump_with_errors.txt exists" test -f "${FIXTURES_DIR}/datapump_with_errors.txt"

#===============================================================================
# TEST: Fixture Content Format - V$INSTANCE
#===============================================================================

echo
echo "=== Testing v_instance.txt Format ==="

run_test "v_instance has pipe delimiter" grep -q '|' "${FIXTURES_DIR}/v_instance.txt"
run_test "v_instance has OPEN status" grep -q 'OPEN' "${FIXTURES_DIR}/v_instance.txt"
run_test "v_instance has ACTIVE database_status" grep -q 'ACTIVE' "${FIXTURES_DIR}/v_instance.txt"

# Test parsing v_instance
run_test "v_instance can parse instance_name" bash -c '
    line=$(head -1 "'"${FIXTURES_DIR}"'/v_instance.txt")
    instance_name=$(echo "${line}" | cut -d"|" -f2)
    [[ -n "${instance_name}" ]]
'

run_test "v_instance can parse version" bash -c '
    line=$(head -1 "'"${FIXTURES_DIR}"'/v_instance.txt")
    version=$(echo "${line}" | cut -d"|" -f4)
    [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]
'

#===============================================================================
# TEST: Fixture Content Format - V$DATAFILE
#===============================================================================

echo
echo "=== Testing v_datafile.txt Format ==="

run_test "v_datafile has data" test -s "${FIXTURES_DIR}/v_datafile.txt"
run_test "v_datafile has pipe delimiter" grep -q '|' "${FIXTURES_DIR}/v_datafile.txt"
run_test "v_datafile has .dbf files" grep -q '\.dbf' "${FIXTURES_DIR}/v_datafile.txt"
run_test "v_datafile has system.dbf" grep -q 'system\.dbf' "${FIXTURES_DIR}/v_datafile.txt"

# Test parsing v_datafile
run_test "v_datafile can parse file number" bash -c '
    line=$(head -1 "'"${FIXTURES_DIR}"'/v_datafile.txt")
    file_num=$(echo "${line}" | cut -d"|" -f1)
    [[ "${file_num}" =~ ^[0-9]+$ ]]
'

run_test "v_datafile can parse file path" bash -c '
    line=$(head -1 "'"${FIXTURES_DIR}"'/v_datafile.txt")
    file_path=$(echo "${line}" | cut -d"|" -f2)
    [[ "${file_path}" == /* ]]
'

run_test "v_datafile can parse size in bytes" bash -c '
    line=$(head -1 "'"${FIXTURES_DIR}"'/v_datafile.txt")
    size=$(echo "${line}" | cut -d"|" -f4)
    [[ "${size}" =~ ^[0-9]+$ ]]
'

#===============================================================================
# TEST: Fixture Content Format - Discovery Map
#===============================================================================

echo
echo "=== Testing discovery_map.txt Format ==="

run_test "discovery_map has --DATAFILES-- section" grep -q '^--DATAFILES--$' "${FIXTURES_DIR}/discovery_map.txt"
run_test "discovery_map has --TEMPFILES-- section" grep -q '^--TEMPFILES--$' "${FIXTURES_DIR}/discovery_map.txt"
run_test "discovery_map has --REDO-- section" grep -q '^--REDO--$' "${FIXTURES_DIR}/discovery_map.txt"

# Test parsing discovery map sections
run_test "discovery_map DATAFILES section has entries" bash -c '
    count=$(awk "/^--DATAFILES--/{f=1;next} /^--/{f=0} f&&/\|/{print}" "'"${FIXTURES_DIR}"'/discovery_map.txt" | wc -l)
    [[ "${count}" -ge 1 ]]
'

run_test "discovery_map TEMPFILES section has entries" bash -c '
    count=$(awk "/^--TEMPFILES--/{f=1;next} /^--/{f=0} f&&/\|/{print}" "'"${FIXTURES_DIR}"'/discovery_map.txt" | wc -l)
    [[ "${count}" -ge 1 ]]
'

run_test "discovery_map REDO section has entries" bash -c '
    count=$(awk "/^--REDO--/{f=1;next} /^--/{f=0} f&&/\|/{print}" "'"${FIXTURES_DIR}"'/discovery_map.txt" | wc -l)
    [[ "${count}" -ge 1 ]]
'

#===============================================================================
# TEST: Fixture Content Format - DBA_USERS
#===============================================================================

echo
echo "=== Testing dba_users.txt Format ==="

run_test "dba_users has data" test -s "${FIXTURES_DIR}/dba_users.txt"
run_test "dba_users has pipe delimiter" grep -q '|' "${FIXTURES_DIR}/dba_users.txt"
run_test "dba_users has SYS user" grep -q '^SYS|' "${FIXTURES_DIR}/dba_users.txt"
run_test "dba_users has SYSTEM user" grep -q '^SYSTEM|' "${FIXTURES_DIR}/dba_users.txt"

# Test parsing dba_users
run_test "dba_users can parse username" bash -c '
    line=$(grep "^SYS|" "'"${FIXTURES_DIR}"'/dba_users.txt")
    username=$(echo "${line}" | cut -d"|" -f1)
    [[ "${username}" == "SYS" ]]
'

run_test "dba_users can parse account_status" bash -c '
    line=$(grep "^SYS|" "'"${FIXTURES_DIR}"'/dba_users.txt")
    status=$(echo "${line}" | cut -d"|" -f2)
    [[ -n "${status}" ]]
'

#===============================================================================
# TEST: Fixture Content Format - ORA Errors
#===============================================================================

echo
echo "=== Testing ora_errors.txt Format ==="

run_test "ora_errors has data" test -s "${FIXTURES_DIR}/ora_errors.txt"
run_test "ora_errors has ORA- prefix" grep -q '^ORA-' "${FIXTURES_DIR}/ora_errors.txt"
run_test "ora_errors has ORA-01034" grep -q 'ORA-01034' "${FIXTURES_DIR}/ora_errors.txt"
run_test "ora_errors has ORA-27101" grep -q 'ORA-27101' "${FIXTURES_DIR}/ora_errors.txt"
run_test "ora_errors has ORA-01555" grep -q 'ORA-01555' "${FIXTURES_DIR}/ora_errors.txt"
run_test "ora_errors has ORA-01917" grep -q 'ORA-01917' "${FIXTURES_DIR}/ora_errors.txt"

# Count ORA errors
run_test "ora_errors has at least 5 error types" bash -c '
    count=$(grep -c "^ORA-" "'"${FIXTURES_DIR}"'/ora_errors.txt")
    [[ "${count}" -ge 5 ]]
'

#===============================================================================
# TEST: Fixture Content Format - Data Pump Success
#===============================================================================

echo
echo "=== Testing datapump_success.txt Format ==="

run_test "datapump_success has data" test -s "${FIXTURES_DIR}/datapump_success.txt"
run_test "datapump_success has 'successfully completed'" grep -q 'successfully completed' "${FIXTURES_DIR}/datapump_success.txt"
run_test "datapump_success has export info" grep -q -E 'exported|imported' "${FIXTURES_DIR}/datapump_success.txt"
run_test "datapump_success has table rows" grep -q 'rows' "${FIXTURES_DIR}/datapump_success.txt"
run_test "datapump_success does NOT have errors" bash -c '
    ! grep -q "error(s)" "'"${FIXTURES_DIR}"'/datapump_success.txt"
'

#===============================================================================
# TEST: Fixture Content Format - Data Pump With Errors
#===============================================================================

echo
echo "=== Testing datapump_with_errors.txt Format ==="

run_test "datapump_with_errors has data" test -s "${FIXTURES_DIR}/datapump_with_errors.txt"
run_test "datapump_with_errors has 'completed with' errors" grep -q 'completed with.*error' "${FIXTURES_DIR}/datapump_with_errors.txt"
run_test "datapump_with_errors has ORA- errors" grep -q 'ORA-' "${FIXTURES_DIR}/datapump_with_errors.txt"
run_test "datapump_with_errors has ORA-31684" grep -q 'ORA-31684' "${FIXTURES_DIR}/datapump_with_errors.txt"
run_test "datapump_with_errors has ORA-01917" grep -q 'ORA-01917' "${FIXTURES_DIR}/datapump_with_errors.txt"

#===============================================================================
# TEST: Fixture Integration with report.sh Functions
#===============================================================================

echo
echo "=== Testing Integration with report.sh Functions ==="

# Test report_count_pattern with ora_errors
if type report_count_pattern &>/dev/null; then
    run_test "report_count_pattern counts ORA errors" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        count=$(report_count_pattern "'"${FIXTURES_DIR}"'/ora_errors.txt" "ORA-")
        [[ "${count}" -ge 5 ]]
    '
else
    echo "[SKIP] report_count_pattern not available"
fi

# Test report_has_pattern with datapump output
if type report_has_pattern &>/dev/null; then
    run_test "report_has_pattern finds success message" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        report_has_pattern "'"${FIXTURES_DIR}"'/datapump_success.txt" "successfully completed"
    '

    run_test "report_has_pattern finds error in error file" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        report_has_pattern "'"${FIXTURES_DIR}"'/datapump_with_errors.txt" "ORA-"
    '
else
    echo "[SKIP] report_has_pattern not available"
fi

# Test report_dp_has_errors
if type report_dp_has_errors &>/dev/null; then
    run_test "report_dp_has_errors detects errors" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        report_dp_has_errors "'"${FIXTURES_DIR}"'/datapump_with_errors.txt"
    '

    run_test "report_dp_has_errors returns false for success" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        ! report_dp_has_errors "'"${FIXTURES_DIR}"'/datapump_success.txt"
    '
else
    echo "[SKIP] report_dp_has_errors not available"
fi

# Test report_dp_get_status
if type report_dp_get_status &>/dev/null; then
    run_test "report_dp_get_status returns SUCCESS" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        status=$(report_dp_get_status "'"${FIXTURES_DIR}"'/datapump_success.txt")
        [[ "${status}" == "SUCCESS" ]]
    '

    run_test "report_dp_get_status returns WITH_ERRORS" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        status=$(report_dp_get_status "'"${FIXTURES_DIR}"'/datapump_with_errors.txt")
        [[ "${status}" == "WITH_ERRORS" ]]
    '
else
    echo "[SKIP] report_dp_get_status not available"
fi

#===============================================================================
# TEST: Fixture Parsing for Discovery Map
#===============================================================================

echo
echo "=== Testing Discovery Map Parsing ==="

# Test oracle_sql_parse_section equivalent
run_test "parse DATAFILES section" bash -c '
    content=$(awk "/^--DATAFILES--/{f=1;next} /^--/{f=0} f&&/\|/{print}" "'"${FIXTURES_DIR}"'/discovery_map.txt")
    [[ -n "${content}" ]]
'

run_test "parse TEMPFILES section" bash -c '
    content=$(awk "/^--TEMPFILES--/{f=1;next} /^--/{f=0} f&&/\|/{print}" "'"${FIXTURES_DIR}"'/discovery_map.txt")
    [[ -n "${content}" ]]
'

run_test "count DATAFILES entries" bash -c '
    count=$(awk "/^--DATAFILES--/{f=1;next} /^--/{f=0} f&&/\|/{print}" "'"${FIXTURES_DIR}"'/discovery_map.txt" | wc -l)
    [[ "${count}" -ge 1 ]]
'

run_test "count REDO entries" bash -c '
    count=$(awk "/^--REDO--/{f=1;next} /^--/{f=0} f&&/\|/{print}" "'"${FIXTURES_DIR}"'/discovery_map.txt" | wc -l)
    [[ "${count}" -ge 1 ]]
'

#===============================================================================
# SUMMARY
#===============================================================================

echo
echo "========================================"
echo "Test Summary: ${PASS_COUNT}/${TEST_COUNT} passed"
if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    echo "FAILURES: ${FAIL_COUNT}"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - ${test}"
    done
    exit 1
else
    echo "All tests passed."
    exit 0
fi
