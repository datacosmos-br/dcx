#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: Configuration Validation Tests
#
# Tests configuration schema validation:
# - Type validation (string, int, uint, bool, enum)
# - Required field validation
# - Default value application
# - Allowed values validation
#
# Usage:
#   ./test_config_validation.sh
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

echo "========================================"
echo "  Configuration Validation Tests"
echo "========================================"
echo

# Test schema registration
run_test "Schema registration works" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_VAR' 'string' '0' 'default' ''
    config_print_schema | grep -q 'TEST_VAR'
"

# Test int validation
run_test "Int validation accepts valid int" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_INT' 'int' '0' '0' ''
    export TEST_INT=42
    config_validate_schema
"

run_test_expect_fail "Int validation rejects invalid int" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_INT' 'int' '0' '0' ''
    export TEST_INT=abc
    config_validate_schema
"

# Test uint validation
run_test "Uint validation accepts valid uint" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_UINT' 'uint' '0' '0' ''
    export TEST_UINT=42
    config_validate_schema
"

run_test_expect_fail "Uint validation rejects negative" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_UINT' 'uint' '0' '0' ''
    export TEST_UINT=-5
    config_validate_schema
"

# Test bool validation
run_test "Bool validation accepts 0/1" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_BOOL' 'bool' '0' '0' ''
    export TEST_BOOL=1
    config_validate_schema
    export TEST_BOOL=0
    config_validate_schema
"

run_test_expect_fail "Bool validation rejects invalid" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_BOOL' 'bool' '0' '0' ''
    export TEST_BOOL=2
    config_validate_schema
"

# Test enum validation
run_test "Enum validation accepts allowed value" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_ENUM' 'enum' '0' 'value1' 'value1 value2 value3'
    export TEST_ENUM=value2
    config_validate_schema
"

run_test_expect_fail "Enum validation rejects disallowed value" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_ENUM' 'enum' '0' 'value1' 'value1 value2 value3'
    export TEST_ENUM=value4
    config_validate_schema
"

# Test required field validation
run_test_expect_fail "Required field validation fails when missing" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_REQUIRED' 'string' '1' '' ''
    unset TEST_REQUIRED
    config_validate_schema
"

run_test "Required field validation passes when set" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_REQUIRED' 'string' '1' '' ''
    export TEST_REQUIRED=value
    config_validate_schema
"

# Test default value application
run_test "Default value applied when empty" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_DEFAULT' 'string' '0' 'default_value' ''
    unset TEST_DEFAULT
    config_validate_schema
    [[ \"\${TEST_DEFAULT}\" == 'default_value' ]]
"

# Test path validation
run_test "Path validation accepts absolute path" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_PATH' 'path' '0' '/tmp' ''
    export TEST_PATH=/usr/bin
    config_validate_schema
"

run_test_expect_fail "Path validation rejects relative path" bash -c "
    source '${LIB_DIR}/config.sh'
    config_register_schema 'TEST_PATH' 'path' '0' '/tmp' ''
    export TEST_PATH=./relative
    config_validate_schema
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
    echo "✅ All validation tests passed!"
    exit 0
fi
