#!/usr/bin/env bash
#===============================================================================
# test_config.sh - Tests for lib/config.sh
#===============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
TMP_DIR="${SCRIPT_DIR}/tmp"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

#-------------------------------------------------------------------------------
# Test helpers
#-------------------------------------------------------------------------------
test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ✓ $1"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ✗ $1"
}

run_test() {
    local name="$1"
    local cmd="$2"
    TESTS_RUN=$((TESTS_RUN + 1))

    if eval "$cmd" &>/dev/null; then
        test_pass "$name"
    else
        test_fail "$name"
    fi
}

#-------------------------------------------------------------------------------
# Setup
#-------------------------------------------------------------------------------
setup() {
    mkdir -p "$TMP_DIR"

    # Create test config file
    cat > "${TMP_DIR}/test.yaml" << 'EOF'
database:
  host: localhost
  port: 5432
  name: testdb
app:
  name: myapp
  debug: true
EOF

    # Create overlay config
    cat > "${TMP_DIR}/overlay.yaml" << 'EOF'
database:
  host: production.db
  port: 5433
app:
  debug: false
EOF
}

#-------------------------------------------------------------------------------
# Teardown
#-------------------------------------------------------------------------------
teardown() {
    rm -rf "$TMP_DIR"
}

#-------------------------------------------------------------------------------
# Tests
#-------------------------------------------------------------------------------
echo "Testing config.sh..."
echo ""

# Setup
setup

# Source modules
source "${LIB_DIR}/core.sh"
source "${LIB_DIR}/config.sh"

# Test: Module loads without error
run_test "config.sh loads" "true"

# Test: _DC_CONFIG_LOADED is set
run_test "_DC_CONFIG_LOADED set" "[[ -n \"\${_DC_CONFIG_LOADED:-}\" ]]"

# Test: config_get function exists
run_test "config_get exists" "type config_get &>/dev/null"

# Test: config_set function exists
run_test "config_set exists" "type config_set &>/dev/null"

# Test: config_has function exists
run_test "config_has exists" "type config_has &>/dev/null"

# Test: config_keys function exists
run_test "config_keys exists" "type config_keys &>/dev/null"

# Test: config_get returns correct value
result=$(config_get "${TMP_DIR}/test.yaml" "database.host")
run_test "config_get value" "[[ \"$result\" == \"localhost\" ]]"

# Test: config_get returns default for missing key
result=$(config_get "${TMP_DIR}/test.yaml" "missing.key" "default_value")
run_test "config_get default" "[[ \"$result\" == \"default_value\" ]]"

# Test: config_get nested value
result=$(config_get "${TMP_DIR}/test.yaml" "database.port")
run_test "config_get nested" "[[ \"$result\" == \"5432\" ]]"

# Test: config_has returns 0 for existing key
run_test "config_has existing" "config_has \"${TMP_DIR}/test.yaml\" \"database.host\""

# Test: config_has returns 1 for missing key
run_test "config_has missing" "! config_has \"${TMP_DIR}/test.yaml\" \"missing.key\""

# Test: config_set creates new key
config_set "${TMP_DIR}/test.yaml" "new.key" "new_value"
result=$(config_get "${TMP_DIR}/test.yaml" "new.key")
run_test "config_set new key" "[[ \"$result\" == \"new_value\" ]]"

# Test: config_set updates existing key
config_set "${TMP_DIR}/test.yaml" "database.host" "newhost"
result=$(config_get "${TMP_DIR}/test.yaml" "database.host")
run_test "config_set update" "[[ \"$result\" == \"newhost\" ]]"

# Test: config_keys returns keys
keys=$(config_keys "${TMP_DIR}/test.yaml" "database")
run_test "config_keys" "[[ \"$keys\" == *\"host\"* ]]"

# Test: config_validate success
run_test "config_validate success" "config_validate \"${TMP_DIR}/test.yaml\" \"database.port\" \"app.name\""

# Test: config_validate failure
run_test "config_validate failure" "! config_validate \"${TMP_DIR}/test.yaml\" \"missing.key\""

# Test: config_merge combines files
merged=$(config_merge "${TMP_DIR}/test.yaml" "${TMP_DIR}/overlay.yaml")
run_test "config_merge works" "[[ \"$merged\" == *\"production.db\"* ]]"

# Test: config_get for missing file returns default
result=$(config_get "/nonexistent/file.yaml" "key" "fallback" || true)
run_test "config_get missing file" "[[ \"$result\" == \"fallback\" ]]"

# Test: config_to_env exports variables
config_to_env "${TMP_DIR}/test.yaml" "TEST_"
run_test "config_to_env" "[[ -n \"\${TEST_APP_NAME:-}\" ]]"

# Teardown
teardown

#-------------------------------------------------------------------------------
# Summary
#-------------------------------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Tests: ${TESTS_RUN} | Passed: ${TESTS_PASSED} | Failed: ${TESTS_FAILED}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed."
    exit 1
fi
