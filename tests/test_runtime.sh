#!/usr/bin/env bash
#===============================================================================
# test_runtime.sh - Tests for lib/runtime.sh
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
    echo "test content" > "${TMP_DIR}/testfile.txt"
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
echo "Testing runtime.sh..."
echo ""

# Setup
setup

# Source modules
source "${LIB_DIR}/core.sh"
source "${LIB_DIR}/runtime.sh"

# Test: Module loads without error
run_test "runtime.sh loads" "true"

# Test: _DC_RUNTIME_LOADED is set
run_test "_DC_RUNTIME_LOADED set" "[[ -n \"\${_DC_RUNTIME_LOADED:-}\" ]]"

# Test: Validator functions exist
run_test "need_cmd exists" "type need_cmd &>/dev/null"
run_test "need_cmds exists" "type need_cmds &>/dev/null"
run_test "assert_file exists" "type assert_file &>/dev/null"
run_test "assert_dir exists" "type assert_dir &>/dev/null"
run_test "assert_nonempty exists" "type assert_nonempty &>/dev/null"
run_test "assert_var exists" "type assert_var &>/dev/null"

# Test: Gum wrapper functions exist
run_test "confirm exists" "type confirm &>/dev/null"
run_test "choose exists" "type choose &>/dev/null"
run_test "choose_multi exists" "type choose_multi &>/dev/null"
run_test "input exists" "type input &>/dev/null"
run_test "input_password exists" "type input_password &>/dev/null"
run_test "input_multiline exists" "type input_multiline &>/dev/null"
run_test "spin exists" "type spin &>/dev/null"
run_test "log exists" "type log &>/dev/null"
run_test "style exists" "type style &>/dev/null"
run_test "filter exists" "type filter &>/dev/null"
run_test "file_select exists" "type file_select &>/dev/null"
run_test "table exists" "type table &>/dev/null"
run_test "format_md exists" "type format_md &>/dev/null"

# Test: Utility functions exist
run_test "retry exists" "type retry &>/dev/null"
run_test "timeout_cmd exists" "type timeout_cmd &>/dev/null"
run_test "run_silent exists" "type run_silent &>/dev/null"
run_test "run_or_die exists" "type run_or_die &>/dev/null"

# Test: need_cmd succeeds for existing command
run_test "need_cmd existing" "need_cmd bash"

# Test: need_cmd fails for missing command
run_test "need_cmd missing" "! need_cmd nonexistent_command_xyz"

# Test: need_cmds succeeds for existing commands
run_test "need_cmds existing" "need_cmds bash cat ls"

# Test: need_cmds fails if any missing
run_test "need_cmds partial" "! need_cmds bash nonexistent_xyz cat"

# Test: assert_file succeeds for existing file
run_test "assert_file existing" "assert_file \"${TMP_DIR}/testfile.txt\""

# Test: assert_file fails for missing file
run_test "assert_file missing" "! assert_file /nonexistent/file.txt"

# Test: assert_dir succeeds for existing directory
run_test "assert_dir existing" "assert_dir \"${TMP_DIR}\""

# Test: assert_dir fails for missing directory
run_test "assert_dir missing" "! assert_dir /nonexistent/dir"

# Test: assert_nonempty succeeds for non-empty value
run_test "assert_nonempty non-empty" "assert_nonempty \"hello\" \"test\""

# Test: assert_nonempty fails for empty value
run_test "assert_nonempty empty" "! assert_nonempty \"\" \"test\""

# Test: assert_var succeeds for set variable
export TEST_VAR="value"
run_test "assert_var set" "assert_var TEST_VAR"

# Test: assert_var fails for unset variable
unset UNSET_VAR 2>/dev/null || true
run_test "assert_var unset" "! assert_var UNSET_VAR"

# Test: run_silent executes command
run_test "run_silent executes" "run_silent echo 'test'"

# Test: run_silent hides output
output=$(run_silent echo 'should not see this')
run_test "run_silent hides output" "[[ -z \"$output\" ]]"

# Test: log function works (smoke test)
run_test "log info" "log info 'Test message'"

# Test: spin executes command (quick command)
run_test "spin executes" "spin 'Testing...' sleep 0.1"

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
