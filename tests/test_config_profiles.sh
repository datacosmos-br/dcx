#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: Configuration Profiles Tests
#
# Tests profile-based configuration:
# - Profile detection
# - Profile loading
# - Profile-specific overrides
#
# Usage:
#   ./test_config_profiles.sh
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="${SCRIPT_DIR}/.."
LIB_DIR="${PARENT_DIR}/lib"
TEST_DIR="${SCRIPT_DIR}/test_profiles"

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

# Setup test profiles
mkdir -p "${TEST_DIR}/profiles"
cat > "${TEST_DIR}/app.conf" <<EOF
BASE_VAR=base_value
EOF

cat > "${TEST_DIR}/profiles/dev.conf" <<EOF
BASE_VAR=dev_value
DEV_SPECIFIC=dev_setting
EOF

cat > "${TEST_DIR}/profiles/prod.conf" <<EOF
BASE_VAR=prod_value
PROD_SPECIFIC=prod_setting
EOF

cat > "${TEST_DIR}/profiles/test.conf" <<EOF
BASE_VAR=test_value
TEST_SPECIFIC=test_setting
EOF

echo "========================================"
echo "  Configuration Profiles Tests"
echo "========================================"
echo

# Test profile loading
run_test "Profile loading loads correct file" bash -c "
    source '${LIB_DIR}/config.sh'
    unset BASE_VAR DEV_SPECIFIC
    config_load_profile 'dev' '${TEST_DIR}'
    [[ \"\${BASE_VAR}\" == 'dev_value' ]] && \
    [[ \"\${DEV_SPECIFIC}\" == 'dev_setting' ]]
"

# Test profile detection from CONFIG_PROFILE
run_test "Profile detection from CONFIG_PROFILE" bash -c "
    source '${LIB_DIR}/config.sh'
    export CONFIG_PROFILE=prod
    profile=\$(config_detect_profile)
    [[ \"\${profile}\" == 'prod' ]]
"

# Test profile detection from ENV
run_test "Profile detection from ENV" bash -c "
    source '${LIB_DIR}/config.sh'
    unset CONFIG_PROFILE
    export ENV=test
    profile=\$(config_detect_profile)
    [[ \"\${profile}\" == 'test' ]]
"

# Test profile detection default
run_test "Profile detection defaults to prod" bash -c "
    source '${LIB_DIR}/config.sh'
    unset CONFIG_PROFILE ENV
    profile=\$(config_detect_profile)
    [[ \"\${profile}\" == 'prod' ]]
"

# Test config_load_with_profile
run_test "config_load_with_profile loads base and profile" bash -c "
    source '${LIB_DIR}/config.sh'
    unset BASE_VAR DEV_SPECIFIC
    CONFIG_PROFILE=dev
    config_load_with_profile 'app' '${TEST_DIR}' || true
    [[ \"\${BASE_VAR}\" == 'dev_value' ]] && \
    [[ \"\${DEV_SPECIFIC}\" == 'dev_setting' ]]
"

# Test profile override order
run_test "Profile overrides base config" bash -c "
    source '${LIB_DIR}/config.sh'
    unset BASE_VAR
    config_load '${TEST_DIR}/app.conf'
    config_load_profile 'prod' '${TEST_DIR}'
    [[ \"\${BASE_VAR}\" == 'prod_value' ]]
"

# Cleanup
rm -rf "${TEST_DIR}"

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
    echo "✅ All profile tests passed!"
    exit 0
fi
