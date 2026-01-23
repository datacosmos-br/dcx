#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Unit Tests: RMAN State Management Functions
#
# Tests for:
#   - _rman_state_file()
#   - _rman_state_load()
#   - _rman_state_set()
#   - _rman_state_get()
#   - _rman_state_step_completed()
#   - oracle_rman_check_catalog_divergence()
#   - oracle_rman_exec_with_state() (mock execution)
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="${SCRIPT_DIR}/.."

# Test counters
PASS=0
FAIL=0
FAILED_TESTS=()

# Test utilities
assert_eq() {
    local expected="$1" actual="$2" msg="${3:-}"
    if [[ "${expected}" == "${actual}" ]]; then
        echo "[PASS] ${msg}"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] ${msg}"
        echo "       Expected: '${expected}'"
        echo "       Actual:   '${actual}'"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("${msg}")
    fi
}

assert_true() {
    local condition="$1" msg="${2:-}"
    if eval "${condition}"; then
        echo "[PASS] ${msg}"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] ${msg}"
        echo "       Condition failed: ${condition}"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("${msg}")
    fi
}

assert_false() {
    local condition="$1" msg="${2:-}"
    if ! eval "${condition}"; then
        echo "[PASS] ${msg}"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] ${msg}"
        echo "       Condition should have failed: ${condition}"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("${msg}")
    fi
}

#===============================================================================
# Setup
#===============================================================================
setup() {
    # Create temp directory for tests
    TEST_LOGDIR=$(mktemp -d)
    export LOGDIR="${TEST_LOGDIR}"

    # Suppress logging output during tests
    export LOG_LEVEL=0

    # Load libraries
    source "${PARENT_DIR}/lib/runtime.sh"
    source "${PARENT_DIR}/lib/oracle_rman.sh"

    echo "Test LOGDIR: ${TEST_LOGDIR}"
}

teardown() {
    # Cleanup temp directory
    if [[ -n "${TEST_LOGDIR:-}" && -d "${TEST_LOGDIR}" ]]; then
        rm -rf "${TEST_LOGDIR}"
    fi
}

#===============================================================================
# Test: _rman_state_file
#===============================================================================
test_state_file_path() {
    echo ""
    echo "=== Test: _rman_state_file ==="

    local result
    result=$(_rman_state_file)
    assert_eq "${TEST_LOGDIR}/execution_state.sh" "${result}" "_rman_state_file returns correct path"

    # Test with different LOGDIR
    local old_logdir="${LOGDIR}"
    export LOGDIR="/custom/path"
    result=$(_rman_state_file)
    assert_eq "/custom/path/execution_state.sh" "${result}" "_rman_state_file uses LOGDIR"
    export LOGDIR="${old_logdir}"

    # Test fallback to /tmp
    unset LOGDIR
    result=$(_rman_state_file)
    assert_eq "/tmp/execution_state.sh" "${result}" "_rman_state_file falls back to /tmp"
    export LOGDIR="${old_logdir}"
}

#===============================================================================
# Test: _rman_state_set and _rman_state_get
#===============================================================================
test_state_set_get() {
    echo ""
    echo "=== Test: _rman_state_set / _rman_state_get ==="

    # Set a value
    _rman_state_set "TEST_KEY" "test_value"
    local result
    result=$(_rman_state_get "TEST_KEY")
    assert_eq "test_value" "${result}" "Set and get simple value"

    # Update existing value
    _rman_state_set "TEST_KEY" "updated_value"
    result=$(_rman_state_get "TEST_KEY")
    assert_eq "updated_value" "${result}" "Update existing value"

    # Get non-existent key with default
    result=$(_rman_state_get "NONEXISTENT_KEY" "default_val")
    assert_eq "default_val" "${result}" "Get non-existent key returns default"

    # Get non-existent key without default
    result=$(_rman_state_get "NONEXISTENT_KEY2")
    assert_eq "" "${result}" "Get non-existent key without default returns empty"

    # Set value with spaces
    _rman_state_set "KEY_WITH_SPACES" "value with spaces"
    result=$(_rman_state_get "KEY_WITH_SPACES")
    assert_eq "value with spaces" "${result}" "Handle value with spaces"

    # Set empty value
    _rman_state_set "EMPTY_KEY" ""
    result=$(_rman_state_get "EMPTY_KEY" "default")
    assert_eq "default" "${result}" "Empty value returns default"

    # Verify state file was created
    assert_true "[[ -f '$(_rman_state_file)' ]]" "State file was created"
}

#===============================================================================
# Test: _rman_state_load
#===============================================================================
test_state_load() {
    echo ""
    echo "=== Test: _rman_state_load ==="

    # Create a state file manually
    local state_file
    state_file=$(_rman_state_file)
    cat > "${state_file}" << 'EOF'
# Test state file
LOADED_VAR="loaded_value"
ANOTHER_VAR="another_value"
EOF

    # Load state
    _rman_state_load
    local rc=$?
    assert_eq "0" "${rc}" "_rman_state_load returns 0 when file exists"

    # Verify variables were loaded
    assert_eq "loaded_value" "${LOADED_VAR:-}" "Variable loaded from state file"
    assert_eq "another_value" "${ANOTHER_VAR:-}" "Second variable loaded"

    # Test load with no file
    rm -f "${state_file}"
    if _rman_state_load; then
        rc=0
    else
        rc=1
    fi
    assert_eq "1" "${rc}" "_rman_state_load returns 1 when file missing"
}

#===============================================================================
# Test: _rman_state_step_completed
#===============================================================================
test_step_completed() {
    echo ""
    echo "=== Test: _rman_state_step_completed ==="

    # Reset state file
    rm -f "$(_rman_state_file)"

    # Step not completed
    if _rman_state_step_completed "PREVIEW"; then
        echo "[FAIL] Step should not be completed initially"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("Step not completed initially")
    else
        echo "[PASS] Step not completed initially"
        PASS=$((PASS + 1))
    fi

    # Mark step as completed
    _rman_state_set "PREVIEW_COMPLETED" "1"
    if _rman_state_step_completed "PREVIEW"; then
        echo "[PASS] Step marked as completed"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] Step should be completed after setting"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("Step completed after setting")
    fi

    # Mark step as failed (COMPLETED=0)
    _rman_state_set "VALIDATE_COMPLETED" "0"
    if _rman_state_step_completed "VALIDATE"; then
        echo "[FAIL] Step with COMPLETED=0 should not be completed"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("Step with COMPLETED=0")
    else
        echo "[PASS] Step with COMPLETED=0 is not completed"
        PASS=$((PASS + 1))
    fi
}

#===============================================================================
# Test: oracle_rman_check_catalog_divergence
#===============================================================================
test_catalog_divergence() {
    echo ""
    echo "=== Test: oracle_rman_check_catalog_divergence ==="

    # Reset state file
    rm -f "$(_rman_state_file)"

    # Test 1: First run (no previous crosscheck) - should return 0 (no divergence)
    if oracle_rman_check_catalog_divergence; then
        echo "[PASS] First run returns no divergence (0)"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] First run should return 0 (no divergence)"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("First run divergence check")
    fi

    # Test 2: Recent crosscheck - should return 0
    local recent_time
    recent_time=$(date +%s)
    _rman_state_set "CROSSCHECK_TIMESTAMP" "${recent_time}"
    if oracle_rman_check_catalog_divergence; then
        echo "[PASS] Recent crosscheck returns no divergence (0)"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] Recent crosscheck should return 0"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("Recent crosscheck divergence")
    fi

    # Test 3: Old crosscheck (>1h ago) - should return 1
    local old_time
    old_time=$(($(date +%s) - 7200))  # 2 hours ago
    _rman_state_set "CROSSCHECK_TIMESTAMP" "${old_time}"
    if oracle_rman_check_catalog_divergence; then
        echo "[FAIL] Old crosscheck should return 1 (divergence)"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("Old crosscheck divergence")
    else
        echo "[PASS] Old crosscheck returns divergence (1)"
        PASS=$((PASS + 1))
    fi
}

#===============================================================================
# Test: State persistence across multiple operations
#===============================================================================
test_state_persistence() {
    echo ""
    echo "=== Test: State Persistence ==="

    # Reset state file
    rm -f "$(_rman_state_file)"

    # Simulate DRY_RUN=1 workflow
    _rman_state_set "PREVIEW_COMPLETED" "1"
    _rman_state_set "PREVIEW_LOG" "/tmp/preview.log"
    _rman_state_set "VALIDATE_COMPLETED" "1"
    _rman_state_set "VALIDATE_LOG" "/tmp/validate.log"

    # Verify state file content
    local state_file
    state_file=$(_rman_state_file)
    assert_true "[[ -f '${state_file}' ]]" "State file exists after DRY_RUN=1"

    # Simulate loading in DRY_RUN=0
    unset PREVIEW_COMPLETED VALIDATE_COMPLETED
    _rman_state_load

    # Verify steps are detected as completed
    if _rman_state_step_completed "PREVIEW" && _rman_state_step_completed "VALIDATE"; then
        echo "[PASS] Steps detected as completed after reload"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] Steps should be detected as completed"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("State persistence across reload")
    fi

    # Verify log paths preserved
    local preview_log validate_log
    preview_log=$(_rman_state_get "PREVIEW_LOG")
    validate_log=$(_rman_state_get "VALIDATE_LOG")
    assert_eq "/tmp/preview.log" "${preview_log}" "Preview log path preserved"
    assert_eq "/tmp/validate.log" "${validate_log}" "Validate log path preserved"
}

#===============================================================================
# Test: Multiple key updates
#===============================================================================
test_multiple_updates() {
    echo ""
    echo "=== Test: Multiple Key Updates ==="

    # Reset state file
    rm -f "$(_rman_state_file)"

    # Set multiple values
    _rman_state_set "KEY1" "value1"
    _rman_state_set "KEY2" "value2"
    _rman_state_set "KEY3" "value3"

    # Update middle key
    _rman_state_set "KEY2" "updated2"

    # Verify all values
    assert_eq "value1" "$(_rman_state_get "KEY1")" "KEY1 unchanged"
    assert_eq "updated2" "$(_rman_state_get "KEY2")" "KEY2 updated"
    assert_eq "value3" "$(_rman_state_get "KEY3")" "KEY3 unchanged"

    # Verify no duplicates in file
    local key2_count
    key2_count=$(grep -c "^KEY2=" "$(_rman_state_file)")
    assert_eq "1" "${key2_count}" "No duplicate KEY2 entries"
}

#===============================================================================
# Main
#===============================================================================
main() {
    echo "========================================"
    echo "  RMAN State Management Unit Tests"
    echo "========================================"

    # Setup
    setup

    # Run tests
    test_state_file_path
    test_state_set_get
    test_state_load
    test_step_completed
    test_catalog_divergence
    test_state_persistence
    test_multiple_updates

    # Teardown
    teardown

    # Summary
    echo ""
    echo "========================================"
    echo "  TEST SUMMARY"
    echo "========================================"
    echo "Passed: ${PASS}"
    echo "Failed: ${FAIL}"

    if [[ ${FAIL} -gt 0 ]]; then
        echo ""
        echo "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - ${test}"
        done
        exit 1
    fi

    echo ""
    echo "STATUS: ALL TESTS PASSED"
    exit 0
}

main "$@"
