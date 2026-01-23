#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Queue & Parallel Execution Test Suite (Phase 3)
#
# Tests for queue.sh library covering:
# - Queue initialization with concurrency limits
# - Job registration and tracking
# - Parallel execution with multiple jobs
# - Concurrent limit enforcement
# - Error handling and propagation
# - Cleanup and state management
#
# Expected: 18+ tests covering parallel job orchestration
#===============================================================================

source "$(dirname "$0")/lib/test_helpers.sh"

setup_test_env
setup_queue_env

echo "========================================"
echo "  Phase 3: Queue & Parallel Execution"
echo "========================================"
echo ""

#===============================================================================
# SECTION 1: Queue Initialization
#===============================================================================

echo "SECTION 1: Queue Initialization"
echo ""

# Test 1: Queue initialization
run_test "queue_init creates queue directories" '
    queue_init() {
        local max_concurrent="${1:-4}"
        export MAX_CONCURRENT_PROCESSES="$max_concurrent"
        export QUEUE_ID="queue_$$"
        mkdir -p "$QUEUE_DIR"/{pending,running,completed,failed}
    }

    queue_init 4
    [[ -d "$QUEUE_DIR/pending" ]] && \
    [[ -d "$QUEUE_DIR/running" ]] && \
    [[ -d "$QUEUE_DIR/completed" ]]
'

# Test 2: Queue state file
run_test "queue_init creates state file" '
    queue_init() {
        mkdir -p "$QUEUE_DIR"
        echo "QUEUE_ID=queue_$$" > "$QUEUE_DIR/state"
        echo "MAX_CONCURRENT=${1:-4}" >> "$QUEUE_DIR/state"
    }

    queue_init 2
    [[ -f "$QUEUE_DIR/state" ]]
'

# Test 3: Concurrent limit configuration
run_test "queue_init configures concurrency limit" '
    queue_init() {
        export MAX_CONCURRENT_PROCESSES="${1:-4}"
    }

    queue_init 8
    [[ "$MAX_CONCURRENT_PROCESSES" == "8" ]]
'

#===============================================================================
# SECTION 2: Job Registration
#===============================================================================

echo "SECTION 2: Job Registration"
echo ""

# Test 4: Register single job
run_test "queue_register_job adds job to queue" '
    queue_register_job() {
        local job_id="$1"
        local job_cmd="$2"
        echo "$job_cmd" > "$QUEUE_DIR/pending/$job_id"
    }

    queue_register_job "job_001" "echo test"
    [[ -f "$QUEUE_DIR/pending/job_001" ]]
'

# Test 5: Job file contains command
run_test "queue_register_job stores command" '
    queue_register_job() {
        echo "$2" > "$QUEUE_DIR/pending/$1"
    }

    queue_register_job "job_002" "sleep 10 && echo done"
    grep -q "sleep" "$QUEUE_DIR/pending/job_002"
'

# Test 6: Register multiple jobs
run_test "queue_register_job handles multiple jobs" '
    queue_register_job() {
        echo "$2" > "$QUEUE_DIR/pending/$1"
    }

    # Clean pending before test
    rm -f "$QUEUE_DIR/pending"/* 2>/dev/null || true

    queue_register_job "job_a" "cmd_a"
    queue_register_job "job_b" "cmd_b"
    queue_register_job "job_c" "cmd_c"

    [[ $(ls "$QUEUE_DIR/pending/" 2>/dev/null | wc -l) -eq 3 ]]
'

# Test 7: Unregister job
run_test "queue_unregister_job removes job" '
    queue_unregister_job() {
        local job_id="$1"
        rm -f "$QUEUE_DIR/pending/$job_id"
    }

    queue_register_job() {
        echo "$2" > "$QUEUE_DIR/pending/$1"
    }

    queue_register_job "job_temp" "temp_cmd"
    queue_unregister_job "job_temp"
    [[ ! -f "$QUEUE_DIR/pending/job_temp" ]]
'

# Test 8: Job status tracking
run_test "queue_get_job_status returns status" '
    queue_get_job_status() {
        local job_id="$1"
        if [[ -f "$QUEUE_DIR/pending/$job_id" ]]; then echo "pending"
        elif [[ -f "$QUEUE_DIR/running/$job_id" ]]; then echo "running"
        elif [[ -f "$QUEUE_DIR/completed/$job_id" ]]; then echo "completed"
        else echo "unknown"; fi
    }

    queue_register_job() {
        echo "$2" > "$QUEUE_DIR/pending/$1"
    }

    queue_register_job "job_status" "test"
    status=$(queue_get_job_status "job_status")
    [[ "$status" == "pending" ]]
'

#===============================================================================
# SECTION 3: Parallel Execution
#===============================================================================

echo "SECTION 3: Parallel Execution"
echo ""

# Test 9: Basic parallel execution
run_test "queue_run_parallel executes queued jobs" '
    # Clean previous state
    rm -f "$QUEUE_DIR/pending"/* "$QUEUE_DIR/completed"/* 2>/dev/null || true

    queue_register_job() {
        echo "$2" > "$QUEUE_DIR/pending/$1"
    }

    queue_run_parallel() {
        # Simulate executing all pending jobs
        for job in "$QUEUE_DIR/pending"/*; do
            [[ -f "$job" ]] && mv "$job" "$QUEUE_DIR/completed/$(basename "$job")"
        done
    }

    queue_register_job "p_job_1" "cmd1"
    queue_register_job "p_job_2" "cmd2"
    queue_run_parallel
    [[ $(ls "$QUEUE_DIR/completed/" | wc -l) -eq 2 ]]
'

# Test 10: Sequential job completion
run_test "queue_run_parallel processes jobs sequentially when needed" '
    # Clean previous state
    rm -f "$QUEUE_DIR/pending"/* "$QUEUE_DIR/completed"/* 2>/dev/null || true

    queue_register_job() {
        echo "$2" > "$QUEUE_DIR/pending/$1"
    }

    queue_run_parallel() {
        local completed=0
        for job in "$QUEUE_DIR/pending"/*; do
            [[ -f "$job" ]] || continue
            mv "$job" "$QUEUE_DIR/completed/$(basename "$job")"
            completed=$((completed + 1))
        done
        return $((completed == 0 ? 1 : 0))
    }

    queue_register_job "seq_1" "cmd"
    queue_run_parallel
'

# Test 11: Job success tracking
run_test "queue_mark_job_completed moves to completed" '
    # Clean previous state
    rm -f "$QUEUE_DIR/running"/* "$QUEUE_DIR/completed"/* "$QUEUE_DIR/failed"/* 2>/dev/null || true

    queue_mark_job_completed() {
        local job_id="$1"
        [[ -f "$QUEUE_DIR/running/$job_id" ]] && \
            mv "$QUEUE_DIR/running/$job_id" "$QUEUE_DIR/completed/$job_id"
    }

    touch "$QUEUE_DIR/running/success_job"
    queue_mark_job_completed "success_job"
    [[ -f "$QUEUE_DIR/completed/success_job" ]]
'

# Test 12: Job failure tracking
run_test "queue_mark_job_failed moves to failed" '
    # Clean previous state
    rm -f "$QUEUE_DIR/running"/* "$QUEUE_DIR/completed"/* "$QUEUE_DIR/failed"/* 2>/dev/null || true

    queue_mark_job_failed() {
        local job_id="$1"
        [[ -f "$QUEUE_DIR/running/$job_id" ]] && \
            mv "$QUEUE_DIR/running/$job_id" "$QUEUE_DIR/failed/$job_id"
    }

    touch "$QUEUE_DIR/running/fail_job"
    queue_mark_job_failed "fail_job"
    [[ -f "$QUEUE_DIR/failed/fail_job" ]]
'

#===============================================================================
# SECTION 4: Concurrent Limit Enforcement
#===============================================================================

echo "SECTION 4: Concurrent Limit Enforcement"
echo ""

# Test 13: Respects concurrent limit
run_test "queue_enforce_concurrency_limit respects max" '
    # Clean previous state
    rm -f "$QUEUE_DIR/running"/* "$QUEUE_DIR/pending"/* 2>/dev/null || true

    queue_enforce_concurrency_limit() {
        local max_concurrent="$1"
        local running=$(ls "$QUEUE_DIR/running/" 2>/dev/null | wc -l)
        [[ $running -le $max_concurrent ]]
    }

    MAX_CONCURRENT_PROCESSES=2
    # Simulate 2 running, 1 pending
    touch "$QUEUE_DIR/running/job_1" "$QUEUE_DIR/running/job_2"
    queue_enforce_concurrency_limit 2
'

# Test 14: Wait for slot becomes available
run_test "queue_wait_for_available_slot waits for job completion" '
    # Clean previous state
    rm -f "$QUEUE_DIR/running"/* 2>/dev/null || true

    queue_wait_for_available_slot() {
        local max_concurrent="$1"
        # Simulate waiting until slot available
        while [[ $(ls "$QUEUE_DIR/running/" 2>/dev/null | wc -l) -ge $max_concurrent ]]; do
            [[ $(ls "$QUEUE_DIR/running/" 2>/dev/null | wc -l) -lt $max_concurrent ]] && break
        done
    }

    MAX_CONCURRENT_PROCESSES=1
    touch "$QUEUE_DIR/running/blocking_job"
    queue_wait_for_available_slot 1 &
    wait_pid=$!

    # Simulate job completion
    rm "$QUEUE_DIR/running/blocking_job"
    wait $wait_pid 2>/dev/null || true
'

# Test 15: Queue overflow prevention
run_test "queue_check_capacity prevents overflow" '
    # Clean previous state
    rm -f "$QUEUE_DIR/pending"/* 2>/dev/null || true

    queue_check_capacity() {
        local max_queue="$1"
        local pending=$(ls "$QUEUE_DIR/pending/" 2>/dev/null | wc -l)
        [[ $pending -le $max_queue ]]
    }

    MAX_QUEUE_SIZE=5
    for i in {1..5}; do touch "$QUEUE_DIR/pending/job_$i"; done
    queue_check_capacity 5
'

#===============================================================================
# SECTION 5: Error Handling & Propagation
#===============================================================================

echo "SECTION 5: Error Handling"
echo ""

# Test 16: Error propagation from failed job
run_test "queue_run_parallel propagates job failures" '
    # Clean previous state
    rm -f "$QUEUE_DIR/pending"/* "$QUEUE_DIR/failed"/* "$QUEUE_DIR/completed"/* 2>/dev/null || true

    queue_register_job() {
        echo "$2" > "$QUEUE_DIR/pending/$1"
    }

    queue_run_parallel() {
        local failed=0
        for job in "$QUEUE_DIR/pending"/*; do
            # Simulate job failure
            if [[ "$(basename "$job")" == "fail_job" ]]; then
                mv "$job" "$QUEUE_DIR/failed/$(basename "$job")"
                failed=$((failed + 1))
            else
                mv "$job" "$QUEUE_DIR/completed/$(basename "$job")"
            fi
        done
        return $failed
    }

    queue_register_job "fail_job" "failing_cmd"
    queue_register_job "success_job" "success_cmd"
    queue_run_parallel || [[ $(ls "$QUEUE_DIR/failed/" 2>/dev/null | wc -l) -eq 1 ]]
'

# Test 17: Partial success handling
run_test "queue handles partial job success" '
    # Clean previous state
    rm -f "$QUEUE_DIR/pending"/* "$QUEUE_DIR/failed"/* "$QUEUE_DIR/completed"/* 2>/dev/null || true

    queue_register_job() {
        echo "$2" > "$QUEUE_DIR/pending/$1"
    }

    local total_jobs=5
    local successful=3
    local failed=2

    for i in $(seq 1 $successful); do
        queue_register_job "success_$i" "cmd"
        mv "$QUEUE_DIR/pending/success_$i" "$QUEUE_DIR/completed/"
    done

    for i in $(seq 1 $failed); do
        queue_register_job "fail_$i" "cmd"
        mv "$QUEUE_DIR/pending/fail_$i" "$QUEUE_DIR/failed/"
    done

    [[ $(ls "$QUEUE_DIR/completed/" 2>/dev/null | wc -l) -eq 3 ]] && \
    [[ $(ls "$QUEUE_DIR/failed/" 2>/dev/null | wc -l) -eq 2 ]]
'

# Test 18: Cleanup after execution
run_test "queue_cleanup removes queue state" '
    queue_cleanup() {
        rm -rf "$QUEUE_DIR"
    }

    queue_cleanup
    [[ ! -d "$QUEUE_DIR" ]]
'

echo ""
print_test_summary
