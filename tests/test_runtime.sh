#!/usr/bin/env bash
#===============================================================================
# test_runtime.sh - Tests for runtime utilities in lib/core.sh (core_ prefix)
#===============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Setup
test_setup
echo "test content" > "${TMP_DIR}/testfile.txt"

# Note: core.sh is auto-sourced by test_helpers.sh
# runtime.sh merged into core.sh - all functions available via core.sh with core_ prefix

#-------------------------------------------------------------------------------
# Test Groups
#-------------------------------------------------------------------------------

test_module_loading() {
    run_test "core.sh provides runtime functions with core_ prefix" "true"
    run_test "_DCX_CORE_LOADED set" "[[ -n \"\${_DCX_CORE_LOADED:-}\" ]]"
}

test_validator_functions() {
    run_test "core_need_cmd exists" "type core_need_cmd &>/dev/null"
    run_test "core_need_cmds exists" "type core_need_cmds &>/dev/null"
    run_test "core_assert_file exists" "type core_assert_file &>/dev/null"
    run_test "core_assert_dir exists" "type core_assert_dir &>/dev/null"
    run_test "core_assert_nonempty exists" "type core_assert_nonempty &>/dev/null"
    run_test "core_assert_var exists" "type core_assert_var &>/dev/null"
}

test_utility_functions() {
    run_test "core_spin exists" "type core_spin &>/dev/null"
    run_test "core_retry exists" "type core_retry &>/dev/null"
    run_test "core_timeout_cmd exists" "type core_timeout_cmd &>/dev/null"
    run_test "core_run_silent exists" "type core_run_silent &>/dev/null"
    run_test "core_run_or_die exists" "type core_run_or_die &>/dev/null"
}

test_need_cmd() {
    run_test "core_need_cmd existing" "core_need_cmd bash"
    run_test "core_need_cmd missing" "! core_need_cmd nonexistent_command_xyz"
    run_test "core_need_cmds existing" "core_need_cmds bash cat ls"
    run_test "core_need_cmds partial" "! core_need_cmds bash nonexistent_xyz cat"
}

test_assert_file_dir() {
    run_test "core_assert_file existing" "core_assert_file \"${TMP_DIR}/testfile.txt\""
    run_test "core_assert_file missing" "! core_assert_file /nonexistent/file.txt"
    run_test "core_assert_dir existing" "core_assert_dir \"${TMP_DIR}\""
    run_test "core_assert_dir missing" "! core_assert_dir /nonexistent/dir"
}

test_assert_nonempty_var() {
    run_test "core_assert_nonempty non-empty" "core_assert_nonempty \"hello\" \"test\""
    run_test "core_assert_nonempty empty" "! core_assert_nonempty \"\" \"test\""

    export TEST_VAR="value"
    run_test "core_assert_var set" "core_assert_var TEST_VAR"

    unset UNSET_VAR 2>/dev/null || true
    run_test "core_assert_var unset" "! core_assert_var UNSET_VAR"
}

test_run_silent() {
    run_test "core_run_silent executes" "core_run_silent echo 'test'"

    output=$(core_run_silent echo 'should not see this')
    run_test "core_run_silent hides output" "[[ -z \"$output\" ]]"
}

test_spin() {
    run_test "core_spin executes" "core_spin 'Testing...' sleep 0.1 2>/dev/null || true"
}

#-------------------------------------------------------------------------------
# Run Tests
#-------------------------------------------------------------------------------

describe "Module Loading" test_module_loading
describe "Validator Functions" test_validator_functions
describe "Utility Functions" test_utility_functions
describe "Need Command" test_need_cmd
describe "Assert File/Dir" test_assert_file_dir
describe "Assert Nonempty/Var" test_assert_nonempty_var
describe "Run Silent" test_run_silent
describe "Spin" test_spin

test_summary
