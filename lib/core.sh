#!/usr/bin/env bash
#===============================================================================
# dcx/lib/core.sh - Module System
#===============================================================================
# Requires: Go binary (dcx-go) for platform detection and binary discovery
#===============================================================================

[[ -n "${_DC_CORE_LOADED:-}" ]] && return 0
declare -r _DC_CORE_LOADED=1

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

declare -gA _DC_MODULE_FILES=()
declare -gA _DC_MODULE_DEPS=()
declare -gA _DC_MODULE_LOADED=()

core_register_module() {
    local name="$1" file="$2" deps="${3:-}"
    _DC_MODULE_FILES[$name]="$file"
    _DC_MODULE_DEPS[$name]="$deps"
}

core_load() {
    for module in "$@"; do
        _dc_load_module "$module" || return 1
    done
}

_dc_load_module() {
    local module="$1"
    [[ "${_DC_MODULE_LOADED[$module]:-}" == "1" ]] && return 0
    local file="${_DC_MODULE_FILES[$module]:-}"
    [[ -z "$file" ]] && { echo "ERROR: Unknown module: $module" >&2; return 1; }
    [[ ! -f "$file" ]] && return 0
    local deps="${_DC_MODULE_DEPS[$module]:-}"
    for dep in $deps; do
        _dc_load_module "$dep" || return 1
    done
    source "$file" || { echo "ERROR: Failed to load: $module" >&2; return 1; }
    _DC_MODULE_LOADED[$module]=1
}

core_require() { dc_init; core_load "$@"; }
dc_require() { dc_init; }
dc_source() { core_load "$@"; }

#===============================================================================
# INITIALIZATION
#===============================================================================

_dc_register_builtin_modules() {
    core_register_module "logging" "$DCX_LIB_DIR/logging.sh" ""
    core_register_module "runtime" "$DCX_LIB_DIR/runtime.sh" "logging"
    core_register_module "config" "$DCX_LIB_DIR/config.sh" "runtime"
    core_register_module "parallel" "$DCX_LIB_DIR/parallel.sh" "runtime"
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
    core_load logging runtime config parallel
}

[[ "${DCX_AUTO_INIT:-1}" == "1" ]] && dc_init || true
