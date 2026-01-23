#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test Suite: restore.sh
#
# Tests for restore.sh script features:
# - RMAN file naming with numeric prefixes
# - Argument parsing (--continue, --help)
# - Database state detection for continue mode
# - Restore window display
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="${SCRIPT_DIR}/.."

# Test counters
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL=$((FAIL + 1))
}

skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

#===============================================================================
# Test Environment Setup
#===============================================================================

setup_test_env() {
    export ORACLE_HOME="/tmp/mock_oracle_$$"
    export ORACLE_SID="TESTDB"
    export LOGDIR="/tmp/test_restore_$$"
    export TARGET_SID="TESTDB"
    export TARGET_DB_UNIQUE_NAME="TESTDB"

    mkdir -p "${ORACLE_HOME}/bin"
    mkdir -p "${LOGDIR}"

    # Create mock sqlplus and rman
    cat > "${ORACLE_HOME}/bin/sqlplus" << 'SQLEOF'
#!/bin/bash
echo "mock sqlplus"
exit 0
SQLEOF
    chmod +x "${ORACLE_HOME}/bin/sqlplus"

    cat > "${ORACLE_HOME}/bin/rman" << 'RMANEOF'
#!/bin/bash
echo "mock rman"
exit 0
RMANEOF
    chmod +x "${ORACLE_HOME}/bin/rman"

    export PATH="${ORACLE_HOME}/bin:${PATH}"
}

cleanup_test_env() {
    rm -rf "${ORACLE_HOME}" 2>/dev/null || true
    rm -rf "${LOGDIR}" 2>/dev/null || true
}

#===============================================================================
# SECTION 1: RMAN File Naming Tests
#===============================================================================

echo "========================================"
echo "  SECTION 1: RMAN File Naming"
echo "========================================"
echo

test_file_naming_variables() {
    # Source restore.sh in a subshell to extract variable definitions
    local output
    output=$(grep -E '^RMAN_|^POST_SQL|^RENAME_SQL' "${PARENT_DIR}/restore.sh" | head -10)

    # Check for numeric prefixes
    if echo "${output}" | grep -q '01_bootstrap'; then
        pass "RMAN_BOOT uses 01_bootstrap.rcv prefix"
    else
        fail "RMAN_BOOT should use 01_bootstrap.rcv prefix"
    fi

    if echo "${output}" | grep -q '02a_crosscheck'; then
        pass "RMAN_XCHK uses 02a_crosscheck.rcv prefix"
    else
        fail "RMAN_XCHK should use 02a_crosscheck.rcv prefix"
    fi

    if echo "${output}" | grep -q '02b_catalog'; then
        pass "RMAN_CAT uses 02b_catalog.rcv prefix"
    else
        fail "RMAN_CAT should use 02b_catalog.rcv prefix"
    fi

    if echo "${output}" | grep -q '03_preview'; then
        pass "RMAN_PRE uses 03_preview.rcv prefix"
    else
        fail "RMAN_PRE should use 03_preview.rcv prefix"
    fi

    if echo "${output}" | grep -q '04_validate'; then
        pass "RMAN_VAL uses 04_validate.rcv prefix"
    else
        fail "RMAN_VAL should use 04_validate.rcv prefix"
    fi

    if echo "${output}" | grep -q '05_restore'; then
        pass "RMAN_RES uses 05_restore.rcv prefix"
    else
        fail "RMAN_RES should use 05_restore.rcv prefix"
    fi

    if echo "${output}" | grep -q '06_recover'; then
        pass "RMAN_REC uses 06_recover.rcv prefix"
    else
        fail "RMAN_REC should use 06_recover.rcv prefix"
    fi

    if echo "${output}" | grep -q '07_post_restore'; then
        pass "POST_SQL uses 07_post_restore.sql prefix"
    else
        fail "POST_SQL should use 07_post_restore.sql prefix"
    fi

    if echo "${output}" | grep -q '08_rename_files'; then
        pass "RENAME_SQL uses 08_rename_files.sql prefix"
    else
        fail "RENAME_SQL should use 08_rename_files.sql prefix"
    fi
}

test_log_file_naming() {
    local output
    # Match ${LOGDIR}/NN_ or ${LOGDIR}/NNa_ patterns (e.g., 01_, 02a_, 02b_)
    output=$(grep -E '\$\{LOGDIR\}/[0-9]+[a-z]?_' "${PARENT_DIR}/restore.sh")

    if echo "${output}" | grep -q '01_bootstrap.log'; then
        pass "Log file uses 01_bootstrap.log"
    else
        fail "Log file should use 01_bootstrap.log"
    fi

    if echo "${output}" | grep -qE '02a_crosscheck.log|02b_catalog.log'; then
        pass "Log file uses 02a/02b prefixes for crosscheck/catalog"
    else
        fail "Log file should use 02a_crosscheck.log or 02b_catalog.log"
    fi

    if echo "${output}" | grep -q '05_restore.log'; then
        pass "Log file uses 05_restore.log"
    else
        fail "Log file should use 05_restore.log"
    fi
}

test_file_naming_variables
test_log_file_naming

#===============================================================================
# SECTION 2: Argument Parsing Tests
#===============================================================================

echo
echo "========================================"
echo "  SECTION 2: Argument Parsing"
echo "========================================"
echo

test_parse_args_function_exists() {
    if grep -q 'parse_args()' "${PARENT_DIR}/restore.sh"; then
        pass "parse_args function exists"
    else
        fail "parse_args function should exist"
    fi
}

test_continue_flag() {
    if grep -qE -- '--continue\|-c' "${PARENT_DIR}/restore.sh"; then
        pass "--continue|-c flag is handled"
    else
        fail "--continue|-c flag should be handled"
    fi
}

test_help_flag() {
    if grep -qE -- '--help\|-h' "${PARENT_DIR}/restore.sh"; then
        pass "--help|-h flag is handled"
    else
        fail "--help|-h flag should be handled"
    fi
}

test_help_output() {
    # Test --help output
    local output
    output=$(ORACLE_HOME=/tmp timeout 5 "${PARENT_DIR}/restore.sh" --help 2>&1 || true)

    if echo "${output}" | grep -q 'Usage:'; then
        pass "--help shows usage"
    else
        fail "--help should show usage"
    fi

    if echo "${output}" | grep -q -- '--continue'; then
        pass "--help documents --continue flag"
    else
        fail "--help should document --continue flag"
    fi

    if echo "${output}" | grep -q 'Environment Variables'; then
        pass "--help documents environment variables"
    else
        fail "--help should document environment variables"
    fi
}

test_continue_mode_variable() {
    if grep -q 'CONTINUE_MODE' "${PARENT_DIR}/restore.sh"; then
        pass "CONTINUE_MODE variable exists"
    else
        fail "CONTINUE_MODE variable should exist"
    fi

    if grep -q "runtime_set_default.*CONTINUE_MODE.*0" "${PARENT_DIR}/restore.sh"; then
        pass "CONTINUE_MODE defaults to 0"
    else
        fail "CONTINUE_MODE should default to 0"
    fi
}

test_parse_args_function_exists
test_continue_flag
test_help_flag
test_help_output
test_continue_mode_variable

#===============================================================================
# SECTION 3: Database State Detection Tests
#===============================================================================

echo
echo "========================================"
echo "  SECTION 3: State Detection"
echo "========================================"
echo

test_detect_db_state_function() {
    if grep -q 'detect_db_state()' "${PARENT_DIR}/restore.sh"; then
        pass "detect_db_state function exists"
    else
        fail "detect_db_state function should exist"
    fi
}

test_determine_skip_to_phase_function() {
    if grep -q 'determine_skip_to_phase()' "${PARENT_DIR}/restore.sh"; then
        pass "determine_skip_to_phase function exists"
    else
        fail "determine_skip_to_phase function should exist"
    fi
}

test_state_detection_handles_mounted() {
    # Check within determine_skip_to_phase function for MOUNTED -> catalog
    local func_content
    func_content=$(sed -n '/determine_skip_to_phase()/,/^}/p' "${PARENT_DIR}/restore.sh")

    if echo "${func_content}" | grep -q 'MOUNTED' && \
       echo "${func_content}" | grep -q 'echo "catalog"'; then
        pass "MOUNTED state skips to catalog phase"
    else
        fail "MOUNTED state should skip to catalog phase"
    fi
}

test_state_detection_handles_started() {
    # Check within determine_skip_to_phase function for STARTED -> bootstrap
    local func_content
    func_content=$(sed -n '/determine_skip_to_phase()/,/^}/p' "${PARENT_DIR}/restore.sh")

    if echo "${func_content}" | grep -q 'STARTED' && \
       echo "${func_content}" | grep -q 'echo "bootstrap"'; then
        pass "STARTED state skips to bootstrap phase"
    else
        fail "STARTED state should skip to bootstrap phase"
    fi
}

test_state_detection_handles_open() {
    # Check within determine_skip_to_phase function for OPEN -> done
    local func_content
    func_content=$(sed -n '/determine_skip_to_phase()/,/^}/p' "${PARENT_DIR}/restore.sh")

    if echo "${func_content}" | grep -q 'OPEN' && \
       echo "${func_content}" | grep -q 'echo "done"'; then
        pass "OPEN state returns done"
    else
        fail "OPEN state should return done"
    fi
}

test_detect_db_state_function
test_determine_skip_to_phase_function
test_state_detection_handles_mounted
test_state_detection_handles_started
test_state_detection_handles_open

#===============================================================================
# SECTION 4: Restore Window Tests (oracle_rman.sh)
#===============================================================================

echo
echo "========================================"
echo "  SECTION 4: Restore Window Display"
echo "========================================"
echo

test_restore_window_function_exists() {
    if grep -q 'oracle_rman_get_restore_window()' "${PARENT_DIR}/lib/oracle_rman.sh"; then
        pass "oracle_rman_get_restore_window function exists"
    else
        fail "oracle_rman_get_restore_window function should exist"
    fi
}

test_restore_window_no_stderr_suppression() {
    # Check that 2>/dev/null is NOT used when calling get_restore_window
    local line
    line=$(grep -n 'oracle_rman_get_restore_window' "${PARENT_DIR}/lib/oracle_rman.sh" | grep 'window_data=' | head -1)

    if echo "${line}" | grep -q '2>/dev/null'; then
        fail "oracle_rman_get_restore_window should not use 2>/dev/null"
    else
        pass "oracle_rman_get_restore_window does not suppress stderr"
    fi
}

test_restore_window_error_logging() {
    if grep -q 'log_debug.*Restore window query failed' "${PARENT_DIR}/lib/oracle_rman.sh"; then
        pass "Restore window errors are logged with log_debug"
    else
        fail "Restore window errors should be logged"
    fi
}

test_restore_window_data_filtering() {
    if grep -q "grep.*BKP_WINDOW\|ARCH_WINDOW" "${PARENT_DIR}/lib/oracle_rman.sh"; then
        pass "Restore window filters valid data lines"
    else
        fail "Restore window should filter valid data lines"
    fi
}

test_restore_window_display_sections() {
    local output
    output=$(grep -A5 'RESTORE WINDOW' "${PARENT_DIR}/lib/oracle_rman.sh")

    if echo "${output}" | grep -q 'Point-in-Time Recovery\|RESTORE WINDOW'; then
        pass "Restore window shows PITR header"
    else
        fail "Restore window should show Point-in-Time Recovery header"
    fi
}

test_restore_window_function_exists
test_restore_window_no_stderr_suppression
test_restore_window_error_logging
test_restore_window_data_filtering
test_restore_window_display_sections

#===============================================================================
# SECTION 5: Main Flow Tests
#===============================================================================

echo
echo "========================================"
echo "  SECTION 5: Main Flow"
echo "========================================"
echo

test_main_handles_continue_mode() {
    if grep -q 'CONTINUE_MODE.*==.*1' "${PARENT_DIR}/restore.sh"; then
        pass "main() handles CONTINUE_MODE"
    else
        fail "main() should handle CONTINUE_MODE"
    fi
}

test_main_skips_phases_in_continue() {
    if grep -q 'skip_to.*!=.*catalog.*phase_validate_and_discover' "${PARENT_DIR}/restore.sh" || \
       grep -q 'skip_to.*catalog.*bootstrap' "${PARENT_DIR}/restore.sh"; then
        pass "main() skips phases in continue mode"
    else
        fail "main() should skip phases in continue mode"
    fi
}

test_parse_args_called_before_main() {
    # Check that parse_args is called before main
    local parse_line main_line
    parse_line=$(grep -n 'parse_args.*\$@' "${PARENT_DIR}/restore.sh" | tail -1 | cut -d: -f1)
    main_line=$(grep -n '^main$' "${PARENT_DIR}/restore.sh" | tail -1 | cut -d: -f1)

    if [[ -n "${parse_line}" && -n "${main_line}" && "${parse_line}" -lt "${main_line}" ]]; then
        pass "parse_args is called before main"
    else
        fail "parse_args should be called before main"
    fi
}

test_main_handles_continue_mode
test_main_skips_phases_in_continue
test_parse_args_called_before_main

#===============================================================================
# SECTION 6: Integration Tests
#===============================================================================

echo
echo "========================================"
echo "  SECTION 6: Integration"
echo "========================================"
echo

test_restore_syntax() {
    if bash -n "${PARENT_DIR}/restore.sh" 2>/dev/null; then
        pass "restore.sh has valid syntax"
    else
        fail "restore.sh syntax error"
    fi
}

test_oracle_rman_syntax() {
    if bash -n "${PARENT_DIR}/lib/oracle_rman.sh" 2>/dev/null; then
        pass "oracle_rman.sh has valid syntax"
    else
        fail "oracle_rman.sh syntax error"
    fi
}

test_no_switch_tempfile_in_restore() {
    # Verify switch tempfile all is NOT in the restore database section
    local restore_func
    restore_func=$(sed -n '/write_rman_restore()/,/^}/p' "${PARENT_DIR}/restore.sh")

    if echo "${restore_func}" | grep -q 'switch tempfile all'; then
        fail "write_rman_restore should not contain 'switch tempfile all'"
    else
        pass "write_rman_restore does not contain 'switch tempfile all'"
    fi
}

test_restore_syntax
test_oracle_rman_syntax
test_no_switch_tempfile_in_restore

#===============================================================================
# SUMMARY
#===============================================================================

echo
echo "========================================"
echo "  TEST SUMMARY"
echo "========================================"
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo

if [[ "${FAIL}" -gt 0 ]]; then
    echo "STATUS: FAILED"
    exit 1
else
    echo "STATUS: ALL TESTS PASSED"
    exit 0
fi
