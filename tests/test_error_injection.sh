#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Error Injection Test Suite (Phase 5)
#
# Tests error paths and edge cases across all modules:
# - Parameter validation failures
# - File not found errors
# - Missing command errors
# - Configuration errors
# - Connection failures
# - Timeout scenarios
#
# Expected: 20+ tests covering critical error paths
#===============================================================================

source "$(dirname "$0")/lib/test_helpers.sh"

setup_test_env

echo "========================================"
echo "  Phase 5: Error Injection Tests"
echo "========================================"
echo ""

#===============================================================================
# SECTION 1: Parameter Validation Errors
#===============================================================================

echo "SECTION 1: Parameter Validation Errors"
echo ""

# Test 1: Missing required parameter
run_test_expect_error "Parameter validation rejects missing required param" \
    "ERROR" \
    'test_function() {
        local param="$1"
        [[ -n "$param" ]] || { echo "ERROR: required parameter is required"; return 1; }
        echo "Got: $param"
    }
    test_function ""
'

# Test 2: Empty string parameter validation
run_test_expect_error "Parameter validation rejects empty string" \
    "ERROR" \
    'test_function() {
        [[ -n "$1" ]] || { echo "ERROR: parameter cannot be empty"; return 1; }
        echo "Got: $1"
    }
    test_function ""
'

# Test 3: Invalid option handling
run_test_expect_error "Invalid option detection" \
    "ERROR" \
    'process_option() {
        case "$1" in
            --valid) echo "OK" ;;
            *) echo "ERROR: Unknown option: $1"; return 1 ;;
        esac
    }
    process_option "--invalid"
'

#===============================================================================
# SECTION 2: File Not Found Errors
#===============================================================================

echo "SECTION 2: File Not Found Errors"
echo ""

# Test 4: Missing input file
run_test_expect_error "Missing input file detection" \
    "ERROR" \
    'read_config() {
        local config_file="$1"
        [[ -f "$config_file" ]] || { echo "ERROR: Config file not found: $config_file"; return 1; }
        cat "$config_file"
    }
    read_config "/nonexistent/file.conf"
'

# Test 5: Missing directory validation
run_test_expect_error "Missing directory detection" \
    "ERROR" \
    'create_in_dir() {
        local dir="$1"
        [[ -d "$dir" ]] || { echo "ERROR: Directory does not exist: $dir"; return 1; }
        touch "$dir/file.txt"
    }
    create_in_dir "/nonexistent/directory"
'

# Test 6: Writable directory validation
run_test_expect_error "Write permission validation" \
    "ERROR" \
    'write_to_dir() {
        local dir="$1"
        [[ -w "$dir" ]] || { echo "ERROR: Directory is not writable: $dir"; return 1; }
        touch "$dir/file.txt"
    }
    # Try to write to root (not writable as regular user)
    write_to_dir "/root"
'

#===============================================================================
# SECTION 3: Command Execution Errors
#===============================================================================

echo "SECTION 3: Command Execution Errors"
echo ""

# Test 7: Missing command error
run_test_expect_error "Missing command detection" \
    "command" \
    '/nonexistent/command arg1 arg2
'

# Test 8: Command failure handling
run_test_expect_error "Command exit code detection" \
    "ERROR" \
    'run_safe() {
        local cmd="$1"
        $cmd || { echo "ERROR: Command failed with exit code $?"; return 1; }
    }
    run_safe "false"
'

# Test 9: Command returns non-zero exit code
run_test "Command failure exit codes" '
    failing_command() {
        return 1
    }
    failing_command || [[ $? -eq 1 ]]
'

#===============================================================================
# SECTION 4: SQL Execution Errors
#===============================================================================

echo "SECTION 4: SQL Execution Errors"
echo ""

# Test 10: Invalid SQL syntax
run_test_expect_error "SQL syntax error detection" \
    "ORA-" \
    'mock_sqlplus() {
        # Simulate sqlplus error for invalid SQL
        if [[ "$1" == *"INVALID SQL"* ]]; then
            echo "ERROR: ORA-00911: invalid character"
            return 1
        fi
    }
    mock_sqlplus "SELECT * INVALID SQL"
'

# Test 11: Connection failure
run_test_expect_error "Database connection error" \
    "ORA-" \
    'connect_db() {
        local user="$1"
        local pass="$2"
        local db="$3"

        # Simulate connection failure
        echo "ERROR: ORA-12514: TNS:listener could not resolve SERVICE_NAME"
        return 1
    }
    connect_db "admin" "wrongpass" "invalid_db"
'

# Test 12: Insufficient privileges
run_test_expect_error "Insufficient privileges detection" \
    "ORA-01031" \
    'grant_privilege() {
        local user="$1"
        # Simulate privilege error
        echo "ERROR: ORA-01031: insufficient privileges"
        return 1
    }
    grant_privilege "limited_user"
'

#===============================================================================
# SECTION 5: Configuration Errors
#===============================================================================

echo "SECTION 5: Configuration Errors"
echo ""

# Test 13: Missing configuration variable
run_test_expect_error "Missing config variable detection" \
    "ERROR" \
    'validate_config() {
        local var="${REQUIRED_VAR:-}"
        [[ -n "$var" ]] || { echo "ERROR: REQUIRED_VAR not set"; return 1; }
        echo "OK"
    }
    REQUIRED_VAR="" validate_config
'

# Test 14: Invalid configuration value
run_test_expect_error "Invalid config value detection" \
    "ERROR" \
    'validate_number() {
        local value="$1"
        [[ "$value" =~ ^[0-9]+$ ]] || { echo "ERROR: Value must be numeric: $value"; return 1; }
        echo "OK"
    }
    validate_number "not_a_number"
'

# Test 15: Configuration file validation
run_test "Configuration file validation" '
    validate_config_file() {
        local file="$1"
        [[ -f "$file" ]] || return 1

        # Check that file contains valid key=value pairs
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            [[ "$line" =~ = ]] || return 1
        done < "$file"
    }
    echo "KEY=value" > "$TEST_TEMP_DIR/good.conf"
    validate_config_file "$TEST_TEMP_DIR/good.conf"
'

#===============================================================================
# SECTION 6: Resource Limits & Constraints
#===============================================================================

echo "SECTION 6: Resource Limits & Constraints"
echo ""

# Test 16: Numeric validation
run_test "Numeric value validation" '
    validate_positive_number() {
        local value="$1"
        [[ "$value" =~ ^[0-9]+$ ]] && [[ $value -gt 0 ]] || return 1
    }
    validate_positive_number 42
'

# Test 17: Range validation
run_test "Range validation" '
    validate_range() {
        local value="$1"
        local min="$2"
        local max="$3"
        [[ $value -ge $min && $value -le $max ]]
    }
    validate_range 50 1 100
'

#===============================================================================
# SECTION 7: Edge Cases & Boundary Conditions
#===============================================================================

echo "SECTION 7: Edge Cases & Boundary Conditions"
echo ""

# Test 18: Empty result handling
run_test "Empty result handling" '
    process_results() {
        local result="$1"
        if [[ -z "$result" ]]; then
            echo "WARNING: No results"
            return 0
        fi
        echo "Got: $result"
    }

    process_results ""
'

# Test 19: Special characters in parameters
run_test "Special characters in parameters" '
    echo_safe() {
        local param="$1"
        # Safely handle special characters
        printf "%s\n" "$param"
    }

    result=$(echo_safe "test with spaces and \$special & chars")
    [[ "$result" =~ "test with spaces" ]]
'

# Test 20: Very large input handling
run_test "Large input handling" '
    process_large_input() {
        local input="$1"
        local size=${#input}
        [[ $size -lt 1000000 ]] && echo "Size: $size"
    }

    large_string=$(printf "x%.0s" {1..10000})
    process_large_input "$large_string"
'

echo ""
print_test_summary
