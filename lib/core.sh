#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Datacosmos - Core Module Loader & Manager
#
# Copyright (c) 2026 Datacosmos
# Licensed under the Apache License, Version 2.0
#===============================================================================
# File    : core.sh
# Version : 4.0.0
# Date    : 2026-01-15
#===============================================================================
#
# DESCRIPTION:
#   Central loader and manager for shared bash libraries. Provides a generic
#   module system with automatic dependency resolution. Modules are loaded
#   lazily only when explicitly requested.
#
# USAGE:
#   source "$(dirname "$0")/lib/core.sh"
#   core_require runtime config
#   core_load oracle
#
# DEPENDS ON:
#   - logging.sh (always loaded)
#   - runtime.sh (loaded on demand via core_require)
#
# PROVIDES:
#   - Module registration and discovery
#   - Automatic dependency resolution
#   - Generic module loading (core_load, core_require)
#   - Optional initialization (core_setup_all)
#
#===============================================================================

# Prevent double sourcing
[[ -n "${__CORE_LOADED:-}" ]] && return 0
__CORE_LOADED=1

# Resolve library directory
_CORE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load logging.sh first (always required, no dependencies)
# shellcheck source=/dev/null
source "${_CORE_LIB_DIR}/logging.sh"

#===============================================================================
# MODULE REGISTRY
#===============================================================================

# Module registry: name -> "file|deps..."
# Dependencies are space-separated module names
declare -A CORE_MODULES
declare -A CORE_MODULE_FILES
declare -A CORE_MODULE_LOADED

# core_register_module - Register a module in the system
# Usage: core_register_module "name" "file.sh" "dep1" "dep2" ...
core_register_module() {
    local name="$1"
    local file="$2"
    shift 2
    local deps="$*"
    
    CORE_MODULES["${name}"]="${deps}"
    CORE_MODULE_FILES["${name}"]="${file}"
    CORE_MODULE_LOADED["${name}"]=0
}

# Register built-in modules (generic)
core_register_module "runtime" "runtime.sh"
core_register_module "session" "session.sh" "runtime"
core_register_module "config" "config.sh" "runtime"
core_register_module "queue" "queue.sh" "runtime"
core_register_module "report" "report.sh" "runtime"

# Register Oracle modules (hierarchical)
core_register_module "oracle_core" "oracle_core.sh" "runtime"
core_register_module "oracle_env" "oracle_env.sh" "oracle_core" "config"
core_register_module "oracle_config" "oracle_config.sh" "oracle_core" "runtime"
core_register_module "oracle_cluster" "oracle_cluster.sh" "oracle_core" "runtime"
core_register_module "oracle_instance" "oracle_instance.sh" "oracle_core" "oracle_cluster" "runtime"
core_register_module "oracle_sql" "oracle_sql.sh" "oracle_core" "runtime"
core_register_module "oracle_datapump" "oracle_datapump.sh" "oracle_core" "oracle_sql" "config" "queue" "report"
core_register_module "oracle_rman" "oracle_rman.sh" "oracle_core" "oracle_sql" "runtime"
core_register_module "oracle_oci" "oracle_oci.sh" "oracle_core" "runtime"
# Oracle unified loader (loads all core Oracle modules)
core_register_module "oracle" "oracle.sh" "oracle_core" "oracle_env" "oracle_config" "oracle_cluster" "oracle_instance" "oracle_sql"

#===============================================================================
# MODULE LOADING FUNCTIONS
#===============================================================================

# core_load_module_internal - Internal function to load a single module
# Usage: core_load_module_internal "module_name"
core_load_module_internal() {
    local name="$1"
    
    # Check if already loaded
    [[ "${CORE_MODULE_LOADED["${name}"]:-0}" -eq 1 ]] && return 0
    
    # Check if module exists
    if [[ -z "${CORE_MODULE_FILES["${name}"]:-}" ]]; then
        warn "Modulo desconhecido: ${name}"
        return 1
    fi
    
    local file="${CORE_MODULE_FILES["${name}"]}"
    local deps="${CORE_MODULES["${name}"]:-}"
    
    # Load dependencies first
    if [[ -n "${deps}" ]]; then
        local dep
        for dep in ${deps}; do
            core_load_module_internal "${dep}"
        done
    fi
    
    # Load the module itself
    local module_path="${_CORE_LIB_DIR}/${file}"
    if [[ -f "${module_path}" ]]; then
        # shellcheck source=/dev/null
        source "${module_path}"
        CORE_MODULE_LOADED["${name}"]=1
        log_debug "✅ Module loaded: ${name}"
    else
        warn "Arquivo do modulo nao encontrado: ${module_path}"
        return 1
    fi
}

# core_load - Load a module and all its dependencies
# Usage: core_load "module_name"
core_load() {
    local name="$1"
    [[ -z "${name}" ]] && { warn "core_load: nome do modulo requerido"; return 1; }
    core_load_module_internal "${name}"
}

# core_require - Ensure module(s) are loaded (idempotent)
# Usage: core_require "module1" "module2" ...
core_require() {
    local mod
    for mod in "$@"; do
        core_load_module_internal "${mod}"
    done
}

# core_list_modules - List all registered modules
# Usage: core_list_modules
core_list_modules() {
    local name
    local sorted_names
    # Sort module names first, then output each module with its dependencies grouped together
    readarray -t sorted_names < <(printf '%s\n' "${!CORE_MODULES[@]}" | sort)
    for name in "${sorted_names[@]}"; do
        local deps="${CORE_MODULES["${name}"]:-}"
        local loaded="${CORE_MODULE_LOADED["${name}"]:-0}"
        local status="[ ]"
        [[ ${loaded} -eq 1 ]] && status="[✓]"
        echo "${status} ${name} -> ${CORE_MODULE_FILES["${name}"]}"
        if [[ -n "${deps}" ]]; then
            echo "    Depends on: ${deps}"
        fi
    done
}

# core_module_info - Show information about a module
# Usage: core_module_info "module_name"
core_module_info() {
    local name="$1"
    [[ -z "${CORE_MODULE_FILES["${name}"]:-}" ]] && {
        warn "Modulo nao encontrado: ${name}"
        return 1
    }
    
    local file="${CORE_MODULE_FILES["${name}"]}"
    local deps="${CORE_MODULES["${name}"]:-}"
    local loaded="${CORE_MODULE_LOADED["${name}"]:-0}"
    
    echo "Module: ${name}"
    echo "  File: ${file}"
    echo "  Dependencies: ${deps:-none}"
    echo "  Loaded: $([[ ${loaded} -eq 1 ]] && echo "yes" || echo "no")"
}

# core_check_dependencies - Check if all module dependencies are satisfied
# Usage: core_check_dependencies
# Returns: 0 if all dependencies valid, 1 if any missing
core_check_dependencies() {
    local errors=0
    local name
    
    for name in "${!CORE_MODULES[@]}"; do
        local deps="${CORE_MODULES["${name}"]:-}"
        if [[ -n "${deps}" ]]; then
            local dep
            for dep in ${deps}; do
                if [[ -z "${CORE_MODULE_FILES["${dep}"]:-}" ]]; then
                    warn "Module ${name} depends on unknown module: ${dep}"
                    errors=$((errors + 1))
                fi
            done
        fi
    done
    
    return ${errors}
}

# core_validate_module_graph - Validate module dependency graph for cycles
# Usage: core_validate_module_graph
# Returns: 0 if valid, 1 if cycles detected
core_validate_module_graph() {
    local name
    local visited=()
    local rec_stack=()
    
    # Simple cycle detection using DFS (nested function)
    # shellcheck disable=SC2034
    check_cycle() {
        local mod="$1"
        local i
        
        # Check if already in recursion stack
        for i in "${!rec_stack[@]}"; do
            [[ "${rec_stack[$i]}" == "${mod}" ]] && return 1
        done
        
        # Mark as visited and add to recursion stack
        visited+=("${mod}")
        rec_stack+=("${mod}")
        
        # Check dependencies
        local deps="${CORE_MODULES["${mod}"]:-}"
        if [[ -n "${deps}" ]]; then
            local dep
            for dep in ${deps}; do
                if [[ -n "${CORE_MODULE_FILES["${dep}"]:-}" ]]; then
                    check_cycle "${dep}" || return 1
                fi
            done
        fi
        
        # Remove from recursion stack (remove last element)
        local stack_len=${#rec_stack[@]}
        if [[ ${stack_len} -gt 0 ]]; then
            unset "rec_stack[$((stack_len - 1))]"
        fi
        return 0
    }
    
    # Check all modules
    for name in "${!CORE_MODULES[@]}"; do
        local pattern=" ${name} "
        if [[ -z "${visited[*]}" ]] || [[ ! " ${visited[*]} " =~ ${pattern} ]]; then
            check_cycle "${name}" || {
                warn "Circular dependency detected involving module: ${name}"
                return 1
            }
        fi
    done
    
    return 0
}

# core_get_loaded_modules - Get list of currently loaded modules
# Usage: core_get_loaded_modules
core_get_loaded_modules() {
    local name
    for name in "${!CORE_MODULE_LOADED[@]}"; do
        [[ "${CORE_MODULE_LOADED["${name}"]:-0}" -eq 1 ]] && echo "${name}"
    done | sort
}

#===============================================================================
# INITIALIZATION FUNCTION
#===============================================================================

# core_setup_all - Initialize core subsystems (optional, generic)
# Usage: core_setup_all [options]
# Options:
#   --logdir DIR          Initialize logging to directory
#   --logbase NAME        Log file base name (default: "script")
#   --session-dir DIR     Initialize session management
#   --session-prefix NAME Session log prefix (default: "session")
#   --queue-max N         Initialize queue with max concurrent jobs (default: 4)
#   --enable-err-trap      Enable error trap handler
#   --config-profile PROFILE Load configuration profile (dev/prod/test)
#   --config-base DIR     Base directory for config files (default: ./config)
#   --config-app NAME     Application name for config (default: migration)
#   --validate-config     Validate configuration against schema
#   --no-queue-init        Skip queue initialization
#   --no-session-init      Skip session initialization
#   --no-log-init          Skip log initialization
#   --no-config-init       Skip configuration loading
core_setup_all() {
    local logdir="" logbase="script" session_dir="" session_prefix="session"
    local queue_max=4 enable_err_trap=0 validate_config=0
    local config_profile="" config_base="./config" config_app="migration"
    local init_queue=1 init_session=1 init_log=1 init_config=1

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --logdir)
                logdir="$2"
                shift 2
                ;;
            --logbase)
                logbase="$2"
                shift 2
                ;;
            --session-dir)
                session_dir="$2"
                shift 2
                ;;
            --session-prefix)
                session_prefix="$2"
                shift 2
                ;;
            --queue-max)
                queue_max="$2"
                shift 2
                ;;
            --enable-err-trap)
                enable_err_trap=1
                shift
                ;;
            --config-profile)
                config_profile="$2"
                shift 2
                ;;
            --config-base)
                config_base="$2"
                shift 2
                ;;
            --config-app)
                config_app="$2"
                shift 2
                ;;
            --validate-config)
                validate_config=1
                shift
                ;;
            --no-queue-init)
                init_queue=0
                shift
                ;;
            --no-session-init)
                init_session=0
                shift
                ;;
            --no-log-init)
                init_log=0
                shift
                ;;
            --no-config-init)
                init_config=0
                shift
                ;;
            *)
                warn "Opcao desconhecida: $1"
                shift
                ;;
        esac
    done

    # Ensure required modules are loaded
    if [[ ${init_config} -eq 1 ]] || [[ ${init_session} -eq 1 ]]; then
        core_require config
    fi
    if [[ ${init_queue} -eq 1 ]]; then
        core_require queue
    fi
    if [[ ${enable_err_trap} -eq 1 ]]; then
        core_require runtime
    fi

    # Load configuration hierarchically if requested
    if [[ ${init_config} -eq 1 ]]; then
        if [[ -n "${config_profile}" ]]; then
            config_load_with_profile "${config_app}" "${config_base}" || true
        else
            config_load_hierarchical "${config_app}" "/etc/${config_app}.conf" "${config_base}/${config_app}.conf" || true
        fi
        
        # Validate configuration if requested
        if [[ ${validate_config} -eq 1 ]]; then
            config_validate_schema || warn "Configuration validation had errors"
        fi
        
        # Log loaded configuration
        config_log_loaded || true
    fi

    # Initialize logging if requested
    if [[ ${init_log} -eq 1 && -n "${logdir}" ]]; then
        core_require runtime
        runtime_init_logs "${logdir}" "${logbase}" || true
    fi

    # Initialize session management if requested
    if [[ ${init_session} -eq 1 && -n "${session_dir}" ]]; then
        core_require session
        session_init "${session_dir}" "${session_prefix}" || true
    fi

    # Initialize queue if requested
    if [[ ${init_queue} -eq 1 ]]; then
        queue_init "${queue_max}" || true
    fi

    # Enable error trap if requested
    if [[ ${enable_err_trap} -eq 1 ]]; then
        runtime_enable_err_trap || true
    fi
}

#===============================================================================
# NOTE:
#   - logging.sh is always loaded (no dependencies)
#   - runtime.sh and other modules are loaded on-demand via core_require/core_load
#   - Generic utilities (on_err, need_cmd, validators, confirmations) live in runtime.sh
#===============================================================================