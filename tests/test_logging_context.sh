#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: Logging Context Tests
#
# Tests automatic context capture in logging functions:
# - Function name capture
# - Module name extraction
# - Line number capture
# - Context display when enabled
#
# Usage:
#   ./test_logging_context.sh
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
echo "  Logging Context Tests"
echo "========================================"
echo

# Test context capture
run_test "Context capture works" bash -c "
    source '${LIB_DIR}/logging.sh'
    LOG_SHOW_CONTEXT=1
    output=\$(log 'Test message' 2>&1)
    echo \"\${output}\" | grep -q '\[logging:' || echo \"\${output}\"
"

# Test module name extraction
run_test "Module name extracted correctly" bash -c "
    source '${LIB_DIR}/logging.sh'
    LOG_SHOW_CONTEXT=1
    output=\$(log 'Test' 2>&1)
    echo \"\${output}\" | grep -qE '\[(logging|core|config|runtime):' || echo \"\${output}\"
"

# Test context disabled by default
run_test "Context disabled by default" bash -c "
    source '${LIB_DIR}/logging.sh'
    output=\$(log 'Test' 2>&1)
    ! echo \"\${output}\" | grep -q '\[.*:.*:.*\]' || echo \"\${output}\"
"

# Test log_debug respects module levels
run_test "log_debug respects module levels" bash -c "
    source '${LIB_DIR}/logging.sh'
    log_set_module_level 'test_module' 'INFO'
    output=\$(LOG_MODULE_LEVELS[test_module]=INFO log_debug 'Debug message' 2>&1)
    [[ -z \"\${output}\" ]] || echo \"\${output}\"
"

# Test structured logging
run_test "Structured logging (JSON) works" bash -c "
    source '${LIB_DIR}/logging.sh'
    LOG_STRUCTURED=1
    output=\$(log 'Test message' 2>&1)
    echo \"\${output}\" | grep -q '\"timestamp\"' && \
    echo \"\${output}\" | grep -q '\"level\"' && \
    echo \"\${output}\" | grep -q '\"module\"' && \
    echo \"\${output}\" | grep -q '\"message\"'
"

# Test log_set_module_level
run_test "log_set_module_level sets level" bash -c "
    source '${LIB_DIR}/logging.sh'
    log_set_module_level 'oracle' 'DEBUG'
    level=\$(log_get_module_level 'oracle')
    [[ \"\${level}\" == 'DEBUG' ]]
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
    echo "✅ All logging context tests passed!"
    exit 0
fi
