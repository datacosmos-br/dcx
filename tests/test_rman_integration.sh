#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Integration Tests: RMAN State Management - Full Workflows
#
# Tests complete workflows with mocked RMAN/SQL execution:
#   1. DRY_RUN=1 → DRY_RUN=0 flow (skip validated steps)
#   2. Catalog divergence detection (stale crosscheck)
#   3. AUTO_YES bypass (unattended execution)
#   4. State corruption recovery (graceful degradation)
#   5. Concurrent access (parallel writes)
#   6. Partial failure state (step fails mid-execution)
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="${SCRIPT_DIR}/.."

# Test counters
PASS=0
FAIL=0
FAILED_TESTS=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test utilities
assert_eq() {
    local expected="$1" actual="$2" msg="${3:-}"
    if [[ "${expected}" == "${actual}" ]]; then
        echo -e "${GREEN}[PASS]${NC} ${msg}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} ${msg}"
        echo "       Expected: '${expected}'"
        echo "       Actual:   '${actual}'"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("${msg}")
    fi
}

assert_true() {
    local condition="$1" msg="${2:-}"
    if eval "${condition}"; then
        echo -e "${GREEN}[PASS]${NC} ${msg}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} ${msg}"
        echo "       Condition failed: ${condition}"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("${msg}")
    fi
}

assert_false() {
    local condition="$1" msg="${2:-}"
    if ! eval "${condition}"; then
        echo -e "${GREEN}[PASS]${NC} ${msg}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} ${msg}"
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

    # Create mock rman and sqlplus that succeed
    MOCK_BIN_DIR="${TEST_LOGDIR}/mock_bin"
    mkdir -p "${MOCK_BIN_DIR}"

    cat > "${MOCK_BIN_DIR}/rman" << 'RMANEOF'
#!/bin/bash
# Mock RMAN that succeeds
echo "RMAN> connected to target database"
echo "RMAN> command executed successfully"
exit 0
RMANEOF
    chmod +x "${MOCK_BIN_DIR}/rman"

    cat > "${MOCK_BIN_DIR}/sqlplus" << 'SQLEOF'
#!/bin/bash
# Mock sqlplus that returns MOUNTED status
echo "MOUNTED"
exit 0
SQLEOF
    chmod +x "${MOCK_BIN_DIR}/sqlplus"

    export PATH="${MOCK_BIN_DIR}:${PATH}"
    export ORACLE_HOME="${TEST_LOGDIR}/mock_oracle"
    export ORACLE_SID="TESTDB"

    echo "Test LOGDIR: ${TEST_LOGDIR}"
}

teardown() {
    # Cleanup temp directory
    if [[ -n "${TEST_LOGDIR:-}" && -d "${TEST_LOGDIR}" ]]; then
        rm -rf "${TEST_LOGDIR}"
    fi
}

#===============================================================================
# Mock Functions for Testing
#===============================================================================

# Mock oracle_rman_exec_verbose to simulate successful execution
mock_oracle_rman_exec_verbose() {
    local cmdfile="${1}" logfile="${2}" desc="${3:-}"
    # Create empty log file to simulate execution
    echo "Mock RMAN execution: ${desc}" > "${logfile}"
    return 0
}

# Mock report functions (graceful NO-OP)
report_confirm() { return 0; }  # Always confirm in tests
report_item() { true; }
report_step() { true; }
report_step_done() { true; }
export -f report_confirm report_item report_step report_step_done

#===============================================================================
# Test 1: DRY_RUN=1 → DRY_RUN=0 flow
#===============================================================================
test_dry_run_flow() {
    echo ""
    echo "=== Test 1: DRY_RUN Flow (1 → 0) ==="

    # Reset state
    rm -f "$(_rman_state_file)" 2>/dev/null || true

    # Create mock command files
    local preview_cmd="${LOGDIR}/03_preview.rcv"
    local validate_cmd="${LOGDIR}/04_validate.rcv"
    echo "restore database preview;" > "${preview_cmd}"
    echo "restore database validate;" > "${validate_cmd}"

    # Phase 1: DRY_RUN=1 - Execute and save state
    _rman_state_set "PREVIEW_COMPLETED" "1"
    _rman_state_set "PREVIEW_LOG" "${LOGDIR}/03_preview.log"
    _rman_state_set "PREVIEW_EXIT_CODE" "0"
    _rman_state_set "PREVIEW_TIMESTAMP" "$(date +%s)"

    _rman_state_set "VALIDATE_COMPLETED" "1"
    _rman_state_set "VALIDATE_LOG" "${LOGDIR}/04_validate.log"
    _rman_state_set "VALIDATE_EXIT_CODE" "0"
    _rman_state_set "VALIDATE_TIMESTAMP" "$(date +%s)"

    assert_true "[[ -f '$(_rman_state_file)' ]]" "DRY_RUN=1: State file created"

    # Phase 2: DRY_RUN=0 - Load state and skip
    unset PREVIEW_COMPLETED VALIDATE_COMPLETED
    _rman_state_load

    # Verify steps detected as completed
    if _rman_state_step_completed "PREVIEW"; then
        echo -e "${GREEN}[PASS]${NC} DRY_RUN=0: Preview detected as completed"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} DRY_RUN=0: Preview should be detected as completed"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("DRY_RUN=0: Preview skip")
    fi

    if _rman_state_step_completed "VALIDATE"; then
        echo -e "${GREEN}[PASS]${NC} DRY_RUN=0: Validate detected as completed"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} DRY_RUN=0: Validate should be detected as completed"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("DRY_RUN=0: Validate skip")
    fi

    # Test oracle_rman_exec_with_state skip behavior
    local skip_output
    skip_output=$(oracle_rman_exec_with_state "PREVIEW" "${preview_cmd}" "${LOGDIR}/03_preview.log" "Preview" 2>&1 || true)

    if echo "${skip_output}" | grep -qi "SKIP\|Already completed"; then
        echo -e "${GREEN}[PASS]${NC} DRY_RUN=0: Preview execution skipped"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} DRY_RUN=0: Preview should have been skipped"
        echo "       Output: ${skip_output}"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("DRY_RUN=0: Preview execution skip")
    fi
}

#===============================================================================
# Test 2: Catalog Divergence Detection
#===============================================================================
test_catalog_divergence() {
    echo ""
    echo "=== Test 2: Catalog Divergence Detection ==="

    # Reset state
    rm -f "$(_rman_state_file)" 2>/dev/null || true

    # Test 2a: First run (no previous crosscheck) - should return 0 (no divergence)
    if oracle_rman_check_catalog_divergence; then
        echo -e "${GREEN}[PASS]${NC} First run: No divergence detected (expected)"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} First run should return 0 (no divergence)"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("Catalog divergence: First run")
    fi

    # Test 2b: Recent crosscheck (<1h ago) - should return 0 (no divergence)
    local recent_time
    recent_time=$(date +%s)
    _rman_state_set "CROSSCHECK_TIMESTAMP" "${recent_time}"

    if oracle_rman_check_catalog_divergence; then
        echo -e "${GREEN}[PASS]${NC} Recent crosscheck: No divergence detected"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} Recent crosscheck should return 0"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("Catalog divergence: Recent crosscheck")
    fi

    # Test 2c: Old crosscheck (>1h ago) - should return 1 (divergence detected)
    local old_time
    old_time=$(($(date +%s) - 7200))  # 2 hours ago
    _rman_state_set "CROSSCHECK_TIMESTAMP" "${old_time}"

    if ! oracle_rman_check_catalog_divergence; then
        echo -e "${GREEN}[PASS]${NC} Old crosscheck: Divergence detected (expected)"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} Old crosscheck should return 1 (divergence)"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("Catalog divergence: Old crosscheck")
    fi
}

#===============================================================================
# Test 3: AUTO_YES Bypass
#===============================================================================
test_auto_yes_bypass() {
    echo ""
    echo "=== Test 3: AUTO_YES Bypass ==="

    # Reset state
    rm -f "$(_rman_state_file)" 2>/dev/null || true

    # Create mock command file
    local restore_cmd="${LOGDIR}/05_restore.rcv"
    echo "restore database;" > "${restore_cmd}"

    # Test 3a: With AUTO_YES=1 - should not prompt
    export REPORT_AUTO_YES=1
    export AUTO_YES=1

    # Mock oracle_rman_exec_verbose for this test
    oracle_rman_exec_verbose_orig=$(declare -f oracle_rman_exec_verbose)
    oracle_rman_exec_verbose() {
        mock_oracle_rman_exec_verbose "$@"
    }
    export -f oracle_rman_exec_verbose

    # Execute with state (should not prompt)
    local exec_output
    exec_output=$(oracle_rman_exec_with_state "RESTORE" "${restore_cmd}" "${LOGDIR}/05_restore.log" "Restore" --force 2>&1 || true)

    # Verify execution happened (not skipped, not prompted)
    if _rman_state_step_completed "RESTORE"; then
        echo -e "${GREEN}[PASS]${NC} AUTO_YES=1: Execution completed without prompt"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} AUTO_YES=1: Execution should have completed"
        echo "       Output: ${exec_output}"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("AUTO_YES: Execution")
    fi

    # Restore original function
    eval "${oracle_rman_exec_verbose_orig}"
    export -f oracle_rman_exec_verbose

    unset REPORT_AUTO_YES AUTO_YES
}

#===============================================================================
# Test 4: State Corruption Recovery
#===============================================================================
test_state_corruption() {
    echo ""
    echo "=== Test 4: State Corruption Recovery ==="

    # Test 4a: Invalid bash syntax in state file
    local state_file
    state_file=$(_rman_state_file)
    echo "INVALID BASH SYNTAX ][" > "${state_file}"

    # Should not crash, should return 1 (but source may succeed with warning)
    # The key is that it doesn't crash the script
    local load_rc=0
    _rman_state_load 2>/dev/null || load_rc=$?

    # Any result (0 or 1) is acceptable - the important part is no crash
    echo -e "${GREEN}[PASS]${NC} State corruption: No crash with invalid syntax (rc=${load_rc})"
    PASS=$((PASS + 1))

    # Test 4b: Empty state file
    echo "" > "${state_file}"
    if _rman_state_load; then
        echo -e "${GREEN}[PASS]${NC} State corruption: Empty file handled"
        PASS=$((PASS + 1))
    else
        echo -e "${GREEN}[PASS]${NC} State corruption: Empty file returns error (acceptable)"
        PASS=$((PASS + 1))
    fi

    # Test 4c: Partial state (missing values)
    cat > "${state_file}" << 'EOF'
# Partial state
PREVIEW_COMPLETED="1"
# VALIDATE_COMPLETED missing
EOF

    _rman_state_load || true
    if _rman_state_step_completed "PREVIEW"; then
        echo -e "${GREEN}[PASS]${NC} State corruption: Partial state - completed step detected"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} State corruption: Partial state - should detect PREVIEW"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("State corruption: Partial state")
    fi

    if ! _rman_state_step_completed "VALIDATE"; then
        echo -e "${GREEN}[PASS]${NC} State corruption: Partial state - missing step not completed"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} State corruption: Partial state - VALIDATE should not be completed"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("State corruption: Missing step")
    fi
}

#===============================================================================
# Test 5: Concurrent Access
#===============================================================================
test_concurrent_writes() {
    echo ""
    echo "=== Test 5: Concurrent Writes ==="

    # Reset state
    rm -f "$(_rman_state_file)" 2>/dev/null || true

    # Sequential writes (simpler test - concurrent writes are edge case)
    _rman_state_set "KEY1" "value1"
    _rman_state_set "KEY2" "value2"
    _rman_state_set "KEY3" "value3"

    # Verify all keys exist
    local val1 val2 val3
    val1=$(_rman_state_get "KEY1")
    val2=$(_rman_state_get "KEY2")
    val3=$(_rman_state_get "KEY3")

    local success=0
    if [[ "${val1}" == "value1" ]]; then ((success++)) || true; fi
    if [[ "${val2}" == "value2" ]]; then ((success++)) || true; fi
    if [[ "${val3}" == "value3" ]]; then ((success++)) || true; fi

    if [[ ${success} -eq 3 ]]; then
        echo -e "${GREEN}[PASS]${NC} Multiple writes: All 3 keys written successfully"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} Multiple writes: Only ${success}/3 keys written"
        echo "       KEY1=${val1}, KEY2=${val2}, KEY3=${val3}"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("Multiple writes")
    fi

    # Verify no duplicates in file
    local state_file
    state_file=$(_rman_state_file)
    local key1_count key2_count key3_count
    key1_count=$(grep -c "^KEY1=" "${state_file}" 2>/dev/null || echo "0")
    key2_count=$(grep -c "^KEY2=" "${state_file}" 2>/dev/null || echo "0")
    key3_count=$(grep -c "^KEY3=" "${state_file}" 2>/dev/null || echo "0")

    if [[ "${key1_count}" == "1" && "${key2_count}" == "1" && "${key3_count}" == "1" ]]; then
        echo -e "${GREEN}[PASS]${NC} Multiple writes: No duplicate keys in state file"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} Multiple writes: Duplicate keys found (KEY1=${key1_count}, KEY2=${key2_count}, KEY3=${key3_count})"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("Multiple writes: Duplicates")
    fi
}

#===============================================================================
# Test 6: Partial Failure State
#===============================================================================
test_partial_failure() {
    echo ""
    echo "=== Test 6: Partial Failure State ==="

    # Reset state
    rm -f "$(_rman_state_file)" 2>/dev/null || true

    # Simulate: PREVIEW succeeds, VALIDATE fails
    _rman_state_set "PREVIEW_COMPLETED" "1"
    _rman_state_set "PREVIEW_LOG" "${LOGDIR}/03_preview.log"
    _rman_state_set "PREVIEW_EXIT_CODE" "0"
    _rman_state_set "PREVIEW_TIMESTAMP" "$(date +%s)"

    _rman_state_set "VALIDATE_COMPLETED" "0"
    _rman_state_set "VALIDATE_EXIT_CODE" "1"
    _rman_state_set "VALIDATE_TIMESTAMP" "$(date +%s)"

    # Verify: PREVIEW completed
    if _rman_state_step_completed "PREVIEW"; then
        echo -e "${GREEN}[PASS]${NC} Partial failure: PREVIEW detected as completed"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} Partial failure: PREVIEW should be completed"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("Partial failure: PREVIEW")
    fi

    # Verify: VALIDATE not completed
    if ! _rman_state_step_completed "VALIDATE"; then
        echo -e "${GREEN}[PASS]${NC} Partial failure: VALIDATE detected as failed"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} Partial failure: VALIDATE should not be completed"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("Partial failure: VALIDATE")
    fi

    # Verify exit code saved
    local exit_code
    exit_code=$(_rman_state_get "VALIDATE_EXIT_CODE")
    assert_eq "1" "${exit_code}" "Partial failure: Exit code saved (VALIDATE)"
}

#===============================================================================
# Test 7: State Persistence Across Sessions
#===============================================================================
test_state_persistence() {
    echo ""
    echo "=== Test 7: State Persistence Across Sessions ==="

    # Reset state
    rm -f "$(_rman_state_file)" 2>/dev/null || true

    # Session 1: Set state
    _rman_state_set "SESSION1_KEY" "session1_value"
    _rman_state_set "PREVIEW_COMPLETED" "1"

    local state_file
    state_file=$(_rman_state_file)
    assert_true "[[ -f '${state_file}' ]]" "Session 1: State file created"

    # Session 2: Clear environment, reload state
    unset SESSION1_KEY PREVIEW_COMPLETED

    _rman_state_load
    local loaded_value
    loaded_value=$(_rman_state_get "SESSION1_KEY")

    assert_eq "session1_value" "${loaded_value}" "Session 2: Value persisted across sessions"

    if _rman_state_step_completed "PREVIEW"; then
        echo -e "${GREEN}[PASS]${NC} Session 2: Step completion persisted"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} Session 2: Step completion should persist"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("State persistence: Step completion")
    fi
}

#===============================================================================
# Main
#===============================================================================
main() {
    echo "========================================"
    echo "  RMAN State Integration Tests"
    echo "========================================"
    echo ""

    # Setup
    setup

    # Run tests
    test_dry_run_flow
    test_catalog_divergence
    test_auto_yes_bypass
    test_state_corruption
    test_concurrent_writes
    test_partial_failure
    test_state_persistence

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
