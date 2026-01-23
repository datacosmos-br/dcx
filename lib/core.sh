#!/usr/bin/env bash
#===============================================================================
# dc-scripts/lib/core.sh - Bootstrap, Module System & Plugin Management
#===============================================================================
# Dependencies: gum, yq
# License: MIT
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DC_CORE_LOADED:-}" ]] && return 0
declare -r _DC_CORE_LOADED=1

# Version - read from VERSION file
declare -r DC_VERSION="$(cat "${DC_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/VERSION" 2>/dev/null || echo "unknown")"

# Paths
declare -g DC_HOME="${DC_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
declare -g DC_LIB_DIR="${DC_HOME}/lib"
declare -g DC_BIN_DIR="${DC_HOME}/bin"
declare -g DC_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dc-scripts"

# Module registry (associative arrays)
declare -gA _DC_MODULE_DEPS=()      # module -> "dep1 dep2 dep3"
declare -gA _DC_MODULE_FILES=()     # module -> file path
declare -gA _DC_MODULE_LOADED=()    # module -> 1 if loaded

#===============================================================================
# INITIALIZATION
#===============================================================================

#-------------------------------------------------------------------------------
# dc_init - Initialize dc-scripts environment
#-------------------------------------------------------------------------------
dc_init() {
    # Already initialized?
    [[ "${DC_INITIALIZED:-}" == "1" ]] && return 0

    # Add bin/ to PATH if exists
    if [[ -d "$DC_BIN_DIR" ]]; then
        export PATH="$DC_BIN_DIR:$PATH"
    fi

    # Check dependencies (gum, yq)
    _dc_check_binary gum || return 1
    _dc_check_binary yq || return 1

    # Register built-in modules
    _dc_register_builtin_modules

    # Create config dir if needed
    mkdir -p "$DC_CONFIG_DIR"

    export DC_VERSION DC_HOME DC_INITIALIZED=1
    return 0
}

#-------------------------------------------------------------------------------
# _dc_check_binary - Check if binary exists (use bundled if available)
#-------------------------------------------------------------------------------
_dc_check_binary() {
    local name="$1"
    local platform_bin

    # Try platform-specific bundled binary first
    platform_bin="$DC_BIN_DIR/${name}-$(_dc_platform)"
    if [[ -x "$platform_bin" ]]; then
        return 0
    fi

    # Try generic bundled binary
    if [[ -x "$DC_BIN_DIR/$name" ]]; then
        return 0
    fi

    # Try system binary
    if command -v "$name" &>/dev/null; then
        return 0
    fi

    echo "ERROR: $name not found" >&2
    echo "Install: brew install $name | https://github.com/charmbracelet/$name" >&2
    return 1
}

#-------------------------------------------------------------------------------
# _dc_platform - Get current platform string
#-------------------------------------------------------------------------------
_dc_platform() {
    local os arch
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
    esac
    echo "${os}-${arch}"
}

#-------------------------------------------------------------------------------
# dc_require - Ensure dc-scripts is initialized
#-------------------------------------------------------------------------------
dc_require() {
    [[ "${DC_INITIALIZED:-}" == "1" ]] || dc_init
}

#-------------------------------------------------------------------------------
# dc_version - Print version information
#-------------------------------------------------------------------------------
dc_version() {
    echo "DCX v${DC_VERSION}"
}

#===============================================================================
# MODULE REGISTRY SYSTEM
#===============================================================================

#-------------------------------------------------------------------------------
# _dc_register_builtin_modules - Register all built-in modules
#-------------------------------------------------------------------------------
_dc_register_builtin_modules() {
    # Layer 0: No dependencies
    core_register_module "logging" "$DC_LIB_DIR/logging.sh" ""
    core_register_module "shared" "$DC_LIB_DIR/shared.sh" ""

    # Layer 1: Depends on logging
    core_register_module "runtime" "$DC_LIB_DIR/runtime.sh" "logging"

    # Layer 2: Depends on runtime
    core_register_module "config" "$DC_LIB_DIR/config.sh" "runtime"
    core_register_module "parallel" "$DC_LIB_DIR/parallel.sh" "runtime"

    # Layer 3: Depends on config
    core_register_module "report" "$DC_LIB_DIR/report.sh" "config"
    core_register_module "update" "$DC_LIB_DIR/update.sh" "config"
    core_register_module "plugin" "$DC_LIB_DIR/plugin.sh" "config"
}

#-------------------------------------------------------------------------------
# core_register_module - Register a module with its dependencies
#-------------------------------------------------------------------------------
# Usage: core_register_module "name" "/path/to/module.sh" "dep1 dep2"
#-------------------------------------------------------------------------------
core_register_module() {
    local name="$1"
    local file="$2"
    local deps="${3:-}"

    _DC_MODULE_FILES[$name]="$file"
    _DC_MODULE_DEPS[$name]="$deps"
}

#-------------------------------------------------------------------------------
# core_load - Load a module with dependency resolution
#-------------------------------------------------------------------------------
# Usage: core_load config runtime
#-------------------------------------------------------------------------------
core_load() {
    for module in "$@"; do
        _dc_load_module "$module" || return 1
    done
}

#-------------------------------------------------------------------------------
# _dc_load_module - Internal: Load a single module with deps
#-------------------------------------------------------------------------------
_dc_load_module() {
    local module="$1"

    # Already loaded?
    [[ "${_DC_MODULE_LOADED[$module]:-}" == "1" ]] && return 0

    # Check if registered
    local file="${_DC_MODULE_FILES[$module]:-}"
    if [[ -z "$file" ]]; then
        echo "ERROR: Unknown module: $module" >&2
        return 1
    fi

    # Check if file exists
    if [[ ! -f "$file" ]]; then
        # Module might not be implemented yet, skip silently
        return 0
    fi

    # Load dependencies first
    local deps="${_DC_MODULE_DEPS[$module]:-}"
    for dep in $deps; do
        _dc_load_module "$dep" || return 1
    done

    # Load the module
    # shellcheck source=/dev/null
    source "$file" || {
        echo "ERROR: Failed to load module: $module ($file)" >&2
        return 1
    }

    _DC_MODULE_LOADED[$module]=1
    return 0
}

#-------------------------------------------------------------------------------
# core_require - Ensure modules are loaded (idempotent)
#-------------------------------------------------------------------------------
# Usage: core_require config runtime
#-------------------------------------------------------------------------------
core_require() {
    dc_require || return 1
    core_load "$@"
}

#-------------------------------------------------------------------------------
# core_list_modules - List all registered modules
#-------------------------------------------------------------------------------
core_list_modules() {
    for module in "${!_DC_MODULE_FILES[@]}"; do
        local status="not loaded"
        [[ "${_DC_MODULE_LOADED[$module]:-}" == "1" ]] && status="loaded"
        local file="${_DC_MODULE_FILES[$module]}"
        local deps="${_DC_MODULE_DEPS[$module]:-none}"
        printf "%-12s %-50s [deps: %s] (%s)\n" "$module" "$file" "$deps" "$status"
    done | sort
}

#-------------------------------------------------------------------------------
# core_module_info - Show detailed info about a module
#-------------------------------------------------------------------------------
core_module_info() {
    local module="$1"
    local file="${_DC_MODULE_FILES[$module]:-}"

    if [[ -z "$file" ]]; then
        echo "ERROR: Unknown module: $module" >&2
        return 1
    fi

    echo "Module: $module"
    echo "File: $file"
    echo "Dependencies: ${_DC_MODULE_DEPS[$module]:-none}"
    echo "Loaded: ${_DC_MODULE_LOADED[$module]:-no}"
    echo "Exists: $([[ -f "$file" ]] && echo "yes" || echo "no")"
}

#-------------------------------------------------------------------------------
# core_get_loaded_modules - Get list of loaded modules
#-------------------------------------------------------------------------------
core_get_loaded_modules() {
    for module in "${!_DC_MODULE_LOADED[@]}"; do
        [[ "${_DC_MODULE_LOADED[$module]}" == "1" ]] && echo "$module"
    done | sort
}

#===============================================================================
# CONVENIENCE FUNCTIONS
#===============================================================================

#-------------------------------------------------------------------------------
# dc_source - Source a dc-scripts module (legacy compatibility)
#-------------------------------------------------------------------------------
dc_source() {
    core_load "$@"
}

#-------------------------------------------------------------------------------
# dc_load - Load all essential modules
#-------------------------------------------------------------------------------
dc_load() {
    dc_require || return 1
    core_load logging runtime config parallel
}

#-------------------------------------------------------------------------------
# dc_load_all - Load all available modules
#-------------------------------------------------------------------------------
dc_load_all() {
    dc_require || return 1
    for module in "${!_DC_MODULE_FILES[@]}"; do
        core_load "$module" 2>/dev/null || true
    done
}

#===============================================================================
# AUTO-INITIALIZATION
#===============================================================================

# Auto-initialize when sourced (can be disabled with DC_AUTO_INIT=0)
if [[ "${DC_AUTO_INIT:-1}" == "1" ]]; then
    dc_init || true
fi
