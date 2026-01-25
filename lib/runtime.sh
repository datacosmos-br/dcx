#!/usr/bin/env bash
#===============================================================================
# dcx/lib/runtime.sh - Runtime Utilities
#===============================================================================
# License: MIT
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DC_RUNTIME_LOADED:-}" ]] && return 0
declare -r _DC_RUNTIME_LOADED=1

#===============================================================================
# VALIDATORS
#===============================================================================

#-------------------------------------------------------------------------------
# need_cmd - Verify a command exists
#-------------------------------------------------------------------------------
# Usage: need_cmd docker
# Returns 0 if command exists, 1 otherwise.
#-------------------------------------------------------------------------------
need_cmd() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null || {
        echo "ERROR: Required command not found: $cmd" >&2
        return 1
    }
}

#-------------------------------------------------------------------------------
# need_cmds - Verify multiple commands exist
#-------------------------------------------------------------------------------
# Usage: need_cmds docker kubectl helm
# Returns 0 if all commands exist, 1 otherwise.
#-------------------------------------------------------------------------------
need_cmds() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Required commands not found: ${missing[*]}" >&2
        return 1
    fi
}

#-------------------------------------------------------------------------------
# assert_file - Verify a file exists
#-------------------------------------------------------------------------------
# Usage: assert_file /path/to/file
#-------------------------------------------------------------------------------
assert_file() {
    local file="$1"
    [[ -f "$file" ]] || {
        echo "ERROR: File not found: $file" >&2
        return 1
    }
}

#-------------------------------------------------------------------------------
# assert_dir - Verify a directory exists
#-------------------------------------------------------------------------------
# Usage: assert_dir /path/to/dir
#-------------------------------------------------------------------------------
assert_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || {
        echo "ERROR: Directory not found: $dir" >&2
        return 1
    }
}

#-------------------------------------------------------------------------------
# assert_nonempty - Verify a variable is not empty
#-------------------------------------------------------------------------------
# Usage: assert_nonempty "$VAR" "VAR"
#-------------------------------------------------------------------------------
assert_nonempty() {
    local value="$1"
    local name="${2:-value}"
    [[ -n "$value" ]] || {
        echo "ERROR: Value is empty: $name" >&2
        return 1
    }
}

#-------------------------------------------------------------------------------
# assert_var - Verify an environment variable is set
#-------------------------------------------------------------------------------
# Usage: assert_var HOME
#-------------------------------------------------------------------------------
assert_var() {
    local var="$1"
    local value="${!var:-}"
    [[ -n "$value" ]] || {
        echo "ERROR: Environment variable not set: $var" >&2
        return 1
    }
}

#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

#-------------------------------------------------------------------------------
# spin - Execute command with spinner
#-------------------------------------------------------------------------------
# Usage: spin "Loading..." sleep 2
# Arguments:
#   $1 - Spinner title
#   $@ - Command to execute
#-------------------------------------------------------------------------------
spin() {
    local title="$1"
    shift
    local gum_bin="${GUM:-gum}"
    if command -v "$gum_bin" &>/dev/null && [[ -t 1 ]]; then
        "$gum_bin" spin --title "$title" -- "$@"
    else
        echo "$title"
        "$@"
    fi
}

#-------------------------------------------------------------------------------
# retry - Retry a command with exponential backoff
#-------------------------------------------------------------------------------
# Usage: retry 3 5 some_command arg1 arg2
# Arguments:
#   $1 - Max retries
#   $2 - Initial delay (seconds)
#   $@ - Command to execute
#-------------------------------------------------------------------------------
retry() {
    local max_retries="$1"
    local delay="$2"
    shift 2

    local attempt=0
    while (( attempt < max_retries )); do
        if "$@"; then
            return 0
        fi
        ((attempt++))
        if (( attempt < max_retries )); then
            echo "WARN: Attempt $attempt failed, retrying in ${delay}s..." >&2
            sleep "$delay"
            delay=$((delay * 2))
        fi
    done

    echo "ERROR: Command failed after $max_retries attempts" >&2
    return 1
}

#-------------------------------------------------------------------------------
# timeout_cmd - Run command with timeout
#-------------------------------------------------------------------------------
# Usage: timeout_cmd 30 some_command arg1 arg2
# Arguments:
#   $1 - Timeout in seconds
#   $@ - Command to execute
#-------------------------------------------------------------------------------
timeout_cmd() {
    local timeout_secs="$1"
    shift
    timeout "$timeout_secs" "$@"
}

#-------------------------------------------------------------------------------
# run_silent - Run command silently (no output)
#-------------------------------------------------------------------------------
# Usage: run_silent some_command
# Returns exit code of command.
#-------------------------------------------------------------------------------
run_silent() {
    "$@" &>/dev/null
}

#-------------------------------------------------------------------------------
# run_or_die - Run command or exit with error
#-------------------------------------------------------------------------------
# Usage: run_or_die "Failed to start service" systemctl start myservice
# Arguments:
#   $1 - Error message if command fails
#   $@ - Command to execute
#-------------------------------------------------------------------------------
run_or_die() {
    local error_msg="$1"
    shift

    if ! "$@"; then
        echo "FATAL: $error_msg" >&2
        exit 1
    fi
}
