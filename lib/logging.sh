#!/usr/bin/env bash
#===============================================================================
# dcx/lib/logging.sh - Structured Logging with Context
#===============================================================================
# Dependencies: gum (optional, falls back to echo)
# License: MIT
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DC_LOGGING_LOADED:-}" ]] && return 0
declare -r _DC_LOGGING_LOADED=1

# Log levels (numeric for comparison)
declare -gA _DC_LOG_LEVELS=(
    [debug]=0
    [info]=1
    [success]=2
    [warn]=3
    [error]=4
    [fatal]=5
)

# Default settings
declare -g DCX_LOG_LEVEL="${DCX_LOG_LEVEL:-info}"
declare -g DCX_LOG_FILE="${DCX_LOG_FILE:-}"
declare -g DCX_LOG_FORMAT="${DCX_LOG_FORMAT:-text}"  # text or json
declare -g DCX_LOG_COLOR="${DCX_LOG_COLOR:-auto}"    # auto, always, never

# Per-module log levels
declare -gA _DC_MODULE_LOG_LEVELS=()

#===============================================================================
# CORE LOGGING FUNCTIONS
#===============================================================================

#-------------------------------------------------------------------------------
# log - Main logging function with context
#-------------------------------------------------------------------------------
# Usage: log info "Starting process"
#        log error "Failed to connect" "module=network"
#-------------------------------------------------------------------------------
log() {
    local level="$1"
    shift
    local message="$*"

    # Get caller context
    local caller_func="${FUNCNAME[1]:-main}"
    local caller_file="${BASH_SOURCE[1]:-unknown}"
    local caller_line="${BASH_LINENO[0]:-0}"
    caller_file=$(basename "$caller_file")

    # Check if we should log at this level
    _dc_should_log "$level" "$caller_file" || return 0

    # Format and output
    if [[ "$DCX_LOG_FORMAT" == "json" ]]; then
        _dc_log_json "$level" "$message" "$caller_func" "$caller_file" "$caller_line"
    else
        _dc_log_text "$level" "$message" "$caller_func" "$caller_file" "$caller_line"
    fi

    # Write to file if configured
    if [[ -n "$DCX_LOG_FILE" ]]; then
        _dc_log_to_file "$level" "$message" "$caller_func" "$caller_file" "$caller_line"
    fi
}

#-------------------------------------------------------------------------------
# _dc_should_log - Check if message should be logged
#-------------------------------------------------------------------------------
_dc_should_log() {
    local level="$1"
    local module="$2"

    local current_level="$DCX_LOG_LEVEL"

    # Check module-specific level
    if [[ -n "${_DC_MODULE_LOG_LEVELS[$module]:-}" ]]; then
        current_level="${_DC_MODULE_LOG_LEVELS[$module]}"
    fi

    local level_num="${_DC_LOG_LEVELS[$level]:-1}"
    local current_num="${_DC_LOG_LEVELS[$current_level]:-1}"

    [[ $level_num -ge $current_num ]]
}

#-------------------------------------------------------------------------------
# _dc_log_text - Format log as text
#-------------------------------------------------------------------------------
_dc_log_text() {
    local level="$1" message="$2" func="$3" file="$4" line="$5"

    # Use gum if available for better formatting
    local gum_bin="${GUM:-gum}"
    if command -v "$gum_bin" &>/dev/null && [[ "$DCX_LOG_COLOR" != "never" ]]; then
        "$gum_bin" log --level "$level" "$message"
    else
        local timestamp
        timestamp=$(date '+%H:%M:%S')
        local level_upper
        level_upper=$(echo "$level" | tr '[:lower:]' '[:upper:]')
        printf "[%s] %-7s %s\n" "$timestamp" "$level_upper" "$message"
    fi
}

#-------------------------------------------------------------------------------
# _dc_log_json - Format log as JSON
#-------------------------------------------------------------------------------
_dc_log_json() {
    local level="$1" message="$2" func="$3" file="$4" line="$5"
    local timestamp
    timestamp=$(date -Iseconds)

    printf '{"timestamp":"%s","level":"%s","message":"%s","function":"%s","file":"%s","line":%s}\n' \
        "$timestamp" "$level" "$message" "$func" "$file" "$line"
}

#-------------------------------------------------------------------------------
# _dc_log_to_file - Append log to file
#-------------------------------------------------------------------------------
_dc_log_to_file() {
    local level="$1" message="$2" func="$3" file="$4" line="$5"
    local timestamp
    timestamp=$(date -Iseconds)

    printf '%s [%s] %s (%s:%s:%s)\n' \
        "$timestamp" "$level" "$message" "$file" "$func" "$line" >> "$DCX_LOG_FILE"
}

#===============================================================================
# CONVENIENCE LOG FUNCTIONS
#===============================================================================

log_debug()   { log debug "$@"; }
log_info()    { log info "$@"; }
log_success() { log success "$@"; }
log_warn()    { log warn "$@"; }
log_error()   { log error "$@"; }
log_fatal()   { log fatal "$@"; exit 1; }

# Aliases (for compatibility)
warn() { log warn "$@"; }
die()  { log fatal "$@"; exit 1; }

#===============================================================================
# LOG CONFIGURATION
#===============================================================================

#-------------------------------------------------------------------------------
# log_set_level - Set global log level
#-------------------------------------------------------------------------------
log_set_level() {
    local level="$1"
    if [[ -n "${_DC_LOG_LEVELS[$level]:-}" ]]; then
        DCX_LOG_LEVEL="$level"
    else
        log error "Unknown log level: $level"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# log_set_module_level - Set log level for specific module
#-------------------------------------------------------------------------------
log_set_module_level() {
    local module="$1"
    local level="$2"

    if [[ -n "${_DC_LOG_LEVELS[$level]:-}" ]]; then
        _DC_MODULE_LOG_LEVELS[$module]="$level"
    else
        log error "Unknown log level: $level"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# log_get_module_level - Get log level for module
#-------------------------------------------------------------------------------
log_get_module_level() {
    local module="$1"
    echo "${_DC_MODULE_LOG_LEVELS[$module]:-$DCX_LOG_LEVEL}"
}

#-------------------------------------------------------------------------------
# log_init_file - Initialize logging to file
#-------------------------------------------------------------------------------
log_init_file() {
    local file="$1"
    local dir
    dir=$(dirname "$file")

    mkdir -p "$dir" || {
        log error "Cannot create log directory: $dir"
        return 1
    }

    DCX_LOG_FILE="$file"
    log_info "Logging to file: $file"
}

#===============================================================================
# PROGRESS & STEP LOGGING
#===============================================================================

#-------------------------------------------------------------------------------
# log_phase - Log start of a phase
#-------------------------------------------------------------------------------
log_phase() {
    local phase="$1"
    local description="${2:-}"
    local gum_bin="${GUM:-gum}"

    if command -v "$gum_bin" &>/dev/null; then
        "$gum_bin" style --bold --foreground 212 "=== Phase: $phase ==="
        [[ -n "$description" ]] && echo "    $description"
    else
        echo "=== Phase: $phase ==="
        [[ -n "$description" ]] && echo "    $description"
    fi
}

#-------------------------------------------------------------------------------
# log_step - Log a step
#-------------------------------------------------------------------------------
log_step() {
    local step="$1"
    log_info "→ $step"
}

#-------------------------------------------------------------------------------
# log_step_done - Log step completion
#-------------------------------------------------------------------------------
log_step_done() {
    local step="$1"
    log_success "✓ $step"
}

#-------------------------------------------------------------------------------
# log_progress - Log progress (n of total)
#-------------------------------------------------------------------------------
log_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing}"

    local percent=$((current * 100 / total))
    printf "\r[%3d%%] %s (%d/%d)" "$percent" "$message" "$current" "$total"

    [[ $current -eq $total ]] && echo ""
}

#===============================================================================
# COMMAND LOGGING
#===============================================================================

#-------------------------------------------------------------------------------
# log_cmd - Log and execute a command
#-------------------------------------------------------------------------------
log_cmd() {
    local cmd="$*"
    log_debug "Executing: $cmd"

    local start_time
    start_time=$(date +%s)

    if "$@"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_debug "Command completed in ${duration}s"
        return 0
    else
        local exit_code=$?
        log_error "Command failed with exit code $exit_code: $cmd"
        return $exit_code
    fi
}

#-------------------------------------------------------------------------------
# log_cmd_start - Log start of a long-running command
#-------------------------------------------------------------------------------
log_cmd_start() {
    local description="$1"
    log_info "Starting: $description"
}

#-------------------------------------------------------------------------------
# log_cmd_end - Log end of a long-running command
#-------------------------------------------------------------------------------
log_cmd_end() {
    local description="$1"
    local status="${2:-success}"

    if [[ "$status" == "success" ]]; then
        log_success "Completed: $description"
    else
        log_error "Failed: $description"
    fi
}

#===============================================================================
# OUTPUT HELPERS
#===============================================================================

#-------------------------------------------------------------------------------
# log_separator - Print a separator line
#-------------------------------------------------------------------------------
log_separator() {
    local char="${1:--}"
    local width="${2:-60}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

#-------------------------------------------------------------------------------
# log_kv - Log key-value pair
#-------------------------------------------------------------------------------
log_kv() {
    local key="$1"
    local value="$2"
    local width="${3:-20}"

    printf "%-${width}s : %s\n" "$key" "$value"
}

#-------------------------------------------------------------------------------
# log_section - Log a section header
#-------------------------------------------------------------------------------
log_section() {
    local title="$1"
    echo ""
    log_separator "="
    echo " $title"
    log_separator "="
}
