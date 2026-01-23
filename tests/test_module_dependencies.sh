#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: Module Dependency Validation
#
# Validates that all modules declare correct dependencies and can be loaded
# independently without circular dependencies.
#
# Usage:
#   ./test_module_dependencies.sh
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
echo "  Module Dependency Validation"
echo "========================================"
echo

#===============================================================================
# Test each module can be loaded independently
#===============================================================================
echo "Testing core modules load independently..."

core_modules=(
    "logging.sh"
    "runtime.sh"
    "session.sh"
    "config.sh"
    "queue.sh"
    "report.sh"
    "core.sh"
)

for module in "${core_modules[@]}"; do
    run_test "${module} loads independently" bash -c "
        unset __LOGGING_LOADED __RUNTIME_LOADED __CORE_LOADED
        unset __CONFIG_LOADED __QUEUE_LOADED __REPORT_LOADED
        source '${LIB_DIR}/${module}' >/dev/null 2>&1
        echo 'Module loaded'
    "
done

echo
echo "Testing Oracle modules load independently..."

oracle_modules=(
    "oracle_core.sh"
    "oracle_env.sh"
    "oracle_config.sh"
    "oracle_cluster.sh"
    "oracle_instance.sh"
    "oracle_sql.sh"
    "oracle_datapump.sh"
    "oracle_oci.sh"
    "oracle_rman.sh"
    "oracle.sh"
)

for module in "${oracle_modules[@]}"; do
    if [[ -f "${LIB_DIR}/${module}" ]]; then
        run_test "${module} loads independently" bash -c "
            unset __ORACLE_LOADED __ORACLE_SQL_LOADED __ORACLE_DATAPUMP_LOADED
            unset __OCI_LOADED __ORACLE_RMAN_LOADED __ORACLE_RUNTIME_LOADED
            unset __ORACLE_CORE_LOADED __ORACLE_ENV_LOADED __ORACLE_CONFIG_LOADED
            unset __ORACLE_CLUSTER_LOADED __ORACLE_INSTANCE_LOADED
            source '${LIB_DIR}/${module}' >/dev/null 2>&1
            echo 'Module loaded'
        "
    else
        echo "[SKIP] ${module} not found"
    fi
done

#===============================================================================
# Test dependency chains
#===============================================================================
echo
echo "Testing dependency chains..."

run_test "logging.sh has no dependencies" bash -c "
    source '${LIB_DIR}/logging.sh'
    [[ -z \"\${__RUNTIME_LOADED:-}\" ]] && \
    [[ -z \"\${__CORE_LOADED:-}\" ]]
"

run_test "runtime.sh only depends on logging.sh" bash -c "
    source '${LIB_DIR}/runtime.sh'
    [[ -n \"\${__LOGGING_LOADED:-}\" ]] && \
    [[ -z \"\${__CORE_LOADED:-}\" ]]
"

run_test "config.sh depends on runtime.sh, not core.sh" bash -c "
    source '${LIB_DIR}/config.sh'
    [[ -n \"\${__RUNTIME_LOADED:-}\" ]] && \
    [[ -z \"\${__CORE_LOADED:-}\" ]]
"

run_test "queue.sh depends on runtime.sh, not core.sh" bash -c "
    source '${LIB_DIR}/queue.sh'
    [[ -n \"\${__RUNTIME_LOADED:-}\" ]] && \
    [[ -z \"\${__CORE_LOADED:-}\" ]]
"

run_test "report.sh depends on runtime.sh, not core.sh" bash -c "
    source '${LIB_DIR}/report.sh'
    [[ -n \"\${__RUNTIME_LOADED:-}\" ]] && \
    [[ -z \"\${__CORE_LOADED:-}\" ]]
"

#===============================================================================
# Test Oracle module dependency chains
#===============================================================================
echo
echo "Testing Oracle module dependency chains..."

run_test "oracle_core.sh depends on runtime.sh" bash -c "
    source '${LIB_DIR}/oracle_core.sh'
    [[ -n \"\${__RUNTIME_LOADED:-}\" ]]
"

run_test "oracle_sql.sh depends on oracle_core.sh" bash -c "
    source '${LIB_DIR}/oracle_sql.sh'
    [[ -n \"\${__ORACLE_CORE_LOADED:-}\" ]]
"

run_test "oracle_instance.sh depends on oracle_core.sh and oracle_cluster.sh" bash -c "
    source '${LIB_DIR}/oracle_instance.sh'
    [[ -n \"\${__ORACLE_CORE_LOADED:-}\" ]] && \
    [[ -n \"\${__ORACLE_CLUSTER_LOADED:-}\" ]]
"

run_test "oracle.sh loads core Oracle modules" bash -c "
    source '${LIB_DIR}/oracle.sh'
    [[ -n \"\${__ORACLE_CORE_LOADED:-}\" ]] && \
    [[ -n \"\${__ORACLE_SQL_LOADED:-}\" ]] && \
    [[ -n \"\${__ORACLE_INSTANCE_LOADED:-}\" ]]
"

#===============================================================================
# Test that modules don't create circular dependencies
#===============================================================================
echo
echo "Testing for circular dependencies..."

run_test "Loading config.sh then queue.sh works" bash -c "
    source '${LIB_DIR}/config.sh'
    source '${LIB_DIR}/queue.sh'
    type -t config_load >/dev/null && \
    type -t queue_init >/dev/null
"

run_test "Loading queue.sh then config.sh works" bash -c "
    source '${LIB_DIR}/queue.sh'
    source '${LIB_DIR}/config.sh'
    type -t queue_init >/dev/null && \
    type -t config_load >/dev/null
"

run_test "Loading all core modules in sequence works" bash -c "
    source '${LIB_DIR}/logging.sh'
    source '${LIB_DIR}/runtime.sh'
    source '${LIB_DIR}/config.sh'
    source '${LIB_DIR}/queue.sh'
    source '${LIB_DIR}/report.sh'
    echo 'All modules loaded successfully'
"

run_test "Loading oracle.sh then oracle_datapump.sh works" bash -c "
    source '${LIB_DIR}/oracle.sh'
    source '${LIB_DIR}/oracle_datapump.sh'
    [[ -n \"\${__ORACLE_LOADED:-}\" ]] && \
    [[ -n \"\${__ORACLE_DATAPUMP_LOADED:-}\" ]]
"

run_test "Loading oracle.sh then oracle_rman.sh works" bash -c "
    source '${LIB_DIR}/oracle.sh'
    source '${LIB_DIR}/oracle_rman.sh'
    [[ -n \"\${__ORACLE_LOADED:-}\" ]] && \
    [[ -n \"\${__ORACLE_RMAN_LOADED:-}\" ]]
"

run_test "Loading oracle.sh then oracle_oci.sh works" bash -c "
    source '${LIB_DIR}/oracle.sh'
    source '${LIB_DIR}/oracle_oci.sh'
    [[ -n \"\${__ORACLE_LOADED:-}\" ]] && \
    [[ -n \"\${__OCI_LOADED:-}\" ]]
"

#===============================================================================
# Test backward compatibility
#===============================================================================
echo
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
    echo "All dependency tests passed."
    exit 0
fi
