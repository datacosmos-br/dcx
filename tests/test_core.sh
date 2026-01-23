#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: core.sh Module System Tests
#
# Comprehensive tests for the new module loading system:
# - Module registration
# - Dependency resolution
# - Lazy loading
# - Backward compatibility
# - Circular dependency detection
# - Integration with all modules
#
# Usage:
#   ./test_core.sh
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="${SCRIPT_DIR}/.."
LIB_DIR="${PARENT_DIR}/lib"

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
        return 0
    else
        echo "[FAIL] ${name}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_TESTS+=("${name}")
        return 1
    fi
}

run_test_expect_fail() {
    local name="$1"
    shift
    TEST_COUNT=$((TEST_COUNT + 1))

    if ! ("$@") 2>/dev/null; then
        echo "[PASS] ${name} (expected failure)"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo "[FAIL] ${name} (should have failed)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_TESTS+=("${name}")
        return 1
    fi
}

#===============================================================================
# PHASE 1: Basic Loading Tests
#===============================================================================

echo "========================================"
echo "  Phase 1: Basic Loading Tests"
echo "========================================"
echo

run_test "core.sh loads without errors" bash -c "
    source '${LIB_DIR}/core.sh'
    [[ -n \"\${__CORE_LOADED:-}\" ]]
"

run_test "core.sh loads logging.sh automatically" bash -c "
    source '${LIB_DIR}/core.sh'
    type -t log >/dev/null && type -t warn >/dev/null && type -t die >/dev/null
"

run_test "core.sh does NOT auto-load runtime.sh" bash -c "
    source '${LIB_DIR}/core.sh'
    ! type -t need_cmd >/dev/null 2>&1
"

run_test "core_require runtime loads runtime.sh" bash -c "
    source '${LIB_DIR}/core.sh'
    core_require runtime
    type -t need_cmd >/dev/null && type -t rt_assert_nonempty >/dev/null
"

#===============================================================================
# PHASE 2: Module Registration Tests
#===============================================================================

echo
echo "========================================"
echo "  Phase 2: Module Registration Tests"
echo "========================================"
echo

run_test "core_list_modules lists all modules" bash -c "
    source '${LIB_DIR}/core.sh'
    modules=\$(core_list_modules | wc -l)
    [[ \${modules} -ge 9 ]]
"

run_test "core_list_modules shows runtime module" bash -c "
    source '${LIB_DIR}/core.sh'
    core_list_modules | grep -q 'runtime'
"

run_test "core_list_modules shows config module" bash -c "
    source '${LIB_DIR}/core.sh'
    core_list_modules | grep -q 'config'
"

run_test "core_module_info shows module details" bash -c "
    source '${LIB_DIR}/core.sh'
    info=\$(core_module_info runtime)
    echo \"\${info}\" | grep -q 'Module: runtime' && \
    echo \"\${info}\" | grep -q 'File: runtime.sh'
"

run_test "core_module_info shows dependencies" bash -c "
    source '${LIB_DIR}/core.sh'
    info=\$(core_module_info config)
    echo \"\${info}\" | grep -q 'Dependencies: runtime'
"

run_test_expect_fail "core_module_info fails for unknown module" bash -c "
    source '${LIB_DIR}/core.sh'
    core_module_info nonexistent_module
"

#===============================================================================
# PHASE 3: Dependency Resolution Tests
#===============================================================================

echo
echo "========================================"
echo "  Phase 3: Dependency Resolution Tests"
echo "========================================"
echo

run_test "core_load config automatically loads runtime" bash -c "
    source '${LIB_DIR}/core.sh'
    core_load config
    type -t config_load >/dev/null && \
    type -t need_cmd >/dev/null && \
    [[ -n \"\${__RUNTIME_LOADED:-}\" ]] && \
    [[ -n \"\${__CONFIG_LOADED:-}\" ]]
"

run_test "core_load queue automatically loads runtime" bash -c "
    source '${LIB_DIR}/core.sh'
    core_load queue
    type -t queue_init >/dev/null && \
    type -t need_cmd >/dev/null && \
    [[ -n \"\${__RUNTIME_LOADED:-}\" ]] && \
    [[ -n \"\${__QUEUE_LOADED:-}\" ]]
"

run_test "core_load report automatically loads runtime" bash -c "
    source '${LIB_DIR}/core.sh'
    core_load report
    type -t report_init >/dev/null && \
    type -t need_cmd >/dev/null && \
    [[ -n \"\${__RUNTIME_LOADED:-}\" ]] && \
    [[ -n \"\${__REPORT_LOADED:-}\" ]]
"

run_test "core_require multiple modules loads dependencies once" bash -c "
    source '${LIB_DIR}/core.sh'
    core_require config queue report
    # Runtime should be loaded only once
    [[ -n \"\${__RUNTIME_LOADED:-}\" ]] && \
    [[ -n \"\${__CONFIG_LOADED:-}\" ]] && \
    [[ -n \"\${__QUEUE_LOADED:-}\" ]] && \
    [[ -n \"\${__REPORT_LOADED:-}\" ]]
"

#===============================================================================
# PHASE 4: Lazy Loading Tests
#===============================================================================

echo
echo "========================================"
echo "  Phase 4: Lazy Loading Tests"
echo "========================================"
echo

run_test "Modules not loaded until requested" bash -c "
    source '${LIB_DIR}/core.sh'
    ! type -t config_load >/dev/null 2>&1 && \
    ! type -t queue_init >/dev/null 2>&1
"

run_test "core_load loads module on demand" bash -c "
    source '${LIB_DIR}/core.sh'
    ! type -t config_load >/dev/null 2>&1
    core_load config
    type -t config_load >/dev/null
"

run_test "Double core_load is idempotent" bash -c "
    source '${LIB_DIR}/core.sh'
    core_load runtime
    core_load runtime
    type -t need_cmd >/dev/null
"

run_test "core_require is idempotent" bash -c "
    source '${LIB_DIR}/core.sh'
    core_require runtime
    core_require runtime
    type -t need_cmd >/dev/null
"

#===============================================================================
# PHASE 5: Oracle Module Tests
#===============================================================================

echo
echo "========================================"
echo "  Phase 5: Oracle Module Tests"
echo "========================================"
echo

run_test "core_load oracle loads oracle.sh" bash -c "
    source '${LIB_DIR}/core.sh'
    core_load oracle
    type -t oracle_core_validate_home >/dev/null && \
    [[ -n \"\${__ORACLE_LOADED:-}\" ]]
"

run_test "core_load oracle loads runtime dependency" bash -c "
    source '${LIB_DIR}/core.sh'
    core_load oracle
    type -t need_cmd >/dev/null && \
    [[ -n \"\${__RUNTIME_LOADED:-}\" ]]
"

run_test "core_load oracle_sql loads dependencies" bash -c "
    source '${LIB_DIR}/core.sh'
    core_load oracle_sql
    type -t oracle_sql_execute_file >/dev/null && \
    type -t need_cmd >/dev/null && \
    [[ -n \"\${__ORACLE_SQL_LOADED:-}\" ]] && \
    [[ -n \"\${__RUNTIME_LOADED:-}\" ]]
"

#===============================================================================
# PHASE 6: Backward Compatibility Tests
#===============================================================================

echo
echo "========================================"
echo "  Phase 6: Backward Compatibility Tests"
echo "========================================"
echo

run_test "core_load loads single module" bash -c "
    source '${LIB_DIR}/core.sh' >/dev/null 2>&1
    core_load config >/dev/null 2>&1
    type -t config_load >/dev/null
"

run_test "core_require loads multiple modules" bash -c "
    source '${LIB_DIR}/core.sh' >/dev/null 2>&1
    core_require config queue >/dev/null 2>&1
    type -t config_load >/dev/null && \
    type -t queue_init >/dev/null
"

#===============================================================================
# PHASE 7: Error Handling Tests
#===============================================================================

echo
echo "========================================"
echo "  Phase 7: Error Handling Tests"
echo "========================================"
echo

run_test_expect_fail "core_load fails for unknown module" bash -c "
    source '${LIB_DIR}/core.sh'
    core_load nonexistent_module
"

run_test_expect_fail "core_require fails for unknown module" bash -c "
    source '${LIB_DIR}/core.sh'
    core_require nonexistent_module
"

run_test_expect_fail "core_load empty name fails" bash -c "
    source '${LIB_DIR}/core.sh'
    core_load ''
"

#===============================================================================
# PHASE 8: Integration Tests
#===============================================================================

echo
echo "========================================"
echo "  Phase 8: Integration Tests"
echo "========================================"
echo

run_test "All core modules can be loaded together" bash -c "
    source '${LIB_DIR}/core.sh'
    core_require runtime config queue report
    core_load oracle
    type -t need_cmd >/dev/null && \
    type -t config_load >/dev/null && \
    type -t queue_init >/dev/null && \
    type -t report_init >/dev/null && \
    type -t oracle_core_validate_home >/dev/null
"

run_test "Modules can be loaded in any order" bash -c "
    source '${LIB_DIR}/core.sh'
    core_load report
    core_load config
    core_load queue
    type -t config_load >/dev/null && \
    type -t queue_init >/dev/null && \
    type -t report_init >/dev/null
"

run_test "Direct module loading still works (backward compat)" bash -c "
    source '${LIB_DIR}/runtime.sh'
    source '${LIB_DIR}/config.sh'
    type -t need_cmd >/dev/null && \
    type -t config_load >/dev/null && \
    [[ -n \"\${__RUNTIME_LOADED:-}\" ]] && \
    [[ -n \"\${__CONFIG_LOADED:-}\" ]]
"

#===============================================================================
# PHASE 9: Circular Dependency Detection
#===============================================================================

echo
echo "========================================"
echo "  Phase 9: Circular Dependency Detection"
echo "========================================"
echo

run_test "No circular dependencies in module graph" bash -c "
    source '${LIB_DIR}/core.sh'
    # Load all modules - should not hang or error
    core_require runtime config queue report
    core_load oracle oracle_sql oracle_datapump oracle_oci oracle_rman
    echo 'All modules loaded successfully'
"

run_test "config.sh does not load core.sh" bash -c "
    # config.sh should load runtime.sh, not core.sh
    source '${LIB_DIR}/config.sh'
    [[ -z \"\${__CORE_LOADED:-}\" ]] && [[ -n \"\${__RUNTIME_LOADED:-}\" ]]
"

run_test "queue.sh does not load core.sh" bash -c "
    # queue.sh should load runtime.sh, not core.sh
    source '${LIB_DIR}/queue.sh'
    [[ -z \"\${__CORE_LOADED:-}\" ]] && [[ -n \"\${__RUNTIME_LOADED:-}\" ]]
"

#===============================================================================
# PHASE 10: core_setup_all Tests
#===============================================================================

echo
echo "========================================"
echo "  Phase 10: core_setup_all Tests"
echo "========================================"
echo

run_test "core_setup_all loads required modules" bash -c "
    source '${LIB_DIR}/core.sh'
    TMPDIR=\$(mktemp -d)
    core_setup_all --logdir \"\${TMPDIR}\" --logbase test --queue-max 4
    type -t runtime_init_logs >/dev/null && \
    type -t queue_init >/dev/null && \
    [[ -n \"\${__CONFIG_LOADED:-}\" ]] && \
    [[ -n \"\${__QUEUE_LOADED:-}\" ]]
    rm -rf \"\${TMPDIR}\"
"

run_test "core_setup_all with --no-queue-init skips queue" bash -c "
    source '${LIB_DIR}/core.sh'
    TMPDIR=\$(mktemp -d)
    core_setup_all --logdir \"\${TMPDIR}\" --logbase test --no-queue-init
    # Queue should not be initialized, but config might be loaded for session
    rm -rf \"\${TMPDIR}\"
"

#===============================================================================
# SUMMARY
#===============================================================================

echo
echo "========================================"
echo "  TEST SUMMARY"
echo "========================================"
echo
echo "Total Tests: ${TEST_COUNT}"
echo "Passed: ${PASS_COUNT}"
echo "Failed: ${FAIL_COUNT}"

if [[ ${FAIL_COUNT} -gt 0 ]]; then
    echo
    echo "Failed tests:"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - ${test}"
    done
    echo
    exit 1
else
    echo
    echo "✅ All tests passed!"
    exit 0
fi
