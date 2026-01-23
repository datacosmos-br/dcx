#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Master Test Runner
#
# Executes all test scripts and provides summary.
#
# Usage:
#   ./run_all_tests.sh           # Run all tests
#   ./run_all_tests.sh --quick   # Run only syntax validation
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="${SCRIPT_DIR}/.."

QUICK_MODE=0
[[ "${1:-}" == "--quick" ]] && QUICK_MODE=1

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_TESTS=()

echo "========================================"
echo "  Datacosmos Script Test Suite"
echo "========================================"
echo
echo "Script Directory: ${PARENT_DIR}"
echo "Test Directory: ${SCRIPT_DIR}"
echo

#===============================================================================
# PHASE 1: Syntax Validation
#===============================================================================

echo "========================================"
echo "  Phase 1: Syntax Validation (bash -n)"
echo "========================================"
echo

syntax_ok=0
syntax_fail=0

# Test all library files
lib_files=(
    "lib/logging.sh"
    "lib/core.sh"
    "lib/runtime.sh"
    "lib/session.sh"
    "lib/config.sh"
    "lib/queue.sh"
    "lib/report.sh"
    "lib/oracle_core.sh"
    "lib/oracle_env.sh"
    "lib/oracle_config.sh"
    "lib/oracle_cluster.sh"
    "lib/oracle_instance.sh"
    "lib/oracle.sh"
    "lib/oracle_sql.sh"
    "lib/oracle_datapump.sh"
    "lib/oracle_oci.sh"
    "lib/oracle_rman.sh"
)

# Test main scripts
main_scripts=(
    "restore.sh"
    "migrate_v2.sh"
)

echo "Testing library files..."
for script in "${lib_files[@]}"; do
    if [[ -f "${PARENT_DIR}/${script}" ]]; then
        if bash -n "${PARENT_DIR}/${script}" 2>/dev/null; then
            echo "[PASS] Syntax OK: ${script}"
            syntax_ok=$((syntax_ok + 1))
        else
            echo "[FAIL] Syntax ERROR: ${script}"
            syntax_fail=$((syntax_fail + 1))
            FAILED_TESTS+=("Syntax: ${script}")
        fi
    else
        echo "[SKIP] Not found: ${script}"
    fi
done

echo
echo "Testing main scripts..."
for script in "${main_scripts[@]}"; do
    if [[ -f "${PARENT_DIR}/${script}" ]]; then
        if bash -n "${PARENT_DIR}/${script}" 2>/dev/null; then
            echo "[PASS] Syntax OK: ${script}"
            syntax_ok=$((syntax_ok + 1))
        else
            echo "[FAIL] Syntax ERROR: ${script}"
            syntax_fail=$((syntax_fail + 1))
            FAILED_TESTS+=("Syntax: ${script}")
        fi
    else
        echo "[SKIP] Not found: ${script}"
    fi
done

echo
echo "Syntax validation: ${syntax_ok} passed, ${syntax_fail} failed"
TOTAL_PASS=$((TOTAL_PASS + syntax_ok))
TOTAL_FAIL=$((TOTAL_FAIL + syntax_fail))

#===============================================================================
# PHASE 2: Library Loading Test
#===============================================================================

echo
echo "========================================"
echo "  Phase 2: Library Loading Test"
echo "========================================"
echo

# Test runtime.sh loads correctly
if bash -c 'source "'"${PARENT_DIR}"'/lib/runtime.sh" && type -t log >/dev/null' 2>/dev/null; then
    echo "[PASS] runtime.sh loads correctly"
    TOTAL_PASS=$((TOTAL_PASS + 1))
else
    echo "[FAIL] runtime.sh failed to load"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILED_TESTS+=("Load: runtime.sh")
fi

# Test oracle.sh auto-loads runtime.sh
if bash -c '
    export ORACLE_HOME=/tmp
    mkdir -p /tmp/bin
    touch /tmp/bin/sqlplus /tmp/bin/rman
    chmod +x /tmp/bin/sqlplus /tmp/bin/rman
    source "'"${PARENT_DIR}"'/lib/oracle.sh"
    type -t log >/dev/null && type -t oracle_sql_sysdba_exec >/dev/null
    rm -rf /tmp/bin
' 2>/dev/null; then
    echo "[PASS] oracle.sh loads correctly (auto-loads runtime.sh)"
    TOTAL_PASS=$((TOTAL_PASS + 1))
else
    echo "[FAIL] oracle.sh failed to load"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILED_TESTS+=("Load: oracle.sh")
fi

# Test double-sourcing protection
if bash -c '
    source "'"${PARENT_DIR}"'/lib/runtime.sh"
    source "'"${PARENT_DIR}"'/lib/runtime.sh"
    [[ -n "${__RUNTIME_LOADED:-}" ]]
' 2>/dev/null; then
    echo "[PASS] runtime.sh double-source protection works"
    TOTAL_PASS=$((TOTAL_PASS + 1))
else
    echo "[FAIL] runtime.sh double-source protection failed"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILED_TESTS+=("Double-source: runtime.sh")
fi

    #===============================================================================
    # PHASE 2.5: Integration Tests - Library Loading
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 2.5: Integration Tests"
    echo "========================================"
    echo

    # Test new core module system
    if bash -c '
        source "'"${PARENT_DIR}"'/lib/core.sh"
        core_require runtime config queue report
        type -t need_cmd >/dev/null && \
        type -t config_load >/dev/null && \
        type -t queue_init >/dev/null && \
        type -t report_init >/dev/null
    ' 2>/dev/null; then
        echo "[PASS] Core module system integrates correctly"
        TOTAL_PASS=$((TOTAL_PASS + 1))
    else
        echo "[FAIL] Core module system integration failed"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        FAILED_TESTS+=("Integration: core module system")
    fi

    # Test all libraries can be loaded together (legacy way)
    if bash -c '
        source "'"${PARENT_DIR}"'/lib/runtime.sh"
        source "'"${PARENT_DIR}"'/lib/oracle.sh"
        source "'"${PARENT_DIR}"'/lib/oracle_sql.sh"

        # Test that functions from different libraries coexist
        type log >/dev/null && \
        type oracle_core_validate_home >/dev/null && \
        type oracle_sql_execute_file >/dev/null && \
        [[ -n "${__RUNTIME_LOADED:-}" ]] && \
        [[ -n "${__ORACLE_LOADED:-}" ]] && \
        [[ -n "${__ORACLE_SQL_LOADED:-}" ]]
    ' 2>/dev/null; then
        echo "[PASS] All libraries integrate correctly (legacy)"
        TOTAL_PASS=$((TOTAL_PASS + 1))
    else
        echo "[FAIL] Library integration failed (legacy)"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        FAILED_TESTS+=("Integration: library loading (legacy)")
    fi

if [[ "${QUICK_MODE}" -eq 1 ]]; then
    echo
    echo "========================================"
    echo "  Quick Mode: Skipping unit tests"
    echo "========================================"
    echo
else
    #===============================================================================
    # PHASE 3: Core Module System Tests
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 3: Core Module System Tests"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_core.sh" ]]; then
        if "${SCRIPT_DIR}/test_core.sh"; then
            echo
            echo "[PASS] test_core.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_core.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Unit: test_core.sh")
        fi
    else
        echo "[SKIP] test_core.sh not found or not executable"
    fi

    #===============================================================================
    # PHASE 3.5: Module Dependency Tests
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 3.5: Module Dependency Tests"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_module_dependencies.sh" ]]; then
        if "${SCRIPT_DIR}/test_module_dependencies.sh"; then
            echo
            echo "[PASS] test_module_dependencies.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_module_dependencies.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Unit: test_module_dependencies.sh")
        fi
    else
        echo "[SKIP] test_module_dependencies.sh not found or not executable"
    fi

    #===============================================================================
    # PHASE 4: Unit Tests - runtime.sh
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 4: Unit Tests - runtime.sh"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_runtime.sh" ]]; then
        if "${SCRIPT_DIR}/test_runtime.sh"; then
            echo
            echo "[PASS] test_runtime.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_runtime.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Unit: test_runtime.sh")
        fi
    else
        echo "[SKIP] test_runtime.sh not found or not executable"
    fi

    #===============================================================================
    # PHASE 5: Unit Tests - logging.sh
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 5: Unit Tests - logging.sh"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_logging.sh" ]]; then
        if "${SCRIPT_DIR}/test_logging.sh"; then
            echo
            echo "[PASS] test_logging.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_logging.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Unit: test_logging.sh")
        fi
    else
        echo "[SKIP] test_logging.sh not found or not executable"
    fi

    #===============================================================================
    # PHASE 5.5: Unit Tests - report.sh
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 5.5: Unit Tests - report.sh"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_report.sh" ]]; then
        if "${SCRIPT_DIR}/test_report.sh"; then
            echo
            echo "[PASS] test_report.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_report.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Unit: test_report.sh")
        fi
    else
        echo "[SKIP] test_report.sh not found or not executable"
    fi

    #===============================================================================
    # PHASE 6: Unit Tests - oracle.sh
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 6: Unit Tests - oracle.sh"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_oracle.sh" ]]; then
        if "${SCRIPT_DIR}/test_oracle.sh"; then
            echo
            echo "[PASS] test_oracle.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_oracle.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Unit: test_oracle.sh")
        fi
    else
        echo "[SKIP] test_oracle.sh not found or not executable"
    fi

    #===============================================================================
    # PHASE 7: Unit Tests - oracle_sql.sh
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 7: Unit Tests - oracle_sql.sh"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_sqlexec.sh" ]]; then
        if "${SCRIPT_DIR}/test_sqlexec.sh"; then
            echo
            echo "[PASS] test_sqlexec.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_sqlexec.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Unit: test_sqlexec.sh")
        fi
    else
        echo "[SKIP] test_sqlexec.sh not found or not executable"
    fi

    #===============================================================================
    # PHASE 7.5: Logging & Config Tests
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 7.5: Logging & Config Tests"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_logging_context.sh" ]]; then
        if "${SCRIPT_DIR}/test_logging_context.sh"; then
            echo
            echo "[PASS] test_logging_context.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_logging_context.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Logging: test_logging_context.sh")
        fi
    else
        echo "[SKIP] test_logging_context.sh not found or not executable"
    fi

    if [[ -x "${SCRIPT_DIR}/test_config_hierarchical.sh" ]]; then
        if "${SCRIPT_DIR}/test_config_hierarchical.sh"; then
            echo
            echo "[PASS] test_config_hierarchical.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_config_hierarchical.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Config: test_config_hierarchical.sh")
        fi
    else
        echo "[SKIP] test_config_hierarchical.sh not found or not executable"
    fi

    if [[ -x "${SCRIPT_DIR}/test_config_validation.sh" ]]; then
        if "${SCRIPT_DIR}/test_config_validation.sh"; then
            echo
            echo "[PASS] test_config_validation.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_config_validation.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Config: test_config_validation.sh")
        fi
    else
        echo "[SKIP] test_config_validation.sh not found or not executable"
    fi

    if [[ -x "${SCRIPT_DIR}/test_config_profiles.sh" ]]; then
        if "${SCRIPT_DIR}/test_config_profiles.sh"; then
            echo
            echo "[PASS] test_config_profiles.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_config_profiles.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Config: test_config_profiles.sh")
        fi
    else
        echo "[SKIP] test_config_profiles.sh not found or not executable"
    fi

    #===============================================================================
    # PHASE 7.6: Integration Tests
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 7.6: Integration Tests"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_integration.sh" ]]; then
        if "${SCRIPT_DIR}/test_integration.sh"; then
            echo
            echo "[PASS] test_integration.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_integration.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Integration: test_integration.sh")
        fi
    else
        echo "[SKIP] test_integration.sh not found or not executable"
    fi

    #===============================================================================
    # PHASE 7.7: Queue Tests
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 7.7: Queue Tests"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_queue.sh" ]]; then
        if "${SCRIPT_DIR}/test_queue.sh"; then
            echo
            echo "[PASS] test_queue.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_queue.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Queue: test_queue.sh")
        fi
    else
        echo "[SKIP] test_queue.sh not found or not executable"
    fi

    #===============================================================================
    # PHASE 7.8: Report Integration Tests
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 7.8: Report Integration Tests"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_report_integration.sh" ]]; then
        if "${SCRIPT_DIR}/test_report_integration.sh"; then
            echo
            echo "[PASS] test_report_integration.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_report_integration.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Report Integration: test_report_integration.sh")
        fi
    else
        echo "[SKIP] test_report_integration.sh not found or not executable"
    fi

    #===============================================================================
    # PHASE 7.9: Restore Script Tests
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 7.9: Restore Script Tests"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_restore.sh" ]]; then
        if "${SCRIPT_DIR}/test_restore.sh"; then
            echo
            echo "[PASS] test_restore.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_restore.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("Restore: test_restore.sh")
        fi
    else
        echo "[SKIP] test_restore.sh not found or not executable"
    fi

    #===============================================================================
    # PHASE 7.10: RMAN State Management Tests
    #===============================================================================

    echo
    echo "========================================"
    echo "  Phase 7.10: RMAN State Management Tests"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_rman_state.sh" ]]; then
        if "${SCRIPT_DIR}/test_rman_state.sh"; then
            echo
            echo "[PASS] test_rman_state.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_rman_state.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("RMAN State: test_rman_state.sh")
        fi
    else
        echo "[SKIP] test_rman_state.sh not found or not executable"
    fi

    #---------------------------------------------------------------------------
    # Phase 7.11: RMAN Integration Tests (State Tracking Workflows)
    #---------------------------------------------------------------------------
    echo
    echo "========================================"
    echo "  Phase 7.11: RMAN Integration Tests"
    echo "========================================"
    echo

    if [[ -x "${SCRIPT_DIR}/test_rman_integration.sh" ]]; then
        if "${SCRIPT_DIR}/test_rman_integration.sh"; then
            echo
            echo "[PASS] test_rman_integration.sh completed"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            echo
            echo "[FAIL] test_rman_integration.sh had failures"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_TESTS+=("RMAN Integration: test_rman_integration.sh")
        fi
    else
        echo "[SKIP] test_rman_integration.sh not found or not executable"
    fi
fi

#===============================================================================
# PHASE 8: Examples Syntax Check
#===============================================================================

echo
echo "========================================"
echo "  Phase 8: Examples Syntax Validation"
echo "========================================"
echo

examples_ok=0
examples_fail=0

for script in "${PARENT_DIR}"/examples/*.sh; do
    if [[ -f "${script}" ]]; then
        if bash -n "${script}" 2>/dev/null; then
            echo "[PASS] Syntax OK: examples/$(basename "${script}")"
            examples_ok=$((examples_ok + 1))
        else
            echo "[FAIL] Syntax ERROR: examples/$(basename "${script}")"
            examples_fail=$((examples_fail + 1))
            FAILED_TESTS+=("Syntax: examples/$(basename "${script}")")
        fi
    fi
done

if [[ "${examples_ok}" -eq 0 && "${examples_fail}" -eq 0 ]]; then
    echo "[SKIP] No example scripts found"
else
    echo
    echo "Examples syntax: ${examples_ok} passed, ${examples_fail} failed"
    TOTAL_PASS=$((TOTAL_PASS + examples_ok))
    TOTAL_FAIL=$((TOTAL_FAIL + examples_fail))
fi

#===============================================================================
# SUMMARY
#===============================================================================

echo
echo "========================================"
echo "  FINAL SUMMARY"
echo "========================================"
echo
echo "Total Passed: ${TOTAL_PASS}"
echo "Total Failed: ${TOTAL_FAIL}"

if [[ "${TOTAL_FAIL}" -gt 0 ]]; then
    echo
    echo "Failed tests:"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - ${test}"
    done
    echo
    echo "STATUS: FAILED"
    exit 1
else
    echo
    echo "STATUS: ALL TESTS PASSED"
    exit 0
fi
