#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test Helpers & Utilities
#
# Provides reusable test framework functions for creating realistic mocks,
# assertions, error injection, and test fixtures.
#
# Usage:
#   source "$(dirname "$0")/lib/test_helpers.sh"
#   run_test "test name" 'test code'
#   run_test_expect_error "test name" "expected error" 'test code'
#===============================================================================

set -Eeuo pipefail

# Test state tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TEST_NAMES=()
TEST_TEMP_DIR=""

#===============================================================================
# SECTION 1: Test Execution Helpers
#===============================================================================

# Run a test expecting success
run_test() {
    local test_name="$1"
    local test_code="$2"

    if (eval "$test_code") 2>/dev/null; then
        echo "[PASS] $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "[FAIL] $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TEST_NAMES+=("$test_name")
        return 1
    fi
}

# Run a test expecting failure with error message validation
run_test_expect_error() {
    local test_name="$1"
    local expected_msg="$2"
    local test_code="$3"

    local error_output
    error_output=$(eval "$test_code" 2>&1 || true)

    if [[ "$error_output" =~ $expected_msg ]]; then
        echo "[PASS] $test_name (correctly failed)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "[FAIL] $test_name (expected error with '$expected_msg', got: $error_output)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TEST_NAMES+=("$test_name")
        return 1
    fi
}

# Print test summary
print_test_summary() {
    echo ""
    echo "========================================"
    echo "  TEST SUMMARY"
    echo "========================================"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo "Failed tests:"
        for name in "${FAILED_TEST_NAMES[@]}"; do
            echo "  - $name"
        done
        return 1
    else
        echo "STATUS: ALL TESTS PASSED ✓"
        return 0
    fi
}

#===============================================================================
# SECTION 2: Mock Setup & Teardown
#===============================================================================

# Setup temporary test environment
setup_test_env() {
    TEST_TEMP_DIR=$(mktemp -d)
    export TEST_TEMP_DIR

    # Create mock directories
    mkdir -p "$TEST_TEMP_DIR"/{mocks,logs,queue,fixtures}

    # Add mocks to PATH
    export PATH="$TEST_TEMP_DIR/mocks:$PATH"
}

# Cleanup temporary test environment
cleanup_test_env() {
    if [[ -n "${TEST_TEMP_DIR:-}" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Trap cleanup on exit
trap cleanup_test_env EXIT

#===============================================================================
# SECTION 3: Oracle Environment Mocking
#===============================================================================

# Setup mock Oracle environment
setup_mock_oracle_env() {
    local oracle_home="$TEST_TEMP_DIR/oracle_home"

    mkdir -p "$oracle_home"/bin

    # Create fake sqlplus
    cat > "$oracle_home/bin/sqlplus" << 'SQLPLUS_EOF'
#!/bin/bash
# Mock SQLPlus - returns canned responses based on arguments
case "$@" in
    *"select status from v$instance"*)
        echo "MOUNTED"
        ;;
    *"select current_scn"*)
        echo "12345678"
        ;;
    *)
        echo "SQL> "
        ;;
esac
exit 0
SQLPLUS_EOF
    chmod +x "$oracle_home/bin/sqlplus"

    # Create fake rman
    cat > "$oracle_home/bin/rman" << 'RMAN_EOF'
#!/bin/bash
# Mock RMAN - records command execution
echo "RMAN> "
while read -r line; do
    [[ -z "$line" ]] && continue
    echo "$line" >> /tmp/rman_commands.log
    echo "RMAN> "
done
exit 0
RMAN_EOF
    chmod +x "$oracle_home/bin/rman"

    export ORACLE_HOME="$oracle_home"
    export PATH="$oracle_home/bin:$PATH"
}

#===============================================================================
# SECTION 4: Data Pump Mock Commands
#===============================================================================

# Setup mock Data Pump commands (impdp/expdp)
setup_mock_datapump_commands() {
    local mocks_dir="$TEST_TEMP_DIR/mocks"

    # Create fake impdp
    cat > "$mocks_dir/impdp" << 'IMPDP_EOF'
#!/bin/bash
# Mock impdp - simulates Data Pump import behavior
set -Eeuo pipefail

# Parse command line
logfile=""
parfile=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        LOGFILE=*)
            logfile="${1#LOGFILE=}"
            ;;
        PARFILE=*)
            parfile="${1#PARFILE=}"
            ;;
    esac
    shift
done

# Default log file if not specified
logfile="${logfile:--}"

# Simulate import log output
{
    echo "Import: Release 19.0.0.0.0 - Production on $(date)"
    echo "Copyright (c) 1982, 2020, Oracle and/or its affiliates.  All rights reserved."
    echo ""
    echo "Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production"
    echo "Completed: 1 file imported (1 files in the import job)"
    echo "Completed: Statistics job"
    echo "Finished at $(date)"
} >> "$logfile"

exit 0
IMPDP_EOF
    chmod +x "$mocks_dir/impdp"

    # Create fake expdp
    cat > "$mocks_dir/expdp" << 'EXPDP_EOF'
#!/bin/bash
# Mock expdp - simulates Data Pump export behavior
set -Eeuo pipefail

# Parse command line
logfile=""
dumpfile=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        LOGFILE=*)
            logfile="${1#LOGFILE=}"
            ;;
        DUMPFILE=*)
            dumpfile="${1#DUMPFILE=}"
            ;;
    esac
    shift
done

# Default log file if not specified
logfile="${logfile:--}"

# Create dummy dump file if specified
if [[ -n "$dumpfile" ]]; then
    touch "$dumpfile"
fi

# Simulate export log output
{
    echo "Export: Release 19.0.0.0.0 - Production on $(date)"
    echo "Copyright (c) 1982, 2020, Oracle and/or its affiliates.  All rights reserved."
    echo ""
    echo "Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production"
    echo "Completed: 1 master table created"
    echo "Completed: SCHEMA.TABLE:10 rows"
    echo "Finished at $(date)"
} >> "$logfile"

exit 0
EXPDP_EOF
    chmod +x "$mocks_dir/expdp"
}

#===============================================================================
# SECTION 5: Mock Command Creation
#===============================================================================

# Create a mock command that returns specified output
mock_command() {
    local cmd_name="$1"
    local output="$2"
    local exit_code="${3:-0}"

    cat > "$TEST_TEMP_DIR/mocks/$cmd_name" << MOCK_EOF
#!/bin/bash
echo "$output"
exit $exit_code
MOCK_EOF
    chmod +x "$TEST_TEMP_DIR/mocks/$cmd_name"
}

# Create a mock command that writes to a log file
mock_command_with_log() {
    local cmd_name="$1"
    local logfile="$2"
    local output="$3"

    cat > "$TEST_TEMP_DIR/mocks/$cmd_name" << MOCK_EOF
#!/bin/bash
echo "$output" >> "$logfile"
exit 0
MOCK_EOF
    chmod +x "$TEST_TEMP_DIR/mocks/$cmd_name"
}

# Create a mock command that fails with specific error
mock_command_fail() {
    local cmd_name="$1"
    local error_msg="$2"
    local exit_code="${3:-1}"

    cat > "$TEST_TEMP_DIR/mocks/$cmd_name" << MOCK_EOF
#!/bin/bash
echo "$error_msg" >&2
exit $exit_code
MOCK_EOF
    chmod +x "$TEST_TEMP_DIR/mocks/$cmd_name"
}

#===============================================================================
# SECTION 6: Test Data Generators
#===============================================================================

# Create a temporary test parfile
create_test_parfile() {
    local parfile_path="$TEST_TEMP_DIR/test.par"

    cat > "$parfile_path" << 'PARFILE_EOF'
-- Test Parfile
USERID=system/oracle@db
DIRECTORY=dpump_dir
DUMPFILE=test.dmp
LOGFILE=test.log
PARALLEL=4
TABLES=TEST_USER.TEST_TABLE
PARFILE_EOF

    echo "$parfile_path"
}

# Create a temporary parfile with QUERY parameter
create_test_parfile_with_query() {
    local parfile_path="$TEST_TEMP_DIR/test_query.par"

    cat > "$parfile_path" << 'PARFILE_EOF'
-- Test Parfile with QUERY
USERID=system/oracle@db
DIRECTORY=dpump_dir
DUMPFILE=test.dmp
LOGFILE=test.log
QUERY=TEST_USER.TEST_TABLE:"WHERE id > 1000"
PARFILE_EOF

    echo "$parfile_path"
}

# Create temporary test configuration file
create_test_config() {
    local config_path="$TEST_TEMP_DIR/test.conf"

    cat > "$config_path" << 'CONFIG_EOF'
# Test Configuration
ORACLE_SID=test
ORACLE_HOME=/tmp/oracle_home
DB_USER=system
DB_PASS=oracle
PARALLEL_DEGREE=4
MAX_CONCURRENT_PROCESSES=2
CONFIG_EOF

    echo "$config_path"
}

#===============================================================================
# SECTION 7: Assertion Helpers
#===============================================================================

# Assert file exists
assert_file_exists() {
    local file="$1"
    [[ -f "$file" ]] || { echo "FAIL: File does not exist: $file"; return 1; }
}

# Assert file contains pattern
assert_file_contains() {
    local file="$1"
    local pattern="$2"
    grep -q "$pattern" "$file" || { echo "FAIL: Pattern not found in $file: $pattern"; return 1; }
}

# Assert directory exists
assert_dir_exists() {
    local dir="$1"
    [[ -d "$dir" ]] || { echo "FAIL: Directory does not exist: $dir"; return 1; }
}

# Assert variable equals value
assert_equals() {
    local var_name="$1"
    local expected="$2"
    local actual="$3"
    [[ "$actual" == "$expected" ]] || { echo "FAIL: $var_name: expected '$expected', got '$actual'"; return 1; }
}

# Assert variable matches pattern
assert_matches() {
    local var_name="$1"
    local pattern="$2"
    local actual="$3"
    [[ "$actual" =~ $pattern ]] || { echo "FAIL: $var_name: '$actual' does not match pattern '$pattern'"; return 1; }
}

# Assert command succeeds
assert_command_success() {
    local cmd="$1"
    eval "$cmd" || { echo "FAIL: Command failed: $cmd"; return 1; }
}

# Assert command fails
assert_command_fails() {
    local cmd="$1"
    ! eval "$cmd" || { echo "FAIL: Command should have failed: $cmd"; return 1; }
}

#===============================================================================
# SECTION 8: Parallel Job Testing Helpers
#===============================================================================

# Create queue for parallel job testing
setup_queue_env() {
    local queue_dir="$TEST_TEMP_DIR/queue"

    mkdir -p "$queue_dir"/{pending,running,completed,failed}

    export QUEUE_DIR="$queue_dir"
}

# Register a mock job in queue
register_queue_job() {
    local job_id="$1"
    local job_cmd="$2"

    cat > "$QUEUE_DIR/pending/$job_id" << JOB_EOF
#!/bin/bash
$job_cmd
JOB_EOF
    chmod +x "$QUEUE_DIR/pending/$job_id"
}

# Simulate job completion
complete_queue_job() {
    local job_id="$1"

    [[ -f "$QUEUE_DIR/pending/$job_id" ]] && mv "$QUEUE_DIR/pending/$job_id" "$QUEUE_DIR/completed/$job_id"
}

# Get count of completed jobs
get_completed_job_count() {
    ls "$QUEUE_DIR/completed/" 2>/dev/null | wc -l || echo 0
}

#===============================================================================
# SECTION 9: Timeout & Timing Helpers
#===============================================================================

# Run command with timeout
run_with_timeout() {
    local timeout_sec="$1"
    local cmd="$2"

    timeout "$timeout_sec" bash -c "$cmd"
}

# Measure command execution time
measure_time() {
    local cmd="$1"

    local start_time
    start_time=$(date +%s%N)

    eval "$cmd" || true

    local end_time
    end_time=$(date +%s%N)

    local elapsed_ms=$(( (end_time - start_time) / 1000000 ))
    echo "$elapsed_ms"
}

# Assert command completes within time limit
assert_completes_within() {
    local timeout_ms="$1"
    local cmd="$2"

    local elapsed
    elapsed=$(measure_time "$cmd")

    if [[ $elapsed -gt $timeout_ms ]]; then
        echo "FAIL: Command took ${elapsed}ms, expected < ${timeout_ms}ms"
        return 1
    fi
}

#===============================================================================
# SECTION 10: Cleanup Helpers
#===============================================================================

# Clean test files matching pattern
cleanup_test_files() {
    local pattern="$1"
    rm -f "$TEST_TEMP_DIR"/$pattern
}

# Save test artifacts (for debugging)
save_test_artifacts() {
    local artifact_dir="${1:-.}"
    cp -r "$TEST_TEMP_DIR" "$artifact_dir/test_artifacts_$$" 2>/dev/null || true
}

#===============================================================================
# SECTION 11: Initialization
#===============================================================================

# Initialize test environment on source
setup_test_env
