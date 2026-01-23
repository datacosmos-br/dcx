#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: Integration Tests
#
# Tests real-world usage scenarios:
# - Script loading patterns
# - Module interaction
# - Function availability across modules
# - Error handling in production scenarios
#
# Usage:
#   ./test_integration.sh
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="${SCRIPT_DIR}/.."
LIB_DIR="${PARENT_DIR}/lib"

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

echo "========================================"
echo "  Integration Tests"
echo "========================================"
echo

# Test restore.sh loading pattern
run_test "restore.sh loading pattern works" bash -c "
    source '${LIB_DIR}/core.sh'
    core_require runtime config
    source '${LIB_DIR}/oracle.sh'
    type -t need_cmd >/dev/null && \
    type -t config_load >/dev/null && \
    type -t oracle_core_validate_home >/dev/null
"

# Test migrate_v2.sh loading pattern
run_test "migrate_v2.sh loading pattern works" bash -c "
    source '${LIB_DIR}/core.sh'
    core_require runtime config queue report
    core_load oracle
    type -t need_cmd >/dev/null && \
    type -t config_load >/dev/null && \
    type -t queue_init >/dev/null && \
    type -t report_init >/dev/null && \
    type -t oracle_core_validate_home >/dev/null
"

# Test that functions from different modules coexist
run_test "Functions from different modules coexist" bash -c "
    source '${LIB_DIR}/core.sh'
    core_require runtime config queue report oracle oracle_datapump
    # Test functions from each module
    type -t need_cmd >/dev/null && \
    type -t rt_assert_nonempty >/dev/null && \
    type -t config_load >/dev/null && \
    type -t queue_init >/dev/null && \
    type -t report_init >/dev/null && \
    type -t oracle_core_validate_home >/dev/null && \
    type -t oracle_sql_execute_file >/dev/null && \
    type -t dp_discover_commands >/dev/null
"

# Test that loading order doesn't matter
run_test "Module loading order doesn't matter" bash -c "
    source '${LIB_DIR}/core.sh'
    # Load in different order
    core_load report
    core_load config
    core_load queue
    core_load runtime
    type -t config_load >/dev/null && \
    type -t queue_init >/dev/null && \
    type -t report_init >/dev/null && \
    type -t need_cmd >/dev/null
"

# Test that core_setup_all initializes correctly
run_test "core_setup_all initializes subsystems" bash -c "
    source '${LIB_DIR}/core.sh'
    TMPDIR=\$(mktemp -d)
    core_setup_all --logdir \"\${TMPDIR}\" --logbase test --queue-max 4 --enable-err-trap
    # Check that modules are loaded
    [[ -n \"\${__CONFIG_LOADED:-}\" ]] && \
    [[ -n \"\${__QUEUE_LOADED:-}\" ]] && \
    [[ -n \"\${__RUNTIME_LOADED:-}\" ]]
    rm -rf \"\${TMPDIR}\"
"

# Test that variables are properly exported
run_test "Module variables are properly exported" bash -c "
    source '${LIB_DIR}/core.sh'
    core_require runtime config
    # Check that loaded flags are set
    [[ -n \"\${__CORE_LOADED:-}\" ]] && \
    [[ -n \"\${__LOGGING_LOADED:-}\" ]] && \
    [[ -n \"\${__RUNTIME_LOADED:-}\" ]] && \
    [[ -n \"\${__CONFIG_LOADED:-}\" ]]
"

# Test backward compatibility - direct loading still works
run_test "Direct module loading still works (backward compat)" bash -c "
    source '${LIB_DIR}/logging.sh'
    source '${LIB_DIR}/runtime.sh'
    source '${LIB_DIR}/config.sh'
    type -t log >/dev/null && \
    type -t need_cmd >/dev/null && \
    type -t config_load >/dev/null
"

# Test that core_check_dependencies works
run_test "core_check_dependencies validates dependencies" bash -c "
    source '${LIB_DIR}/core.sh'
    core_check_dependencies
"

# Test that core_validate_module_graph works
run_test "core_validate_module_graph detects no cycles" bash -c "
    source '${LIB_DIR}/core.sh'
    core_validate_module_graph
"

# Test that core_get_loaded_modules works
run_test "core_get_loaded_modules lists loaded modules" bash -c "
    source '${LIB_DIR}/core.sh'
    core_require runtime config
    loaded=\$(core_get_loaded_modules)
    echo \"\${loaded}\" | grep -q runtime && \
    echo \"\${loaded}\" | grep -q config
"

echo
echo "========================================"
echo "  SUMMARY"
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
    exit 1
else
    echo
    echo "✅ All integration tests passed!"
    exit 0
fi
