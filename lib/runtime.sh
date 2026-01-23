#!/usr/bin/env bash
#===============================================================================
# dc-scripts/lib/runtime.sh - Runtime Utilities and Gum Wrappers
#===============================================================================
# Version: 0.1.1
# Dependencies: gum
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
        gum log --level error "Required command not found: $cmd"
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
        gum log --level error "Required commands not found: ${missing[*]}"
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
        gum log --level error "File not found: $file"
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
        gum log --level error "Directory not found: $dir"
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
        gum log --level error "Value is empty: $name"
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
        gum log --level error "Environment variable not set: $var"
        return 1
    }
}

#===============================================================================
# GUM WRAPPERS - Simplified interfaces
#===============================================================================

#-------------------------------------------------------------------------------
# confirm - Ask for confirmation (Yes/No)
#-------------------------------------------------------------------------------
# Usage: confirm "Are you sure?"
# Returns 0 for Yes, 1 for No.
#-------------------------------------------------------------------------------
confirm() {
    local prompt="${1:-Continue?}"
    gum confirm "$prompt"
}

#-------------------------------------------------------------------------------
# choose - Select from a list of options
#-------------------------------------------------------------------------------
# Usage: choice=$(choose "Option A" "Option B" "Option C")
# Returns selected option to stdout.
#-------------------------------------------------------------------------------
choose() {
    gum choose "$@"
}

#-------------------------------------------------------------------------------
# choose_multi - Select multiple options from a list
#-------------------------------------------------------------------------------
# Usage: choices=$(choose_multi "Option A" "Option B" "Option C")
# Returns selected options (newline separated) to stdout.
#-------------------------------------------------------------------------------
choose_multi() {
    gum choose --no-limit "$@"
}

#-------------------------------------------------------------------------------
# input - Get user input
#-------------------------------------------------------------------------------
# Usage: name=$(input "Enter your name" "default")
# Arguments:
#   $1 - Placeholder text
#   $2 - Default value (optional)
#-------------------------------------------------------------------------------
input() {
    local placeholder="${1:-}"
    local default="${2:-}"

    if [[ -n "$default" ]]; then
        gum input --placeholder "$placeholder" --value "$default"
    else
        gum input --placeholder "$placeholder"
    fi
}

#-------------------------------------------------------------------------------
# input_password - Get password input (masked)
#-------------------------------------------------------------------------------
# Usage: password=$(input_password "Enter password")
#-------------------------------------------------------------------------------
input_password() {
    local placeholder="${1:-Enter password}"
    gum input --password --placeholder "$placeholder"
}

#-------------------------------------------------------------------------------
# input_multiline - Get multiline text input
#-------------------------------------------------------------------------------
# Usage: text=$(input_multiline "Enter description")
#-------------------------------------------------------------------------------
input_multiline() {
    local placeholder="${1:-}"
    gum write --placeholder "$placeholder"
}

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
    gum spin --title "$title" -- "$@"
}

#-------------------------------------------------------------------------------
# log - Log a message with level
#-------------------------------------------------------------------------------
# Usage: log info "Starting process"
#        log warn "Something might be wrong"
#        log error "Something went wrong"
# Levels: debug, info, warn, error, fatal
#-------------------------------------------------------------------------------
log() {
    local level="$1"
    shift
    gum log --level "$level" "$@"
}

#-------------------------------------------------------------------------------
# style - Style text output
#-------------------------------------------------------------------------------
# Usage: style --bold "Important text"
#        style --foreground 212 "Pink text"
#-------------------------------------------------------------------------------
style() {
    gum style "$@"
}

#-------------------------------------------------------------------------------
# filter - Fuzzy filter a list
#-------------------------------------------------------------------------------
# Usage: selected=$(echo -e "opt1\nopt2\nopt3" | filter "Select option")
# Arguments:
#   $1 - Placeholder/prompt text
#-------------------------------------------------------------------------------
filter() {
    local placeholder="${1:-Filter...}"
    gum filter --placeholder "$placeholder"
}

#-------------------------------------------------------------------------------
# file_select - Select a file using file browser
#-------------------------------------------------------------------------------
# Usage: file=$(file_select /path/to/start)
#-------------------------------------------------------------------------------
file_select() {
    local start_dir="${1:-.}"
    gum file "$start_dir"
}

#-------------------------------------------------------------------------------
# table - Display data as table
#-------------------------------------------------------------------------------
# Usage: echo -e "Name,Age\nJohn,30\nJane,25" | table
# Note: Input should be CSV format
#-------------------------------------------------------------------------------
table() {
    gum table
}

#-------------------------------------------------------------------------------
# format_md - Render markdown
#-------------------------------------------------------------------------------
# Usage: format_md "# Title\n\nSome **bold** text"
#-------------------------------------------------------------------------------
format_md() {
    local text="$1"
    echo -e "$text" | gum format
}

#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

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
            gum log --level warn "Attempt $attempt failed, retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
        fi
    done

    gum log --level error "Command failed after $max_retries attempts"
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
        gum log --level fatal "$error_msg"
        exit 1
    fi
}
