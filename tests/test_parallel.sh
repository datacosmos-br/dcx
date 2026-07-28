#!/usr/bin/env bash
#===============================================================================
# test_parallel.sh - Tests for lib/parallel.sh
#===============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Setup
test_setup

# Test helper functions
write_file() {
    local name="$1"
    echo "$name" >> "${TMP_DIR}/output.txt"
}
export -f write_file
export TMP_DIR

# Source parallel module (core.sh is auto-sourced by test_helpers.sh)
source "${LIB_DIR}/parallel.sh"

#-------------------------------------------------------------------------------
# Test Groups
#-------------------------------------------------------------------------------

test_module_loading() {
    run_test "parallel.sh loads" "true"
    run_test "_DCX_PARALLEL_LOADED set" "[[ -n \"\${_DCX_PARALLEL_LOADED:-}\" ]]"
}

test_functions_exist() {
    run_test "parallel_run exists" "type parallel_run &>/dev/null"
    run_test "parallel_map exists" "type parallel_map &>/dev/null"
    run_test "parallel_pipe exists" "type parallel_pipe &>/dev/null"
    run_test "parallel_batch exists" "type parallel_batch &>/dev/null"
    run_test "parallel_wait_all exists" "type parallel_wait_all &>/dev/null"
    run_test "parallel_limit exists" "type parallel_limit &>/dev/null"
    run_test "parallel_cpu_count exists" "type parallel_cpu_count &>/dev/null"
    run_test "parallel_auto exists" "type parallel_auto &>/dev/null"
}

test_defaults_and_limit() {
    run_test "default max jobs" "[[ \"\$DCX_PARALLEL_MAX_JOBS\" == \"4\" ]]"

    parallel_limit 8
    run_test "parallel_limit" "[[ \"\$DCX_PARALLEL_MAX_JOBS\" == \"8\" ]]"
    parallel_limit 4

    cpu_count=$(parallel_cpu_count)
    run_test "parallel_cpu_count" "[[ \"$cpu_count\" =~ ^[0-9]+$ ]]"
}

test_parallel_run() {
    rm -f "${TMP_DIR}/output.txt"
    parallel_run 2 \
        "echo 'a' >> '${TMP_DIR}/output.txt'" \
        "echo 'b' >> '${TMP_DIR}/output.txt'" \
        "echo 'c' >> '${TMP_DIR}/output.txt'"
    count=$(wc -l < "${TMP_DIR}/output.txt")
    run_test "parallel_run executes all" "[[ \"$count\" == \"3\" ]]"

    rm -f "${TMP_DIR}/output.txt"
    parallel_run 2 \
        "echo '1' >> '${TMP_DIR}/output.txt'" \
        "echo '2' >> '${TMP_DIR}/output.txt'" \
        "echo '3' >> '${TMP_DIR}/output.txt'" \
        "echo '4' >> '${TMP_DIR}/output.txt'" \
        "echo '5' >> '${TMP_DIR}/output.txt'"
    count=$(wc -l < "${TMP_DIR}/output.txt")
    run_test "parallel_run many jobs" "[[ \"$count\" == \"5\" ]]"

    run_test "parallel_run failure" "! parallel_run 2 'true' 'false' 'true'"
    run_test "parallel_run success" "parallel_run 2 'true' 'true' 'true'"
}

test_parallel_map() {
    rm -f "${TMP_DIR}/output.txt"
    parallel_map 2 write_file "item1" "item2" "item3"
    count=$(wc -l < "${TMP_DIR}/output.txt")
    run_test "parallel_map" "[[ \"$count\" == \"3\" ]]"
}

test_parallel_pipe() {
    rm -f "${TMP_DIR}/output.txt"
    echo -e "line1\nline2\nline3" | parallel_pipe 2 "echo >> '${TMP_DIR}/output.txt'"
    count=$(wc -l < "${TMP_DIR}/output.txt")
    run_test "parallel_pipe" "[[ \"$count\" == \"3\" ]]"
}

test_parallel_batch() {
    rm -f "${TMP_DIR}/output.txt"
    parallel_batch 2 2 \
        "echo 'b1' >> '${TMP_DIR}/output.txt'" \
        "echo 'b2' >> '${TMP_DIR}/output.txt'" \
        "echo 'b3' >> '${TMP_DIR}/output.txt'" \
        "echo 'b4' >> '${TMP_DIR}/output.txt'"
    count=$(wc -l < "${TMP_DIR}/output.txt")
    run_test "parallel_batch" "[[ \"$count\" == \"4\" ]]"
}

test_parallel_wait_and_auto() {
    rm -f "${TMP_DIR}/output.txt"
    echo "bg1" >> "${TMP_DIR}/output.txt" &
    echo "bg2" >> "${TMP_DIR}/output.txt" &
    parallel_wait_all
    count=$(wc -l < "${TMP_DIR}/output.txt")
    run_test "parallel_wait_all" "[[ \"$count\" == \"2\" ]]"

    rm -f "${TMP_DIR}/output.txt"
    parallel_auto \
        "echo 'auto1' >> '${TMP_DIR}/output.txt'" \
        "echo 'auto2' >> '${TMP_DIR}/output.txt'"
    count=$(wc -l < "${TMP_DIR}/output.txt")
    run_test "parallel_auto" "[[ \"$count\" == \"2\" ]]"
}

#-------------------------------------------------------------------------------
# Run Tests
#-------------------------------------------------------------------------------

describe "Module Loading" test_module_loading
describe "Functions Exist" test_functions_exist
describe "Defaults and Limit" test_defaults_and_limit
describe "Parallel Run" test_parallel_run
describe "Parallel Map" test_parallel_map
describe "Parallel Pipe" test_parallel_pipe
describe "Parallel Batch" test_parallel_batch
describe "Wait and Auto" test_parallel_wait_and_auto

test_summary
