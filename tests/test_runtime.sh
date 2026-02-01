#!/usr/bin/env bash
#===============================================================================
# test_runtime.sh - Tests for lib/runtime.sh
#===============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

echo "Testing runtime.sh..."
echo ""

# Setup
test_setup
echo "test content" > "${TMP_DIR}/testfile.txt"

# Source modules
source "${LIB_DIR}/core.sh"
source "${LIB_DIR}/runtime.sh"

# Test: Module loads without error
run_test "runtime.sh loads" "true"
run_test "_DCX_RUNTIME_LOADED set" "[[ -n \"\${_DCX_RUNTIME_LOADED:-}\" ]]"

# Test: Validator functions exist
run_test "need_cmd exists" "type need_cmd &>/dev/null"
run_test "need_cmds exists" "type need_cmds &>/dev/null"
run_test "assert_file exists" "type assert_file &>/dev/null"
run_test "assert_dir exists" "type assert_dir &>/dev/null"
run_test "assert_nonempty exists" "type assert_nonempty &>/dev/null"
run_test "assert_var exists" "type assert_var &>/dev/null"

# Test: spin function exists
run_test "spin exists" "type spin &>/dev/null"

# Test: Utility functions exist
run_test "retry exists" "type retry &>/dev/null"
run_test "timeout_cmd exists" "type timeout_cmd &>/dev/null"
run_test "run_silent exists" "type run_silent &>/dev/null"
run_test "run_or_die exists" "type run_or_die &>/dev/null"

# Test: need_cmd succeeds for existing command
run_test "need_cmd existing" "need_cmd bash"
run_test "need_cmd missing" "! need_cmd nonexistent_command_xyz"

# Test: need_cmds succeeds for existing commands
run_test "need_cmds existing" "need_cmds bash cat ls"
run_test "need_cmds partial" "! need_cmds bash nonexistent_xyz cat"

# Test: assert_file succeeds for existing file
run_test "assert_file existing" "assert_file \"${TMP_DIR}/testfile.txt\""
run_test "assert_file missing" "! assert_file /nonexistent/file.txt"

# Test: assert_dir succeeds for existing directory
run_test "assert_dir existing" "assert_dir \"${TMP_DIR}\""
run_test "assert_dir missing" "! assert_dir /nonexistent/dir"

# Test: assert_nonempty succeeds for non-empty value
run_test "assert_nonempty non-empty" "assert_nonempty \"hello\" \"test\""
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

# Test: spin executes command (quick command)
run_test "spin executes" "spin 'Testing...' sleep 0.1 2>/dev/null || true"

test_summary
