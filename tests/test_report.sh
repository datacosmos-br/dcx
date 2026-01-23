#!/usr/bin/env bash
#===============================================================================
# test_report.sh - Tests for lib/report.sh
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
echo "Testing report.sh..."
echo ""

# Source report.sh (it has no external dependencies for basic tests)
source "${LIB_DIR}/report.sh"

# Test: Module loads without error
run_test "report.sh loads" "true"

# Test: Guard variable set
run_test "_DC_REPORT_LOADED set" "[[ -n \"\${_DC_REPORT_LOADED:-}\" ]]"

# Test: Core functions exist
run_test "report_init exists" "type report_init &>/dev/null"
run_test "report_phase exists" "type report_phase &>/dev/null"
run_test "report_step exists" "type report_step &>/dev/null"
run_test "report_step_done exists" "type report_step_done &>/dev/null"
run_test "report_track_item exists" "type report_track_item &>/dev/null"
run_test "report_metric exists" "type report_metric &>/dev/null"
run_test "report_metric_add exists" "type report_metric_add &>/dev/null"
run_test "report_metric_get exists" "type report_metric_get &>/dev/null"
run_test "report_confirm exists" "type report_confirm &>/dev/null"
run_test "report_select exists" "type report_select &>/dev/null"
run_test "report_progress exists" "type report_progress &>/dev/null"
run_test "report_finalize exists" "type report_finalize &>/dev/null"
run_test "report_summary exists" "type report_summary &>/dev/null"
run_test "report_table exists" "type report_table &>/dev/null"

# Test: Internal functions exist
run_test "_report_phase_end exists" "type _report_phase_end &>/dev/null"

# Test: report_init sets variables
report_init "Test Report" >/dev/null 2>&1
run_test "report_init sets _DC_REPORT_NAME" "[[ \"\$_DC_REPORT_NAME\" == \"Test Report\" ]]"
run_test "report_init sets _DC_REPORT_START_TIME" "[[ -n \"\$_DC_REPORT_START_TIME\" ]]"
run_test "report_init resets counters" "[[ \$_DC_REPORT_TOTAL_ITEMS -eq 0 ]]"

# Test: report_init with file
tmp_report="/tmp/dc-test-$$/report.md"
mkdir -p "/tmp/dc-test-$$"
report_init "File Test" "$tmp_report" >/dev/null 2>&1
run_test "report_init creates file" "[[ -f \"\$tmp_report\" ]]"
run_test "report_init file has header" "grep -q '# File Test' \"\$tmp_report\""

# Test: report_phase works
report_phase "Phase 1" "Description" >/dev/null 2>&1
run_test "report_phase sets _DC_REPORT_CURRENT_PHASE" "[[ \"\$_DC_REPORT_CURRENT_PHASE\" == \"Phase 1\" ]]"
run_test "report_phase sets _DC_REPORT_PHASE_START" "[[ -n \"\$_DC_REPORT_PHASE_START\" ]]"

# Test: report_phase writes to file
run_test "report_phase writes to file" "grep -q '## Phase 1' \"\$tmp_report\""

# Test: report_step produces output
run_test "report_step output" "[[ -n \"\$(report_step 'Test step')\" ]]"

# Test: report_step_done produces output
run_test "report_step_done success" "[[ -n \"\$(report_step_done 'Test step' 'success')\" ]]"
run_test "report_step_done failed" "[[ -n \"\$(report_step_done 'Test step' 'failed')\" ]]"
run_test "report_step_done skipped" "[[ -n \"\$(report_step_done 'Test step' 'skipped')\" ]]"

# Test: report_track_item increments counters
_DC_REPORT_TOTAL_ITEMS=0
_DC_REPORT_SUCCESS_ITEMS=0
_DC_REPORT_FAILED_ITEMS=0
_DC_REPORT_SKIPPED_ITEMS=0
_DC_REPORT_ITEMS=()

report_track_item "item1" "success" "message1" >/dev/null 2>&1
run_test "report_track_item increments total" "[[ \$_DC_REPORT_TOTAL_ITEMS -eq 1 ]]"
run_test "report_track_item increments success" "[[ \$_DC_REPORT_SUCCESS_ITEMS -eq 1 ]]"

report_track_item "item2" "failed" "message2" >/dev/null 2>&1
run_test "report_track_item increments failed" "[[ \$_DC_REPORT_FAILED_ITEMS -eq 1 ]]"

report_track_item "item3" "skipped" "message3" >/dev/null 2>&1
run_test "report_track_item increments skipped" "[[ \$_DC_REPORT_SKIPPED_ITEMS -eq 1 ]]"

run_test "report_track_item total is 3" "[[ \$_DC_REPORT_TOTAL_ITEMS -eq 3 ]]"

# Test: report_track_item stores items
run_test "report_track_item stores items" "[[ \${#_DC_REPORT_ITEMS[@]} -eq 3 ]]"

# Test: report_metric sets value
report_metric "test_metric" "100"
run_test "report_metric sets value" "[[ \"\${_DC_REPORT_METRICS[test_metric]}\" == \"100\" ]]"

# Test: report_metric_add increments
report_metric "counter" "0"
report_metric_add "counter" 5
run_test "report_metric_add increments" "[[ \"\${_DC_REPORT_METRICS[counter]}\" == \"5\" ]]"

report_metric_add "counter" 3
run_test "report_metric_add accumulates" "[[ \"\${_DC_REPORT_METRICS[counter]}\" == \"8\" ]]"

# Test: report_metric_add with default increment
report_metric "count2" "0"
report_metric_add "count2"
run_test "report_metric_add default increment" "[[ \"\${_DC_REPORT_METRICS[count2]}\" == \"1\" ]]"

# Test: report_metric_get returns value
run_test "report_metric_get" "[[ \"\$(report_metric_get 'test_metric')\" == \"100\" ]]"

# Test: report_metric_get with default
run_test "report_metric_get default" "[[ \"\$(report_metric_get 'nonexistent' '42')\" == \"42\" ]]"

# Test: report_progress produces output
run_test "report_progress output" "[[ -n \"\$(report_progress 5 10 'Testing' 2>&1)\" ]]"

# Test: report_summary produces output
run_test "report_summary output" "[[ -n \"\$(report_summary 2>&1)\" ]]"

# Test: report_table produces output (with items)
run_test "report_table output" "[[ -n \"\$(report_table)\" ]]"

# Test: report_table empty
_DC_REPORT_ITEMS=()
run_test "report_table empty" "[[ \"\$(report_table)\" == *'No items'* ]]"

# Test: report_finalize works
_DC_REPORT_ITEMS=()
_DC_REPORT_TOTAL_ITEMS=2
_DC_REPORT_SUCCESS_ITEMS=1
_DC_REPORT_FAILED_ITEMS=1
_DC_REPORT_SKIPPED_ITEMS=0
output=$(report_finalize 2>&1)
run_test "report_finalize output" "[[ -n \"\$output\" ]]"

# Test: report_finalize auto-determines status
_DC_REPORT_FAILED_ITEMS=0
_DC_REPORT_SUCCESS_ITEMS=5
run_test "report_finalize auto success" "report_finalize >/dev/null 2>&1"

# Test: report_finalize writes to file
run_test "report_finalize writes summary" "grep -q 'Summary' \"\$tmp_report\""

# Cleanup
rm -rf "/tmp/dc-test-$$"

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
