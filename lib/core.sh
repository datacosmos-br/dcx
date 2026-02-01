#!/usr/bin/env bash
#===============================================================================
# dcx/lib/core.sh - Module System
#===============================================================================
# Requires: Go binary (dcx-go) for platform detection and binary discovery
#===============================================================================

[[ -n "${_DCX_CORE_LOADED:-}" ]] && return 0
declare -r _DCX_CORE_LOADED=1

#===============================================================================
# PATHS
#===============================================================================

DCX_HOME="${DCX_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DCX_LIB_DIR="${DCX_HOME}/lib"
DCX_BIN_DIR="${DCX_HOME}/bin"
DCX_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dcx"

export DCX_HOME DCX_LIB_DIR DCX_BIN_DIR DCX_CONFIG_DIR

#===============================================================================
# GO BINARY (REQUIRED)
#===============================================================================

# Find Go binary - REQUIRED for dcx to work
_dc_go_binary() {
    local platform
    platform="$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
    [[ -x "$DCX_BIN_DIR/dcx-${platform}" ]] && echo "$DCX_BIN_DIR/dcx-${platform}" && return 0
    [[ -x "$DCX_BIN_DIR/dcx-go" ]] && echo "$DCX_BIN_DIR/dcx-go" && return 0
    return 1
}

DCX_GO=$(_dc_go_binary) || {
    echo "ERROR: Go binary not found. Run 'scripts/build.sh' first." >&2
    return 1
}

# Platform detection via Go
dc_detect_platform() {
    "$DCX_GO" config get platform
}

# Set platform variable (used by other modules)
DCX_PLATFORM=$(dc_detect_platform)
export DCX_PLATFORM

# Binary discovery via Go
_dc_find_binary() {
    "$DCX_GO" binary find "$1" 2>/dev/null
}

# Binary check with error message
_dc_check_binary() {
    local name="$1"
    if "$DCX_GO" binary find "$name" &>/dev/null; then
        return 0
    fi
    echo "ERROR: $name not found. Run 'dcx tools install $name'" >&2
    return 1
}

# Confirmation with gum
dc_confirm() {
    local prompt="$1"
    local gum_bin
    gum_bin=$(_dc_find_binary gum) || gum_bin=""
    if [[ -n "$gum_bin" && -t 0 && -t 1 ]]; then
        "$gum_bin" confirm "$prompt"
    else
        read -r -p "$prompt [y/N] " response
        [[ "$response" =~ ^[Yy] ]]
    fi
}

#===============================================================================
# MODULE SYSTEM
#===============================================================================

declare -gA _DCX_MODULE_FILES=()
declare -gA _DCX_MODULE_DEPS=()
declare -gA _DCX_MODULE_LOADED=()

core_register_module() {
    local name="$1" file="$2" deps="${3:-}"
    _DCX_MODULE_FILES[$name]="$file"
    _DCX_MODULE_DEPS[$name]="$deps"
}

core_load() {
    for module in "$@"; do
        _dc_load_module "$module" || return 1
    done
}

_dc_load_module() {
    local module="$1"
    [[ "${_DCX_MODULE_LOADED[$module]:-}" == "1" ]] && return 0
    local file="${_DCX_MODULE_FILES[$module]:-}"
    [[ -z "$file" ]] && { echo "ERROR: Unknown module: $module" >&2; return 1; }
    [[ ! -f "$file" ]] && return 0
    local deps="${_DCX_MODULE_DEPS[$module]:-}"
    for dep in $deps; do
        _dc_load_module "$dep" || return 1
    done
    source "$file" || { echo "ERROR: Failed to load: $module" >&2; return 1; }
    _DCX_MODULE_LOADED[$module]=1
}

core_require() { dc_init; core_load "$@"; }
dc_require() { dc_init; }
dc_source() { core_load "$@"; }

#===============================================================================
# INITIALIZATION
#===============================================================================

_dc_register_builtin_modules() {
    core_register_module "logging" "$DCX_LIB_DIR/logging.sh" ""
    # runtime.sh merged into core.sh - all functions available via core.sh with core_ prefix
    core_register_module "config" "$DCX_LIB_DIR/config.sh" "logging"
    core_register_module "parallel" "$DCX_LIB_DIR/parallel.sh" "logging"
    core_register_module "plugin" "$DCX_LIB_DIR/plugin.sh" "config"
    core_register_module "shared" "$DCX_LIB_DIR/shared.sh" ""
}

dc_init() {
    [[ "${DCX_INITIALIZED:-}" == "1" ]] && return 0
    _dc_register_builtin_modules
    mkdir -p "$DCX_CONFIG_DIR" 2>/dev/null || true
    DCX_VERSION=$(cat "$DCX_HOME/VERSION" 2>/dev/null || echo "0.0.0")
    export DCX_VERSION DCX_INITIALIZED=1
}

dc_version() { echo "dcx v${DCX_VERSION}"; }

dc_load() {
    dc_init
    core_load logging config parallel
}

#===============================================================================
# RUNTIME UTILITIES
#===============================================================================

#-------------------------------------------------------------------------------
# core_need_cmd - Verify a command exists
#-------------------------------------------------------------------------------
# Usage: core_need_cmd docker
# Returns 0 if command exists, 1 otherwise.
#-------------------------------------------------------------------------------
core_need_cmd() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null || {
        echo "ERROR: Required command not found: $cmd" >&2
        return 1
    }
}

#-------------------------------------------------------------------------------
# core_need_cmds - Verify multiple commands exist
#-------------------------------------------------------------------------------
# Usage: core_need_cmds docker kubectl helm
# Returns 0 if all commands exist, 1 otherwise.
#-------------------------------------------------------------------------------
core_need_cmds() {
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
# core_assert_file - Verify a file exists
#-------------------------------------------------------------------------------
# Usage: core_assert_file /path/to/file
#-------------------------------------------------------------------------------
core_assert_file() {
    local file="$1"
    [[ -f "$file" ]] || {
        echo "ERROR: File not found: $file" >&2
        return 1
    }
}

#-------------------------------------------------------------------------------
# core_assert_dir - Verify a directory exists
#-------------------------------------------------------------------------------
# Usage: core_assert_dir /path/to/dir
#-------------------------------------------------------------------------------
core_assert_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || {
        echo "ERROR: Directory not found: $dir" >&2
        return 1
    }
}

#-------------------------------------------------------------------------------
# core_assert_nonempty - Verify a variable is not empty
#-------------------------------------------------------------------------------
# Usage: core_assert_nonempty "$VAR" "VAR"
#-------------------------------------------------------------------------------
core_assert_nonempty() {
    local value="$1"
    local name="${2:-value}"
    [[ -n "$value" ]] || {
        echo "ERROR: Value is empty: $name" >&2
        return 1
    }
}

#-------------------------------------------------------------------------------
# core_assert_var - Verify an environment variable is set
#-------------------------------------------------------------------------------
# Usage: core_assert_var HOME
#-------------------------------------------------------------------------------
core_assert_var() {
    local var="$1"
    local value="${!var:-}"
    [[ -n "$value" ]] || {
        echo "ERROR: Environment variable not set: $var" >&2
        return 1
    }
}

#-------------------------------------------------------------------------------
# core_spin - Execute command with spinner
#-------------------------------------------------------------------------------
# Usage: core_spin "Loading..." sleep 2
# Arguments:
#   $1 - Spinner title
#   $@ - Command to execute
#-------------------------------------------------------------------------------
core_spin() {
    local title="$1"
    shift
    local gum_bin
    gum_bin=$(_dc_find_binary gum) || gum_bin=""
    if [[ -n "$gum_bin" && -t 0 && -t 1 ]]; then
        "$gum_bin" spin --title "$title" -- "$@"
    else
        echo "$title"
        "$@"
    fi
}

#-------------------------------------------------------------------------------
# core_retry - Retry a command with exponential backoff
#-------------------------------------------------------------------------------
# Usage: core_retry 3 5 some_command arg1 arg2
# Arguments:
#   $1 - Max retries
#   $2 - Initial delay (seconds)
#   $@ - Command to execute
#-------------------------------------------------------------------------------
core_retry() {
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
# core_timeout_cmd - Run command with timeout
#-------------------------------------------------------------------------------
# Usage: core_timeout_cmd 30 some_command arg1 arg2
# Arguments:
#   $1 - Timeout in seconds
#   $@ - Command to execute
#-------------------------------------------------------------------------------
core_timeout_cmd() {
    local timeout_secs="$1"
    shift
    timeout "$timeout_secs" "$@"
}

#-------------------------------------------------------------------------------
# core_run_silent - Run command silently (no output)
#-------------------------------------------------------------------------------
# Usage: core_run_silent some_command
# Returns exit code of command.
#-------------------------------------------------------------------------------
core_run_silent() {
    "$@" &>/dev/null
}

#-------------------------------------------------------------------------------
# core_run_or_die - Run command or exit with error
#-------------------------------------------------------------------------------
# Usage: core_run_or_die "Failed to start service" systemctl start myservice
# Arguments:
#   $1 - Error message if command fails
#   $@ - Command to execute
#-------------------------------------------------------------------------------
core_run_or_die() {
    local error_msg="$1"
    shift

    if ! "$@"; then
        echo "FATAL: $error_msg" >&2
        exit 1
    fi
}

[[ "${DCX_AUTO_INIT:-1}" == "1" ]] && dc_init || true
