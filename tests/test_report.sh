#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: report.sh Unit Tests
#
# Validates all report.sh functions without external dependencies.
# Can run on any system with bash 4.0+.
#
# Usage:
#   ./test_report.sh              # Run basic tests
#   ./test_report.sh --fixtures   # Include fixture-based tests
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures/oracle_xe"
source "${SCRIPT_DIR}/../lib/report.sh"

# Parse arguments
USE_FIXTURES=0
for arg in "$@"; do
    case "${arg}" in
        --fixtures) USE_FIXTURES=1 ;;
    esac
done

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

    # Run in subshell to isolate exit calls
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

    # Run in subshell to isolate exit calls (die/exit won't kill test runner)
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
# TEST: Report Initialization
#===============================================================================

echo
echo "=== Testing Report Initialization ==="

run_test "report_init creates session" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPDIR=$(mktemp -d)
    report_init "Test Report" "${TMPDIR}" "test_session"
    [[ -n "${REPORT_TITLE:-}" ]] && \
    [[ -n "${REPORT_SESSION_ID:-}" ]] && \
    [[ -n "${REPORT_START_TIME:-}" ]]
    rm -rf "${TMPDIR}"
'

run_test "report_init creates report file" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPDIR=$(mktemp -d)
    report_init "Test Report" "${TMPDIR}" "test_session"
    [[ -f "${REPORT_FILE:-}" ]]
    rm -rf "${TMPDIR}"
'

#===============================================================================
# TEST: Phase and Step Tracking
#===============================================================================

echo
echo "=== Testing Phase and Step Tracking ==="

run_test "report_phase increments counter" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPDIR=$(mktemp -d)
    report_init "Test" "${TMPDIR}" "test"
    report_phase "Phase 1"
    report_phase "Phase 2"
    [[ "${_REPORT_PHASE_COUNT:-0}" -ge 2 ]]
    rm -rf "${TMPDIR}"
'

run_test "report_step increments counter" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPDIR=$(mktemp -d)
    report_init "Test" "${TMPDIR}" "test"
    report_phase "Phase 1"
    report_step "Step 1"
    report_step "Step 2"
    [[ "${_REPORT_STEP_COUNT:-0}" -ge 2 ]]
    rm -rf "${TMPDIR}"
'

run_test "report_step_done records success" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPDIR=$(mktemp -d)
    report_init "Test" "${TMPDIR}" "test"
    report_phase "Phase 1"
    report_step "Step 1"
    report_step_done 0
    [[ "${_REPORT_SUCCESS_COUNT:-0}" -ge 1 ]]
    rm -rf "${TMPDIR}"
'

run_test "report_step_done records failure" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPDIR=$(mktemp -d)
    report_init "Test" "${TMPDIR}" "test"
    report_phase "Phase 1"
    report_step "Step 1"
    report_step_done 1
    [[ "${_REPORT_FAIL_COUNT:-0}" -ge 1 ]]
    rm -rf "${TMPDIR}"
'

#===============================================================================
# TEST: Confirmation Functions
#===============================================================================

echo
echo "=== Testing Confirmation Functions ==="

run_test "report_confirm accepts with AUTO_YES" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    export REPORT_AUTO_YES=1
    report_confirm "Test confirmation"
'

run_test "report_confirm rejects with AUTO_NO" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    export REPORT_AUTO_NO=1
    ! report_confirm "Test confirmation"
'

run_test "report_confirm with token accepts with AUTO_YES" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    export REPORT_AUTO_YES=1
    report_confirm "Type YES to confirm" "YES"
'

#===============================================================================
# TEST: Data Collection
#===============================================================================

echo
echo "=== Testing Data Collection ==="

run_test "report_data stores key-value" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPDIR=$(mktemp -d)
    report_init "Test" "${TMPDIR}" "test"
    report_data "key1" "value1"
    [[ -n "${_REPORT_DATA[key1]:-}" ]] && \
    [[ "${_REPORT_DATA[key1]}" == "value1" ]]
    rm -rf "${TMPDIR}"
'

run_test "report_data_inc increments counter" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPDIR=$(mktemp -d)
    report_init "Test" "${TMPDIR}" "test"
    report_data_inc "counter"
    report_data_inc "counter"
    report_data_inc "counter"
    [[ "${_REPORT_DATA[counter]:-0}" == "3" ]]
    rm -rf "${TMPDIR}"
'

#===============================================================================
# TEST: Report Generation
#===============================================================================

echo
echo "=== Testing Report Generation ==="

run_test "report_end generates markdown file" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPDIR=$(mktemp -d)
    report_init "Test Report" "${TMPDIR}" "test_session"
    report_phase "Phase 1"
    report_step "Step 1"
    report_step_done 0
    report_end
    [[ -f "${REPORT_FILE:-}" ]] && \
    grep -q "Test Report" "${REPORT_FILE:-}"
    rm -rf "${TMPDIR}"
'

run_test "report includes phase info" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPDIR=$(mktemp -d)
    report_init "Test Report" "${TMPDIR}" "test_session"
    report_phase "My Custom Phase"
    report_step "Step 1"
    report_step_done 0
    report_end
    grep -q "My Custom Phase" "${REPORT_FILE:-}"
    rm -rf "${TMPDIR}"
'

#===============================================================================
# TEST: Display Functions
#===============================================================================

echo
echo "=== Testing Display Functions ==="

run_test "report_section outputs header" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPDIR=$(mktemp -d)
    report_init "Test" "${TMPDIR}" "test"
    output=$(report_section "Test Section")
    echo "${output}" | grep -q "Test Section"
    rm -rf "${TMPDIR}"
'

run_test "report_kv outputs key-value" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPDIR=$(mktemp -d)
    report_init "Test" "${TMPDIR}" "test"
    output=$(report_kv "Key" "Value")
    echo "${output}" | grep -q "Key" && echo "${output}" | grep -q "Value"
    rm -rf "${TMPDIR}"
'

run_test "report_table outputs formatted table" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPDIR=$(mktemp -d)
    report_init "Test" "${TMPDIR}" "test"
    output=$(report_table "Title" "Col1|Val1" "Col2|Val2")
    echo "${output}" | grep -q "Title"
    rm -rf "${TMPDIR}"
'

#===============================================================================
# TEST: Generic Output Analysis Functions
#===============================================================================

echo
echo "=== Testing Generic Output Analysis ==="

run_test "report_count_pattern counts occurrences" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPFILE=$(mktemp)
    echo -e "error\nerror\nok" > "${TMPFILE}"
    count=$(report_count_pattern "${TMPFILE}" "error")
    [[ "${count}" == "2" ]]
    rm -f "${TMPFILE}"
'

run_test "report_has_pattern returns true for match" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPFILE=$(mktemp)
    echo "test pattern here" > "${TMPFILE}"
    report_has_pattern "${TMPFILE}" "pattern"
    rm -f "${TMPFILE}"
'

run_test "report_has_pattern returns false for no match" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPFILE=$(mktemp)
    echo "test text" > "${TMPFILE}"
    ! report_has_pattern "${TMPFILE}" "nomatch"
    rm -f "${TMPFILE}"
'

run_test "report_parse_delimited extracts column" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPFILE=$(mktemp)
    echo -e "a|b|c\nd|e|f" > "${TMPFILE}"
    col2=$(report_parse_delimited "${TMPFILE}" "|" 2 | head -1)
    [[ "${col2}" == "b" ]]
    rm -f "${TMPFILE}"
'

#===============================================================================
# TEST: SQL Output Analysis Functions
#===============================================================================

echo
echo "=== Testing SQL Output Analysis ==="

run_test "report_sql_count_sections counts sections" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPFILE=$(mktemp)
    echo -e "--DATAFILES--\n1|file1\n--TEMPFILES--\n1|temp1" > "${TMPFILE}"
    count=$(report_sql_count_sections "${TMPFILE}")
    [[ "${count}" == "2" ]]
    rm -f "${TMPFILE}"
'

run_test "report_sql_section_count counts entries in section" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPFILE=$(mktemp)
    echo -e "--DATAFILES--\n1|file1\n2|file2\n--TEMPFILES--\n1|temp1" > "${TMPFILE}"
    count=$(report_sql_section_count "${TMPFILE}" "DATAFILES")
    [[ "${count}" == "2" ]]
    rm -f "${TMPFILE}"
'

run_test "report_sql_validate_discovery validates map" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPFILE=$(mktemp)
    echo -e "--DATAFILES--\n1|/data/file1.dbf\n--TEMPFILES--\n1|/temp/temp1.dbf" > "${TMPFILE}"
    report_sql_validate_discovery "${TMPFILE}"
    rm -f "${TMPFILE}"
'

#===============================================================================
# TEST: Data Pump Analysis Functions
#===============================================================================

echo
echo "=== Testing Data Pump Analysis ==="

run_test "report_dp_has_errors detects ORA errors" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPFILE=$(mktemp)
    echo "ORA-12345: Some error" > "${TMPFILE}"
    report_dp_has_errors "${TMPFILE}"
    rm -f "${TMPFILE}"
'

run_test "report_dp_get_status returns SUCCESS" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPFILE=$(mktemp)
    echo "Job successfully completed" > "${TMPFILE}"
    status=$(report_dp_get_status "${TMPFILE}")
    [[ "${status}" == "SUCCESS" ]]
    rm -f "${TMPFILE}"
'

run_test "report_dp_get_status returns WITH_ERRORS" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/report.sh"
    TMPFILE=$(mktemp)
    echo "Job completed with error at 12:00" > "${TMPFILE}"
    status=$(report_dp_get_status "${TMPFILE}")
    [[ "${status}" == "WITH_ERRORS" ]]
    rm -f "${TMPFILE}"
'

#===============================================================================
# TEST: Fixture-Based Tests (Real Oracle XE outputs)
#===============================================================================

if [[ "${USE_FIXTURES}" -eq 1 ]] && [[ -d "${FIXTURES_DIR}" ]]; then
    echo
    echo "=== Testing with Real Oracle XE Fixtures ==="

    # Test with real discovery_map.txt
    run_test "fixture: count_sections on real discovery_map" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        count=$(report_sql_count_sections "'"${FIXTURES_DIR}"'/discovery_map.txt")
        [[ "${count}" -ge 3 ]]
    '

    run_test "fixture: section_count DATAFILES" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        count=$(report_sql_section_count "'"${FIXTURES_DIR}"'/discovery_map.txt" "DATAFILES")
        [[ "${count}" -ge 1 ]]
    '

    run_test "fixture: section_count TEMPFILES" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        count=$(report_sql_section_count "'"${FIXTURES_DIR}"'/discovery_map.txt" "TEMPFILES")
        [[ "${count}" -ge 1 ]]
    '

    run_test "fixture: section_count REDO" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        count=$(report_sql_section_count "'"${FIXTURES_DIR}"'/discovery_map.txt" "REDO")
        [[ "${count}" -ge 1 ]]
    '

    run_test "fixture: validate_discovery on real map" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        report_sql_validate_discovery "'"${FIXTURES_DIR}"'/discovery_map.txt"
    '

    # Test with real ora_errors.txt
    run_test "fixture: count ORA errors in real file" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        count=$(report_count_pattern "'"${FIXTURES_DIR}"'/ora_errors.txt" "ORA-")
        [[ "${count}" -ge 5 ]]
    '

    run_test "fixture: has_pattern finds ORA-01034" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        report_has_pattern "'"${FIXTURES_DIR}"'/ora_errors.txt" "ORA-01034"
    '

    run_test "fixture: has_pattern finds ORA-01555" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        report_has_pattern "'"${FIXTURES_DIR}"'/ora_errors.txt" "ORA-01555"
    '

    # Test with real datapump_success.txt
    run_test "fixture: dp_get_status SUCCESS on real file" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        status=$(report_dp_get_status "'"${FIXTURES_DIR}"'/datapump_success.txt")
        [[ "${status}" == "SUCCESS" ]]
    '

    run_test "fixture: dp_has_errors false for success" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        ! report_dp_has_errors "'"${FIXTURES_DIR}"'/datapump_success.txt"
    '

    # Test with real datapump_with_errors.txt
    run_test "fixture: dp_get_status WITH_ERRORS on real file" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        status=$(report_dp_get_status "'"${FIXTURES_DIR}"'/datapump_with_errors.txt")
        [[ "${status}" == "WITH_ERRORS" ]]
    '

    run_test "fixture: dp_has_errors true for error file" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        report_dp_has_errors "'"${FIXTURES_DIR}"'/datapump_with_errors.txt"
    '

    # Test parsing real dba_users.txt
    run_test "fixture: parse_delimited on dba_users" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        username=$(report_parse_delimited "'"${FIXTURES_DIR}"'/dba_users.txt" "|" 1 | head -1)
        [[ -n "${username}" ]]
    '

    run_test "fixture: parse dba_users account status" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        line=$(grep "^SYS|" "'"${FIXTURES_DIR}"'/dba_users.txt")
        status=$(echo "${line}" | cut -d"|" -f2)
        [[ "${status}" == "OPEN" ]]
    '

    # Test parsing real v_datafile.txt
    run_test "fixture: parse v_datafile file paths" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        count=$(report_count_pattern "'"${FIXTURES_DIR}"'/v_datafile.txt" "\.dbf")
        [[ "${count}" -ge 3 ]]
    '

    run_test "fixture: parse_delimited on v_datafile sizes" bash -c '
        source "'"${SCRIPT_DIR}"'/../lib/report.sh"
        size=$(report_parse_delimited "'"${FIXTURES_DIR}"'/v_datafile.txt" "|" 4 | head -1)
        [[ "${size}" =~ ^[0-9]+$ ]]
    '

else
    if [[ "${USE_FIXTURES}" -eq 1 ]]; then
        echo
        echo "=== Fixture Tests Skipped (fixtures not found) ==="
        echo "Generate fixtures first: ./fixtures/generate_fixtures.sh"
    fi
fi

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
    echo "All tests passed!"
    exit 0
fi
