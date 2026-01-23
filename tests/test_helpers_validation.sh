#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test Helpers Validation
#
# Validates that test_helpers.sh infrastructure works correctly
#===============================================================================

source "$(dirname "$0")/lib/test_helpers.sh"

echo "========================================"
echo "  Test Helpers Validation"
echo "========================================"
echo ""

# Test 1: Basic test execution
run_test "run_test function works" '
    [[ 1 -eq 1 ]]
'

# Test 2: Test failure detection
run_test "run_test detects failures" '
    ! run_test "intentional failure" "[[ 1 -eq 2 ]]" 2>/dev/null
'

# Test 3: Mock Oracle environment
run_test "setup_mock_oracle_env creates ORACLE_HOME" '
    original_oracle=$ORACLE_HOME
    setup_mock_oracle_env
    # Verify it changed to our mock
    [[ -n "${ORACLE_HOME:-}" ]] && [[ "$ORACLE_HOME" == "$TEST_TEMP_DIR/oracle_home" ]]
'

# Test 4: Mock sqlplus exists and is executable
run_test "Mock sqlplus executable" '
    [[ -x "$TEST_TEMP_DIR/oracle_home/bin/sqlplus" ]]
'

# Test 5: Mock rman exists and is executable
run_test "Mock rman executable" '
    [[ -x "$TEST_TEMP_DIR/oracle_home/bin/rman" ]]
'

# Test 6: Setup mock Data Pump commands
run_test "setup_mock_datapump_commands creates impdp" '
    setup_mock_datapump_commands
    [[ -x "${TEST_TEMP_DIR}/mocks/impdp" ]]
'

# Test 7: Setup mock Data Pump creates expdp
run_test "setup_mock_datapump_commands creates expdp" '
    [[ -x "${TEST_TEMP_DIR}/mocks/expdp" ]]
'

# Test 8: Create test parfile
run_test "create_test_parfile generates valid parfile" '
    parfile=$(create_test_parfile)
    [[ -f "$parfile" ]] && grep -q "USERID=" "$parfile"
'

# Test 9: Create test config
run_test "create_test_config generates valid config" '
    config=$(create_test_config)
    [[ -f "$config" ]] && grep -q "ORACLE_SID=" "$config"
'

# Test 10: Assertion helpers work
run_test "assert_file_exists validates file" '
    touch "$TEST_TEMP_DIR/test.txt"
    assert_file_exists "$TEST_TEMP_DIR/test.txt"
'

# Test 11: Queue environment setup
run_test "setup_queue_env creates queue directories" '
    setup_queue_env
    [[ -d "$QUEUE_DIR/pending" ]] && \
    [[ -d "$QUEUE_DIR/running" ]] && \
    [[ -d "$QUEUE_DIR/completed" ]]
'

# Test 12: Mock command creation
run_test "mock_command creates executable" '
    mock_command "test_cmd" "test output"
    [[ -x "$TEST_TEMP_DIR/mocks/test_cmd" ]]
'

# Test 13: Mock command executes correctly
run_test "mock_command produces expected output" '
    output=$("$TEST_TEMP_DIR/mocks/test_cmd" 2>&1)
    [[ "$output" == "test output" ]]
'

# Test 14: Mock command with failure
run_test "mock_command_fail creates failing command" '
    mock_command_fail "fail_cmd" "error message" 1
    ! "$TEST_TEMP_DIR/mocks/fail_cmd" >/dev/null 2>&1
'

# Test 15: Error test helper
run_test_expect_error "run_test_expect_error validates errors" \
    "ERROR" \
    'run_test_expect_error "test" "ERROR" "die \"ERROR: test\"" 2>/dev/null'

echo ""
print_test_summary
