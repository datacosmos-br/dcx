#!/usr/bin/env bash
#===============================================================================
# test_core.sh - Tests for lib/core.sh
#===============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

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
# Tests
#-------------------------------------------------------------------------------
echo "Testing core.sh..."
echo ""

# Source core.sh
source "${LIB_DIR}/core.sh"

# Test: Module loads without error
run_test "core.sh loads" "true"

# Test: DC_VERSION is set
run_test "DC_VERSION is set" "[[ -n \"\${DC_VERSION:-}\" ]]"

# Test: DC_VERSION is correct
run_test "DC_VERSION is 0.2.0" "[[ \"\${DC_VERSION}\" == \"0.2.0\" ]]"

# Test: dc_init function exists
run_test "dc_init exists" "type dc_init &>/dev/null"

# Test: dc_require function exists
run_test "dc_require exists" "type dc_require &>/dev/null"

# Test: dc_version function exists
run_test "dc_version exists" "type dc_version &>/dev/null"

# Test: dc_source function exists
run_test "dc_source exists" "type dc_source &>/dev/null"

# Test: dc_load function exists
run_test "dc_load exists" "type dc_load &>/dev/null"

# Test: dc_init succeeds (gum and yq should be installed)
run_test "dc_init succeeds" "dc_init"

# Test: DC_INITIALIZED is set after init
run_test "DC_INITIALIZED is set" "[[ \"\${DC_INITIALIZED:-}\" == \"1\" ]]"

# Test: dc_version outputs correct format
run_test "dc_version output" "[[ \"\$(dc_version)\" == \"dc-scripts v0.2.0\" ]]"

# Test: dc_require is idempotent
run_test "dc_require idempotent" "dc_require && dc_require"

# Test: _DC_CORE_LOADED prevents re-sourcing
run_test "_DC_CORE_LOADED set" "[[ -n \"\${_DC_CORE_LOADED:-}\" ]]"

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
