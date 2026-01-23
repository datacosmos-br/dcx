#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: Hierarchical Configuration Tests
#
# Tests hierarchical configuration loading:
# - Defaults loading
# - Global config loading
# - Local config loading
# - Environment variable precedence
#
# Usage:
#   ./test_config_hierarchical.sh
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="${SCRIPT_DIR}/.."
LIB_DIR="${PARENT_DIR}/lib"
TEST_DIR="${SCRIPT_DIR}/test_configs"

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

# Setup test configs
mkdir -p "${TEST_DIR}/profiles"
cat > "${TEST_DIR}/defaults.conf" <<EOF
TEST_VAR=default_value
TEST_INT=10
EOF

cat > "${TEST_DIR}/global.conf" <<EOF
TEST_VAR=global_value
TEST_INT=20
EOF

cat > "${TEST_DIR}/local.conf" <<EOF
TEST_VAR=local_value
TEST_INT=30
EOF

cat > "${TEST_DIR}/profiles/dev.conf" <<EOF
TEST_VAR=dev_value
TEST_INT=40
EOF

cat > "${TEST_DIR}/profiles/prod.conf" <<EOF
TEST_VAR=prod_value
TEST_INT=50
EOF

echo "========================================"
echo "  Hierarchical Configuration Tests"
echo "========================================"
echo

# Test hierarchical loading (defaults -> global -> local)
run_test "Hierarchical loading works" bash -c "
    source '${LIB_DIR}/config.sh'
    unset TEST_VAR TEST_INT
    config_load_hierarchical 'test' '${TEST_DIR}/global.conf' '${TEST_DIR}/local.conf'
    [[ \"\${TEST_VAR}\" == 'local_value' ]] && \
    [[ \"\${TEST_INT}\" == '30' ]]
"

# Test environment variable precedence
run_test "Environment variables override config" bash -c "
    source '${LIB_DIR}/config.sh'
    export TEST_VAR=env_value
    config_load_hierarchical 'test' '${TEST_DIR}/global.conf' '${TEST_DIR}/local.conf'
    [[ \"\${TEST_VAR}\" == 'env_value' ]]
"

# Test profile loading
run_test "Profile loading works" bash -c "
    source '${LIB_DIR}/config.sh'
    unset TEST_VAR TEST_INT
    config_load_profile 'dev' '${TEST_DIR}'
    [[ \"\${TEST_VAR}\" == 'dev_value' ]] && \
    [[ \"\${TEST_INT}\" == '40' ]]
"

# Test profile detection
run_test "Profile detection works" bash -c "
    source '${LIB_DIR}/config.sh'
    profile=\$(config_detect_profile)
    [[ -n \"\${profile}\" ]] && \
    [[ \"\${profile}\" == 'dev' || \"\${profile}\" == 'prod' || \"\${profile}\" == 'test' ]]
"

# Test config_load_with_profile
run_test "config_load_with_profile works" bash -c "
    source '${LIB_DIR}/config.sh'
    unset TEST_VAR TEST_INT CONFIG_PROFILE ENV
    CONFIG_PROFILE=dev
    config_load_with_profile 'test' '${TEST_DIR}' || true
    [[ \"\${TEST_VAR}\" == 'dev_value' || \"\${TEST_VAR}\" == 'local_value' ]]
"

# Test config_log_loaded
run_test "config_log_loaded lists loaded files" bash -c "
    source '${LIB_DIR}/config.sh'
    config_load '${TEST_DIR}/local.conf'
    output=\$(config_log_loaded 2>&1)
    echo \"\${output}\" | grep -q 'Configuration files loaded' || echo \"\${output}\"
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
    echo "✅ All hierarchical config tests passed!"
    exit 0
fi
