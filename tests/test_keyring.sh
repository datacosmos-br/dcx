#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: keyring.sh Unit Tests
#
# Validates keyring management functions for secure credential storage.
# Tests encryption, environment management, and credential fallback chain.
#
# Usage:
#   ./test_keyring.sh
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load dependencies
source "${SCRIPT_DIR}/../lib/logging.sh"
source "${SCRIPT_DIR}/../lib/runtime.sh"
source "${SCRIPT_DIR}/../lib/keyring.sh"

#===============================================================================
# TEST FRAMEWORK
#===============================================================================

TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Test temp directory
TEST_TMPDIR=""

setup_test_env() {
    TEST_TMPDIR=$(mktemp -d)
    export KEYRING_FILE="${TEST_TMPDIR}/test_keyring.enc"
    export WALLET_BASE="${TEST_TMPDIR}/wallets"
    # Reset keyring state (use correct variable names from keyring.sh)
    _KEYRING_DATA=""
    _KEYRING_MASTER_KEY=""
    _KEYRING_OPEN=0
}

cleanup_test_env() {
    [[ -n "${TEST_TMPDIR}" ]] && rm -rf "${TEST_TMPDIR}"
}

run_test() {
    local name="$1"
    shift
    TEST_COUNT=$((TEST_COUNT + 1))

    setup_test_env

    # Run in subshell to isolate state
    if ("$@") 2>/dev/null; then
        echo "[PASS] ${name}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "[FAIL] ${name}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    cleanup_test_env
}

run_test_expect_fail() {
    local name="$1"
    shift
    TEST_COUNT=$((TEST_COUNT + 1))

    setup_test_env

    # Run in subshell (expected to fail)
    if ! ("$@") 2>/dev/null; then
        echo "[PASS] ${name} (expected failure)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "[FAIL] ${name} (should have failed)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    cleanup_test_env
}

#===============================================================================
# TEST: Keyring Initialization
#===============================================================================

echo
echo "=== Testing Keyring Initialization ==="

test_keyring_init_creates_file() {
    local tmpdir
    tmpdir=$(mktemp -d)
    export KEYRING_FILE="${tmpdir}/test.enc"
    _KEYRING_DATA=""
    _KEYRING_MASTER_KEY=""
    _KEYRING_OPEN=0

    # Simulate init with known password (keyring must be "open" to save)
    _KEYRING_MASTER_KEY=$(echo -n "testpassword123" | openssl dgst -sha256 -binary | base64)
    local salt
    salt=$(openssl rand -hex 16)

    _KEYRING_DATA=$(jq -n \
        --arg version "1.0" \
        --arg created "$(date -Iseconds)" \
        --arg salt "${salt}" \
        '{version: $version, created: $created, salt: $salt, environments: {}}')

    # Must be open to save
    _KEYRING_OPEN=1
    keyring_save

    [[ -f "${KEYRING_FILE}" ]]
    local result=$?

    rm -rf "${tmpdir}"
    return ${result}
}

run_test "keyring_init creates encrypted file" test_keyring_init_creates_file

test_keyring_file_permissions() {
    local tmpdir
    tmpdir=$(mktemp -d)
    export KEYRING_FILE="${tmpdir}/test.enc"
    _KEYRING_DATA=""
    _KEYRING_MASTER_KEY=""
    _KEYRING_OPEN=0

    _KEYRING_MASTER_KEY=$(echo -n "testpassword123" | openssl dgst -sha256 -binary | base64)
    local salt
    salt=$(openssl rand -hex 16)

    _KEYRING_DATA=$(jq -n \
        --arg version "1.0" \
        --arg created "$(date -Iseconds)" \
        --arg salt "${salt}" \
        '{version: $version, created: $created, salt: $salt, environments: {}}')

    _KEYRING_OPEN=1
    keyring_save

    local perms
    perms=$(stat -c%a "${KEYRING_FILE}" 2>/dev/null || stat -f%OLp "${KEYRING_FILE}")
    [[ "${perms}" == "600" ]]
    local result=$?

    rm -rf "${tmpdir}"
    return ${result}
}

run_test "keyring file has 600 permissions" test_keyring_file_permissions

#===============================================================================
# TEST: Keyring State Management
#===============================================================================

echo
echo "=== Testing Keyring State ==="

test_keyring_is_open_false_initially() {
    _KEYRING_OPEN=0
    ! keyring_is_open
}

run_test "keyring_is_open returns false initially" test_keyring_is_open_false_initially

test_keyring_is_open_true_after_open() {
    _KEYRING_OPEN=1
    keyring_is_open
}

run_test "keyring_is_open returns true when open" test_keyring_is_open_true_after_open

test_keyring_close_clears_state() {
    _KEYRING_OPEN=1
    _KEYRING_MASTER_KEY="somekey"
    _KEYRING_DATA="somedata"

    keyring_close

    [[ ${_KEYRING_OPEN} -eq 0 ]] && [[ -z "${_KEYRING_MASTER_KEY}" ]] && [[ -z "${_KEYRING_DATA}" ]]
}

run_test "keyring_close clears state" test_keyring_close_clears_state

#===============================================================================
# TEST: Environment Management
#===============================================================================

echo
echo "=== Testing Environment Management ==="

test_keyring_env_set_and_get() {
    _KEYRING_OPEN=1
    _KEYRING_MASTER_KEY=$(echo -n "testpassword123" | openssl dgst -sha256 -binary | base64)
    _KEYRING_DATA='{"version":"1.0","salt":"abc123","environments":{}}'

    keyring_env_set "TEST" "user" "testuser"
    keyring_env_set "TEST" "tns" "testtns"

    local user
    user=$(keyring_env_get "TEST" "user")
    local tns
    tns=$(keyring_env_get "TEST" "tns")

    [[ "${user}" == "testuser" ]] && [[ "${tns}" == "testtns" ]]
}

run_test "keyring_env_set and get work" test_keyring_env_set_and_get

test_keyring_env_list() {
    _KEYRING_OPEN=1
    _KEYRING_MASTER_KEY=$(echo -n "testpassword123" | openssl dgst -sha256 -binary | base64)
    _KEYRING_DATA='{"version":"1.0","salt":"abc123","environments":{"ENV1":{"user":"u1"},"ENV2":{"user":"u2"}}}'

    local envs
    envs=$(keyring_env_list)

    echo "${envs}" | grep -q "ENV1" && echo "${envs}" | grep -q "ENV2"
}

run_test "keyring_env_list returns environments" test_keyring_env_list

test_keyring_env_remove() {
    _KEYRING_OPEN=1
    _KEYRING_MASTER_KEY=$(echo -n "testpassword123" | openssl dgst -sha256 -binary | base64)
    _KEYRING_DATA='{"version":"1.0","salt":"abc123","environments":{"TOREMOVE":{"user":"u1"},"KEEP":{"user":"u2"}}}'

    keyring_env_remove "TOREMOVE"

    local envs
    envs=$(keyring_env_list)

    ! echo "${envs}" | grep -q "TOREMOVE" && echo "${envs}" | grep -q "KEEP"
}

run_test "keyring_env_remove deletes environment" test_keyring_env_remove

#===============================================================================
# TEST: Password Encryption
#===============================================================================

echo
echo "=== Testing Password Encryption ==="

test_password_encrypted_on_set() {
    _KEYRING_OPEN=1
    _KEYRING_MASTER_KEY=$(echo -n "testpassword123" | openssl dgst -sha256 -binary | base64)
    _KEYRING_DATA='{"version":"1.0","salt":"abc123","environments":{}}'

    keyring_env_set "TEST" "password" "mysecretpassword"

    # Password should NOT be stored in plaintext
    ! echo "${_KEYRING_DATA}" | grep -q "mysecretpassword"
}

run_test "password is encrypted when set" test_password_encrypted_on_set

test_password_decrypted_on_get() {
    _KEYRING_OPEN=1
    _KEYRING_MASTER_KEY=$(echo -n "testpassword123" | openssl dgst -sha256 -binary | base64)
    _KEYRING_DATA='{"version":"1.0","salt":"abc123","environments":{}}'

    keyring_env_set "TEST" "password" "mysecretpassword"

    local retrieved
    retrieved=$(keyring_env_get "TEST" "password")

    [[ "${retrieved}" == "mysecretpassword" ]]
}

run_test "password is decrypted when retrieved" test_password_decrypted_on_get

#===============================================================================
# TEST: Export Functionality
#===============================================================================

echo
echo "=== Testing Export Functionality ==="

test_keyring_env_export_sets_vars() {
    _KEYRING_OPEN=1
    _KEYRING_MASTER_KEY=$(echo -n "testpassword123" | openssl dgst -sha256 -binary | base64)
    _KEYRING_DATA='{"version":"1.0","salt":"abc123","environments":{}}'

    keyring_env_set "TEST" "user" "exportuser"
    keyring_env_set "TEST" "tns" "exporttns"
    keyring_env_set "TEST" "password" "exportpass"

    # Clear any existing vars
    unset DB_ADMIN_USER DB_ADMIN_PASSWORD DB_CONNECTION_STRING

    # In non-terminal mode, keyring_env_export outputs export statements
    # We need to eval them to set the variables
    eval "$(keyring_env_export "TEST")"

    [[ "${DB_ADMIN_USER}" == "exportuser" ]] && \
    [[ "${DB_ADMIN_PASSWORD}" == "exportpass" ]] && \
    [[ "${DB_CONNECTION_STRING}" == "exporttns" ]]
}

run_test "keyring_env_export sets environment variables" test_keyring_env_export_sets_vars

#===============================================================================
# TEST: Secure Prompts
#===============================================================================

echo
echo "=== Testing Secure Prompts ==="

test_keyring_prompt_value_uses_default() {
    # keyring_prompt_value sets a variable, not returns a value
    # Simulate empty input by redirecting from /dev/null
    TEST_VAR=""
    keyring_prompt_value "TEST_VAR" "Test prompt" "default_value" < /dev/null 2>/dev/null

    [[ "${TEST_VAR}" == "default_value" ]]
}

run_test "keyring_prompt_value uses default on empty input" test_keyring_prompt_value_uses_default

#===============================================================================
# TEST: Validation
#===============================================================================

echo
echo "=== Testing Validation ==="

test_keyring_env_get_fails_when_closed() {
    _KEYRING_OPEN=0

    ! keyring_env_get "TEST" "user" 2>/dev/null
}

run_test_expect_fail "keyring_env_get fails when keyring closed" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    source "'"${SCRIPT_DIR}"'/../lib/keyring.sh"
    _KEYRING_OPEN=0
    keyring_env_get "TEST" "user"
'

test_keyring_env_set_fails_when_closed() {
    _KEYRING_OPEN=0

    ! keyring_env_set "TEST" "user" "value" 2>/dev/null
}

run_test_expect_fail "keyring_env_set fails when keyring closed" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/runtime.sh"
    source "'"${SCRIPT_DIR}"'/../lib/keyring.sh"
    _KEYRING_OPEN=0
    keyring_env_set "TEST" "user" "value"
'

#===============================================================================
# SUMMARY
#===============================================================================

echo
echo "========================================"
echo "Test Summary: ${PASS_COUNT}/${TEST_COUNT} passed"
echo "========================================"

if [[ ${FAIL_COUNT} -gt 0 ]]; then
    echo "FAILED: ${FAIL_COUNT} tests"
    exit 1
fi

echo "All tests passed!"
exit 0
