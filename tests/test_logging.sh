#!/usr/bin/env bash
#===============================================================================
# test_logging.sh - Tests for lib/logging.sh
#===============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Source logging.sh directly (it has no dependencies)
source "${LIB_DIR}/logging.sh"

#-------------------------------------------------------------------------------
# Test Groups
#-------------------------------------------------------------------------------

test_module_loading() {
    run_test "logging.sh loads" "true"
    run_test "_DCX_LOGGING_LOADED set" "[[ -n \"\${_DCX_LOGGING_LOADED:-}\" ]]"
    run_test "_DCX_LOG_LEVELS exists" "[[ -n \"\${_DCX_LOG_LEVELS[info]:-}\" ]]"
    run_test "DCX_LOG_LEVEL default is info" "[[ \"\${DCX_LOG_LEVEL}\" == \"info\" ]]"
}

test_log_functions() {
    run_test "log exists" "type log &>/dev/null"
    run_test "log_debug exists" "type log_debug &>/dev/null"
    run_test "log_info exists" "type log_info &>/dev/null"
    run_test "log_success exists" "type log_success &>/dev/null"
    run_test "log_warn exists" "type log_warn &>/dev/null"
    run_test "log_error exists" "type log_error &>/dev/null"
    run_test "log_fatal exists" "type log_fatal &>/dev/null"
    run_test "warn exists" "type warn &>/dev/null"
    run_test "die exists" "type die &>/dev/null"
}

test_config_functions() {
    run_test "log_set_level exists" "type log_set_level &>/dev/null"
    run_test "log_set_module_level exists" "type log_set_module_level &>/dev/null"
    run_test "log_get_module_level exists" "type log_get_module_level &>/dev/null"
    run_test "log_init_file exists" "type log_init_file &>/dev/null"
}

test_progress_functions() {
    run_test "log_phase exists" "type log_phase &>/dev/null"
    run_test "log_step exists" "type log_step &>/dev/null"
    run_test "log_step_done exists" "type log_step_done &>/dev/null"
    run_test "log_progress exists" "type log_progress &>/dev/null"
}

test_command_logging() {
    run_test "log_cmd exists" "type log_cmd &>/dev/null"
    run_test "log_cmd_start exists" "type log_cmd_start &>/dev/null"
    run_test "log_cmd_end exists" "type log_cmd_end &>/dev/null"
}

test_output_helpers() {
    run_test "log_separator exists" "type log_separator &>/dev/null"
    run_test "log_kv exists" "type log_kv &>/dev/null"
    run_test "log_section exists" "type log_section &>/dev/null"
}

test_internal_functions() {
    run_test "_dc_should_log exists" "type _dc_should_log &>/dev/null"
    run_test "_dc_log_text exists" "type _dc_log_text &>/dev/null"
    run_test "_dc_log_json exists" "type _dc_log_json &>/dev/null"
}

test_log_level_changes() {
    run_test "log_set_level debug" "log_set_level debug && [[ \"\$DCX_LOG_LEVEL\" == \"debug\" ]]"
    run_test "log_set_level info" "log_set_level info && [[ \"\$DCX_LOG_LEVEL\" == \"info\" ]]"
    run_test "log_set_level warn" "log_set_level warn && [[ \"\$DCX_LOG_LEVEL\" == \"warn\" ]]"
    run_test "log_set_level error" "log_set_level error && [[ \"\$DCX_LOG_LEVEL\" == \"error\" ]]"
    run_test "log_set_level rejects invalid" "! log_set_level invalid"
}

test_module_level() {
    run_test "log_set_module_level" "log_set_module_level 'test.sh' 'debug'"
    log_set_module_level "test.sh" "warn"
    run_test "log_get_module_level" "[[ \"\$(log_get_module_level 'test.sh')\" == \"warn\" ]]"
    run_test "log_get_module_level fallback" "[[ \"\$(log_get_module_level 'unknown.sh')\" == \"\$DCX_LOG_LEVEL\" ]]"
}

test_should_log() {
    DCX_LOG_LEVEL="warn"
    run_test "_dc_should_log filters debug" "! _dc_should_log debug test.sh"
    run_test "_dc_should_log filters info" "! _dc_should_log info test.sh"
    run_test "_dc_should_log allows warn" "_dc_should_log warn test.sh"
    run_test "_dc_should_log allows error" "_dc_should_log error test.sh"
    DCX_LOG_LEVEL="info"
}

test_log_output() {
    run_test "log info output" "[[ -n \"\$(log info 'test message' 2>&1)\" ]]"
    run_test "log_info output" "[[ -n \"\$(log_info 'test message' 2>&1)\" ]]"
}

test_json_format() {
    DCX_LOG_FORMAT="json"
    output=$(log info "test" 2>&1)
    run_test "JSON format has timestamp" "[[ \"\$output\" == *'\"timestamp\"'* ]]"
    run_test "JSON format has level" "[[ \"\$output\" == *'\"level\"'* ]]"
    run_test "JSON format has message" "[[ \"\$output\" == *'\"message\"'* ]]"
    DCX_LOG_FORMAT="text"
}

test_file_logging() {
    tmp_log="/tmp/dc-test-$$/test.log"
    run_test "log_init_file" "log_init_file \"\$tmp_log\" && [[ \"\$DCX_LOG_FILE\" == \"\$tmp_log\" ]]"
    echo "test" > "$tmp_log"
    DCX_LOG_FILE="$tmp_log"
    log info "file test message"
    run_test "log writes to file" "grep -q 'file test message' \"\$tmp_log\""
    DCX_LOG_FILE=""
    rm -rf "/tmp/dc-test-$$"
}

test_helper_output() {
    run_test "log_separator output" "[[ -n \"\$(log_separator)\" ]]"
    run_test "log_separator custom char" "[[ \"\$(log_separator '=')\" == *'='* ]]"

    output=$(log_kv "key" "value")
    run_test "log_kv output" "[[ \"\$output\" == *'key'* && \"\$output\" == *'value'* ]]"

    run_test "log_section output" "[[ -n \"\$(log_section 'Test Section')\" ]]"
    run_test "log_cmd executes" "log_cmd true"
    run_test "log_cmd returns exit code" "! log_cmd false"
    run_test "log_progress output" "[[ -n \"\$(log_progress 5 10 'Testing' 2>&1)\" ]]"
}

#-------------------------------------------------------------------------------
# Run Tests
#-------------------------------------------------------------------------------

describe "Module Loading" test_module_loading
describe "Log Functions" test_log_functions
describe "Configuration Functions" test_config_functions
describe "Progress Functions" test_progress_functions
describe "Command Logging" test_command_logging
describe "Output Helpers" test_output_helpers
describe "Internal Functions" test_internal_functions
describe "Log Level Changes" test_log_level_changes
describe "Module Level" test_module_level
describe "Should Log Filter" test_should_log
describe "Log Output" test_log_output
describe "JSON Format" test_json_format
describe "File Logging" test_file_logging
describe "Helper Output" test_helper_output

test_summary
