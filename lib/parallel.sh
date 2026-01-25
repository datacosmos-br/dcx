#!/usr/bin/env bash
#===============================================================================
# dcx/lib/parallel.sh - Parallel Job Execution
#===============================================================================
# Version: 0.1.1
# Dependencies: none (pure bash)
# License: MIT
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DC_PARALLEL_LOADED:-}" ]] && return 0
declare -r _DC_PARALLEL_LOADED=1

# Default max concurrent jobs
declare -g DCX_PARALLEL_MAX_JOBS="${DCX_PARALLEL_MAX_JOBS:-4}"

#-------------------------------------------------------------------------------
# parallel_run - Execute commands in parallel with job limit
#-------------------------------------------------------------------------------
# Usage: parallel_run 4 "cmd1" "cmd2" "cmd3" "cmd4" "cmd5"
# Arguments:
#   $1 - Max concurrent jobs
#   $@ - Commands to execute (as strings)
# Returns 0 if all commands succeeded, 1 otherwise.
#-------------------------------------------------------------------------------
parallel_run() {
    local max_jobs="${1:-$DCX_PARALLEL_MAX_JOBS}"
    shift

    local -a pids=()
    local -a cmds=("$@")
    local failed=0

    for cmd in "${cmds[@]}"; do
        # Wait if we've reached max jobs
        while (( ${#pids[@]} >= max_jobs )); do
            # Wait for any child to finish
            local temp_pids=()
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    temp_pids+=("$pid")
                else
                    wait "$pid" || ((failed++))
                fi
            done
            pids=("${temp_pids[@]}")

            # Small sleep to avoid busy loop
            [[ ${#pids[@]} -ge $max_jobs ]] && sleep 0.1
        done

        # Start new job
        eval "$cmd" &
        pids+=($!)
    done

    # Wait for remaining jobs
    for pid in "${pids[@]}"; do
        wait "$pid" || ((failed++))
    done

    return $((failed > 0 ? 1 : 0))
}

#-------------------------------------------------------------------------------
# parallel_map - Apply a function to items in parallel
#-------------------------------------------------------------------------------
# Usage: parallel_map 4 process_item item1 item2 item3
# Arguments:
#   $1 - Max concurrent jobs
#   $2 - Function name to call for each item
#   $@ - Items to process
#-------------------------------------------------------------------------------
parallel_map() {
    local max_jobs="$1"
    local func="$2"
    shift 2

    local -a cmds=()
    for item in "$@"; do
        cmds+=("$func \"$item\"")
    done

    parallel_run "$max_jobs" "${cmds[@]}"
}

#-------------------------------------------------------------------------------
# parallel_pipe - Process stdin lines in parallel
#-------------------------------------------------------------------------------
# Usage: cat items.txt | parallel_pipe 4 process_line
# Arguments:
#   $1 - Max concurrent jobs
#   $2 - Command/function to run for each line
# Reads lines from stdin and executes command with line as argument.
#-------------------------------------------------------------------------------
parallel_pipe() {
    local max_jobs="$1"
    local cmd="$2"

    local -a items=()
    while IFS= read -r line; do
        items+=("$line")
    done

    local -a cmds=()
    for item in "${items[@]}"; do
        cmds+=("$cmd \"$item\"")
    done

    parallel_run "$max_jobs" "${cmds[@]}"
}

#-------------------------------------------------------------------------------
# parallel_batch - Execute commands in batches
#-------------------------------------------------------------------------------
# Usage: parallel_batch 4 2 "cmd1" "cmd2" "cmd3" "cmd4" "cmd5"
# Arguments:
#   $1 - Max concurrent jobs per batch
#   $2 - Number of batches
#   $@ - Commands to distribute across batches
# Useful for rate-limited APIs or avoiding resource contention.
#-------------------------------------------------------------------------------
parallel_batch() {
    local max_jobs="$1"
    local num_batches="$2"
    shift 2

    local -a cmds=("$@")
    local batch_size=$(( (${#cmds[@]} + num_batches - 1) / num_batches ))
    local failed=0

    for ((i = 0; i < ${#cmds[@]}; i += batch_size)); do
        local -a batch=("${cmds[@]:i:batch_size}")
        parallel_run "$max_jobs" "${batch[@]}" || ((failed++))
    done

    return $((failed > 0 ? 1 : 0))
}

#-------------------------------------------------------------------------------
# parallel_wait_all - Wait for all background jobs
#-------------------------------------------------------------------------------
# Usage:
#   cmd1 & cmd2 & cmd3 &
#   parallel_wait_all
# Returns 0 if all jobs succeeded, 1 otherwise.
#-------------------------------------------------------------------------------
parallel_wait_all() {
    local failed=0
    while true; do
        local job_pid
        job_pid=$(jobs -p | head -n1)
        [[ -z "$job_pid" ]] && break
        wait "$job_pid" || ((failed++))
    done
    return $((failed > 0 ? 1 : 0))
}

#-------------------------------------------------------------------------------
# parallel_limit - Set default max concurrent jobs
#-------------------------------------------------------------------------------
# Usage: parallel_limit 8
#-------------------------------------------------------------------------------
parallel_limit() {
    DCX_PARALLEL_MAX_JOBS="$1"
}

#-------------------------------------------------------------------------------
# parallel_cpu_count - Get number of CPU cores
#-------------------------------------------------------------------------------
# Usage: cores=$(parallel_cpu_count)
#-------------------------------------------------------------------------------
parallel_cpu_count() {
    if [[ -f /proc/cpuinfo ]]; then
        grep -c ^processor /proc/cpuinfo
    elif command -v nproc &>/dev/null; then
        nproc
    elif command -v sysctl &>/dev/null; then
        sysctl -n hw.ncpu 2>/dev/null || echo 4
    else
        echo 4
    fi
}

#-------------------------------------------------------------------------------
# parallel_auto - Run with auto-detected parallelism
#-------------------------------------------------------------------------------
# Usage: parallel_auto "cmd1" "cmd2" "cmd3"
# Automatically uses number of CPU cores as max jobs.
#-------------------------------------------------------------------------------
parallel_auto() {
    local max_jobs
    max_jobs=$(parallel_cpu_count)
    parallel_run "$max_jobs" "$@"
}
