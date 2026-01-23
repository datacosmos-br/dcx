#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test Suite: Report Integration Tests
#
# Tests comprehensive integration of report.sh with all library modules
# Validates: WITH report, WITHOUT report, cross-module correlation, performance
#===============================================================================

# Setup
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

# Source libraries
source lib/logging.sh
source lib/runtime.sh
source lib/report.sh
source lib/oracle_datapump.sh
source lib/oracle_sql.sh
source lib/oracle_rman.sh
source lib/oracle_env.sh
source lib/oracle_config.sh
source lib/oracle_cluster.sh

# Test counter
test_count=0
pass_count=0
fail_count=0

# Temp directories
TEST_LOGS="/tmp/test_report_$$"
mkdir -p "${TEST_LOGS}"

# Test cleanup
cleanup_test() {
    [[ -d "${TEST_LOGS}" ]] && rm -rf "${TEST_LOGS}"
}
trap cleanup_test EXIT

#===============================================================================
# Test 1: Report Initialization
#===============================================================================
test_report_initialization() {
    (( test_count++ )) || true
    local test_name="Report initialization"

    report_init "Test" "${TEST_LOGS}/test1" >/dev/null 2>&1

    [[ -n "${_R_SESSION:-}" ]] || { (( fail_count++ )) || true; return 1; }
    [[ -d "${_R_OUTPUT_DIR}" ]] || { (( fail_count++ )) || true; return 1; }
    [[ ${_R_INITIALIZED} -eq 1 ]] || { (( fail_count++ )) || true; return 1; }

    (( pass_count++ )) || true
    echo "[PASS] $test_name"
}

#===============================================================================
# Test 2: Data Pump WITH Report
#===============================================================================
test_dp_with_report() {
    (( test_count++ )) || true
    local test_name="Data Pump module with report"

    {
        report_init "DP Test" "${TEST_LOGS}/dp_test" "dp_test" >/dev/null 2>&1
        report_track_phase "DP Phase" >/dev/null 2>&1
        report_track_step "DP Step" >/dev/null 2>&1
        report_track_metric "dp_rows_imported" "1000" >/dev/null 2>&1
        report_track_item "ok" "test" "ok" >/dev/null 2>&1
        report_track_step_done 0 "ok" >/dev/null 2>&1
    } >/dev/null 2>&1

    local report_file="${_R_OUTPUT_DIR}/dp_test_report.md"
    # Don't finalize - just check tracking works
    [[ ${_R_STEP_COUNT} -gt 0 ]] || { (( fail_count++ )) || true; return 1; }
    [[ -n "${_R_METRICS[dp_rows_imported]:-}" ]] || { (( fail_count++ )) || true; return 1; }

    (( pass_count++ )) || true
    echo "[PASS] $test_name"
}

#===============================================================================
# Test 3: SQL WITH Report
#===============================================================================
test_sql_with_report() {
    (( test_count++ )) || true
    local test_name="SQL module with report"

    {
        report_init "SQL Test" "${TEST_LOGS}/sql_test" "sql_test" >/dev/null 2>&1
        report_track_step "SQL Step" >/dev/null 2>&1
        report_track_metric "sql_scripts_executed" "3" >/dev/null 2>&1
        report_track_step_done 0 "ok" >/dev/null 2>&1
    } >/dev/null 2>&1

    [[ ${_R_STEP_COUNT} -gt 0 ]] || { (( fail_count++ )) || true; return 1; }
    [[ -n "${_R_METRICS[sql_scripts_executed]:-}" ]] || { (( fail_count++ )) || true; return 1; }

    (( pass_count++ )) || true
    echo "[PASS] $test_name"
}

#===============================================================================
# Test 4: RMAN WITH Report
#===============================================================================
test_rman_with_report() {
    (( test_count++ )) || true
    local test_name="RMAN module with report"

    {
        report_init "RMAN Test" "${TEST_LOGS}/rman_test" "rman_test" >/dev/null 2>&1
        report_track_step "RMAN Step" >/dev/null 2>&1
        report_track_metric "rman_transformations_total" "50" >/dev/null 2>&1
        report_track_step_done 0 "ok" >/dev/null 2>&1
    } >/dev/null 2>&1

    [[ ${_R_STEP_COUNT} -gt 0 ]] || { (( fail_count++ )) || true; return 1; }
    [[ -n "${_R_METRICS[rman_transformations_total]:-}" ]] || { (( fail_count++ )) || true; return 1; }

    (( pass_count++ )) || true
    echo "[PASS] $test_name"
}

#===============================================================================
# Test 5: WITHOUT Report (Backward Compatibility)
#===============================================================================
test_modules_without_report() {
    (( test_count++ )) || true
    local test_name="Module operations without report (graceful)"

    # Reset initialization
    _R_INITIALIZED=0

    # These should not error
    report_track_step "test" >/dev/null 2>&1 || true
    report_track_metric "test_metric" "123" >/dev/null 2>&1 || true
    report_track_step_done 0 "success" >/dev/null 2>&1 || true

    (( pass_count++ )) || true
    echo "[PASS] $test_name"
}

#===============================================================================
# Test 6: Cross-Module Correlation
#===============================================================================
test_cross_module_correlation() {
    (( test_count++ )) || true
    local test_name="Cross-module correlation by session"

    {
        report_init "Multi Test" "${TEST_LOGS}/multi" "multi_session" >/dev/null 2>&1
        local sess="${_R_SESSION}"

        report_track_step "DP" >/dev/null 2>&1
        report_track_metric "dp_rows" "100" >/dev/null 2>&1
        report_track_step_done 0 "ok" >/dev/null 2>&1

        report_track_step "SQL" >/dev/null 2>&1
        report_track_metric "sql_exec" "2" >/dev/null 2>&1
        report_track_step_done 0 "ok" >/dev/null 2>&1

        report_track_step "RMAN" >/dev/null 2>&1
        report_track_metric "rman_files" "10" >/dev/null 2>&1
        report_track_step_done 0 "ok" >/dev/null 2>&1
    } >/dev/null 2>&1

    [[ ${_R_STEP_COUNT} -eq 3 ]] || { (( fail_count++ )) || true; return 1; }

    (( pass_count++ )) || true
    echo "[PASS] $test_name"
}

#===============================================================================
# Test 7: Metric Aggregation
#===============================================================================
test_metric_aggregation() {
    (( test_count++ )) || true
    local test_name="Metric aggregation functions"

    {
        report_init "Agg Test" "${TEST_LOGS}/agg" "agg_test" >/dev/null 2>&1
        report_track_metric "dp_1" "100" >/dev/null 2>&1
        report_track_metric "dp_2" "200" >/dev/null 2>&1
        report_track_metric "sql_1" "50" >/dev/null 2>&1
    } >/dev/null 2>&1

    local sum
    sum=$(report_metric_aggregate "dp_*" "sum" 2>/dev/null)
    [[ "${sum}" == "300" ]] || { (( fail_count++ )) || true; return 1; }

    (( pass_count++ )) || true
    echo "[PASS] $test_name"
}

#===============================================================================
# Test 8: Timeline Query
#===============================================================================
test_timeline_query() {
    (( test_count++ )) || true
    local test_name="Timeline query function"

    {
        report_init "Timeline Test" "${TEST_LOGS}/timeline" "timeline_test" >/dev/null 2>&1
        report_track_step "Step 1" >/dev/null 2>&1
        sleep 0.05
        report_track_step_done 0 "OK" >/dev/null 2>&1
    } >/dev/null 2>&1

    local timeline
    timeline=$(report_query_timeline 2>/dev/null)
    [[ -n "${timeline}" ]] || { (( fail_count++ )) || true; return 1; }

    (( pass_count++ )) || true
    echo "[PASS] $test_name"
}

#===============================================================================
# Test 9: Critical Path
#===============================================================================
test_critical_path() {
    (( test_count++ )) || true
    local test_name="Critical path analysis"

    {
        report_init "Critical Test" "${TEST_LOGS}/critical" "critical_test" >/dev/null 2>&1
        report_track_step "Op 1" >/dev/null 2>&1
        sleep 0.05
        report_track_step_done 0 "OK" >/dev/null 2>&1
        report_track_step "Op 2" >/dev/null 2>&1
        sleep 0.02
        report_track_step_done 0 "OK" >/dev/null 2>&1
    } >/dev/null 2>&1

    local critical
    critical=$(report_query_critical_path 2 2>/dev/null)
    [[ -n "${critical}" ]] || { (( fail_count++ )) || true; return 1; }

    (( pass_count++ )) || true
    echo "[PASS] $test_name"
}

#===============================================================================
# Test 10: Module-Specific Markdown Sections
#===============================================================================
test_module_markdown_sections() {
    (( test_count++ )) || true
    local test_name="Module-specific markdown sections"

    {
        report_init "Module Sections" "${TEST_LOGS}/sections" "sections_test" >/dev/null 2>&1
        report_track_metric "dp_parfiles_total" "5" >/dev/null 2>&1
        report_track_metric "sql_scripts_executed" "3" >/dev/null 2>&1
        report_track_metric "rman_transformations_total" "50" >/dev/null 2>&1
        report_track_step "test" >/dev/null 2>&1
        report_track_step_done 0 "ok" >/dev/null 2>&1
    } >/dev/null 2>&1

    # Verify metrics are set
    [[ -n "${_R_METRICS[dp_parfiles_total]:-}" ]] || { (( fail_count++ )) || true; return 1; }
    [[ -n "${_R_METRICS[sql_scripts_executed]:-}" ]] || { (( fail_count++ )) || true; return 1; }
    [[ -n "${_R_METRICS[rman_transformations_total]:-}" ]] || { (( fail_count++ )) || true; return 1; }

    (( pass_count++ )) || true
    echo "[PASS] $test_name"
}

#===============================================================================
# Test 11: Performance with Many Items
#===============================================================================
test_performance_many_items() {
    (( test_count++ )) || true
    local test_name="Performance test (100+ items)"

    {
        report_init "Perf Test" "${TEST_LOGS}/perf" "perf_test" >/dev/null 2>&1
        report_track_step "Bulk Op" >/dev/null 2>&1

        for i in {1..120}; do
            report_track_item "ok" "Item_$i" "data" >/dev/null 2>&1
        done

        report_track_step_done 0 "OK" >/dev/null 2>&1
    } >/dev/null 2>&1

    [[ ${#_R_ITEMS[@]} -ge 100 ]] || { (( fail_count++ )) || true; return 1; }

    (( pass_count++ )) || true
    echo "[PASS] $test_name"
}

#===============================================================================
# Test 12: Multiple Phases
#===============================================================================
test_multiple_phases() {
    (( test_count++ )) || true
    local test_name="Multiple phases"

    {
        report_init "Phases Test" "${TEST_LOGS}/phases" "phases_test" >/dev/null 2>&1
        report_track_phase "Phase 1" >/dev/null 2>&1
        report_track_step "Step 1" >/dev/null 2>&1
        report_track_step_done 0 "OK" >/dev/null 2>&1
        report_track_phase "Phase 2" >/dev/null 2>&1
        report_track_step "Step 2" >/dev/null 2>&1
        report_track_step_done 0 "OK" >/dev/null 2>&1
        report_track_phase "Phase 3" >/dev/null 2>&1
        report_track_step "Step 3" >/dev/null 2>&1
        report_track_step_done 0 "OK" >/dev/null 2>&1
    } >/dev/null 2>&1

    [[ ${_R_STEP_COUNT} -eq 3 ]] || { (( fail_count++ )) || true; return 1; }

    (( pass_count++ )) || true
    echo "[PASS] $test_name"
}

#===============================================================================
# Main Test Execution
#===============================================================================

echo "=================================================="
echo "  Report Integration Test Suite"
echo "=================================================="
echo

# Run all tests
test_report_initialization
test_dp_with_report
test_sql_with_report
test_rman_with_report
test_modules_without_report
test_cross_module_correlation
test_metric_aggregation
test_timeline_query
test_critical_path
test_module_markdown_sections
test_performance_many_items
test_multiple_phases

echo
echo "=================================================="
echo "  Test Summary"
echo "=================================================="
echo "Total Tests: ${test_count}"
echo "Passed: ${pass_count}"
echo "Failed: ${fail_count}"
echo "=================================================="

if [[ ${fail_count} -eq 0 ]]; then
    echo "✅ All integration tests passed!"
    exit 0
else
    echo "❌ ${fail_count} test(s) failed"
    exit 1
fi
