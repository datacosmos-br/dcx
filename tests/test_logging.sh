#!/usr/bin/env bash
#===============================================================================
# test_logging.sh - Tests for lib/logging.sh
#===============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

echo "Testing logging.sh..."
echo ""

# Source logging.sh directly (it has no dependencies)
source "${LIB_DIR}/logging.sh"

# Test: Module loads without error
run_test "logging.sh loads" "true"
run_test "_DC_LOGGING_LOADED set" "[[ -n \"\${_DC_LOGGING_LOADED:-}\" ]]"
run_test "_DC_LOG_LEVELS exists" "[[ -n \"\${_DC_LOG_LEVELS[info]:-}\" ]]"
run_test "DC_LOG_LEVEL default is info" "[[ \"\${DC_LOG_LEVEL}\" == \"info\" ]]"

# Test: Core functions exist
run_test "log exists" "type log &>/dev/null"
run_test "log_debug exists" "type log_debug &>/dev/null"
run_test "log_info exists" "type log_info &>/dev/null"
run_test "log_success exists" "type log_success &>/dev/null"
run_test "log_warn exists" "type log_warn &>/dev/null"
run_test "log_error exists" "type log_error &>/dev/null"
run_test "log_fatal exists" "type log_fatal &>/dev/null"
run_test "warn exists" "type warn &>/dev/null"
run_test "die exists" "type die &>/dev/null"

# Test: Configuration functions exist
run_test "log_set_level exists" "type log_set_level &>/dev/null"
run_test "log_set_module_level exists" "type log_set_module_level &>/dev/null"
run_test "log_get_module_level exists" "type log_get_module_level &>/dev/null"
run_test "log_init_file exists" "type log_init_file &>/dev/null"

# Test: Progress/step functions exist
run_test "log_phase exists" "type log_phase &>/dev/null"
run_test "log_step exists" "type log_step &>/dev/null"
run_test "log_step_done exists" "type log_step_done &>/dev/null"
run_test "log_progress exists" "type log_progress &>/dev/null"

# Test: Command logging functions exist
run_test "log_cmd exists" "type log_cmd &>/dev/null"
run_test "log_cmd_start exists" "type log_cmd_start &>/dev/null"
run_test "log_cmd_end exists" "type log_cmd_end &>/dev/null"

# Test: Output helpers exist
run_test "log_separator exists" "type log_separator &>/dev/null"
run_test "log_kv exists" "type log_kv &>/dev/null"
run_test "log_section exists" "type log_section &>/dev/null"

# Test: Internal functions exist
run_test "_dc_should_log exists" "type _dc_should_log &>/dev/null"
run_test "_dc_log_text exists" "type _dc_log_text &>/dev/null"
run_test "_dc_log_json exists" "type _dc_log_json &>/dev/null"

# Test: log_set_level works
run_test "log_set_level debug" "log_set_level debug && [[ \"\$DC_LOG_LEVEL\" == \"debug\" ]]"
run_test "log_set_level info" "log_set_level info && [[ \"\$DC_LOG_LEVEL\" == \"info\" ]]"
run_test "log_set_level warn" "log_set_level warn && [[ \"\$DC_LOG_LEVEL\" == \"warn\" ]]"
run_test "log_set_level error" "log_set_level error && [[ \"\$DC_LOG_LEVEL\" == \"error\" ]]"
run_test "log_set_level rejects invalid" "! log_set_level invalid"

# Test: log_set_module_level works
run_test "log_set_module_level" "log_set_module_level 'test.sh' 'debug'"

# Test: log_get_module_level returns correct level
log_set_module_level "test.sh" "warn"
run_test "log_get_module_level" "[[ \"\$(log_get_module_level 'test.sh')\" == \"warn\" ]]"
run_test "log_get_module_level fallback" "[[ \"\$(log_get_module_level 'unknown.sh')\" == \"\$DC_LOG_LEVEL\" ]]"

# Test: _dc_should_log respects log levels
DC_LOG_LEVEL="warn"
run_test "_dc_should_log filters debug" "! _dc_should_log debug test.sh"
run_test "_dc_should_log filters info" "! _dc_should_log info test.sh"
run_test "_dc_should_log allows warn" "_dc_should_log warn test.sh"
run_test "_dc_should_log allows error" "_dc_should_log error test.sh"
DC_LOG_LEVEL="info"

# Test: log produces output
run_test "log info output" "[[ -n \"\$(log info 'test message' 2>&1)\" ]]"
run_test "log_info output" "[[ -n \"\$(log_info 'test message' 2>&1)\" ]]"

# Test: JSON format
DC_LOG_FORMAT="json"
output=$(log info "test" 2>&1)
run_test "JSON format has timestamp" "[[ \"\$output\" == *'\"timestamp\"'* ]]"
run_test "JSON format has level" "[[ \"\$output\" == *'\"level\"'* ]]"
run_test "JSON format has message" "[[ \"\$output\" == *'\"message\"'* ]]"
DC_LOG_FORMAT="text"

# Test: log_init_file creates directory and sets variable
tmp_log="/tmp/dc-test-$$/test.log"
run_test "log_init_file" "log_init_file \"\$tmp_log\" && [[ \"\$DC_LOG_FILE\" == \"\$tmp_log\" ]]"

# Test: logging to file works
echo "test" > "$tmp_log"
DC_LOG_FILE="$tmp_log"
log info "file test message"
run_test "log writes to file" "grep -q 'file test message' \"\$tmp_log\""
DC_LOG_FILE=""
rm -rf "/tmp/dc-test-$$"

# Test: log_separator produces output
run_test "log_separator output" "[[ -n \"\$(log_separator)\" ]]"
run_test "log_separator custom char" "[[ \"\$(log_separator '=')\" == *'='* ]]"

# Test: log_kv produces formatted output
output=$(log_kv "key" "value")
run_test "log_kv output" "[[ \"\$output\" == *'key'* && \"\$output\" == *'value'* ]]"

# Test: log_section produces output
run_test "log_section output" "[[ -n \"\$(log_section 'Test Section')\" ]]"

# Test: log_cmd executes command
run_test "log_cmd executes" "log_cmd true"
run_test "log_cmd returns exit code" "! log_cmd false"

# Test: log_progress produces output (redirect stderr)
run_test "log_progress output" "[[ -n \"\$(log_progress 5 10 'Testing' 2>&1)\" ]]"

test_summary
