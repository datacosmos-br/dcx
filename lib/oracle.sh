#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Datacosmos - Oracle Unified Module Loader
#
# Copyright (c) 2026 Datacosmos
# Licensed under the Apache License, Version 2.0
#===============================================================================
# File    : oracle.sh
# Version : 2.0.0
# Date    : 2026-01-15
#===============================================================================
#
# DESCRIPTION:
#   Unified loader and facade for all Oracle-related modules. This is the
#   recommended entry point for scripts that need Oracle functionality.
#   Automatically loads and integrates with core.sh module system.
#
# ARCHITECTURE:
#   This module acts as a facade that loads all core Oracle sub-modules:
#   - oracle_core.sh    : Base Oracle functionality (environment, binaries)
#   - oracle_env.sh     : Environment management and configuration
#   - oracle_config.sh  : PFILE, memory, filesystem, paths
#   - oracle_cluster.sh : RAC and Clusterware support
#   - oracle_instance.sh: Instance lifecycle management
#   - oracle_sql.sh     : SQL execution via sqlplus
#
#   Additional specialized modules can be loaded on demand:
#   - oracle_datapump.sh: Data Pump operations
#   - oracle_rman.sh    : RMAN backup/restore
#   - oracle_oci.sh     : OCI Object Storage
#
# USAGE:
#   # Load via core.sh (recommended)
#   source lib/core.sh
#   core_load oracle
#   oracle_init
#
#   # Direct sourcing (also works)
#   source lib/oracle.sh
#   oracle_init
#
#   # Load specific module only
#   source lib/core.sh
#   core_load oracle_sql
#
# PROVIDES:
#   - oracle_init()         : Initialize Oracle environment
#   - oracle_setup()        : Full setup with core.sh integration
#   - oracle_load_module()  : Load additional Oracle modules
#   - oracle_print_info()   : Print Oracle environment information
#
#===============================================================================

# Prevent double sourcing
[[ -n "${__ORACLE_LOADED:-}" ]] && return 0
__ORACLE_LOADED=1

# Resolve library directory
_ORACLE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#===============================================================================
# SECTION 1: Load Core Modules
#===============================================================================

# Load core.sh if available (provides module system)
if [[ -f "${_ORACLE_LIB_DIR}/core.sh" ]] && [[ -z "${__CORE_LOADED:-}" ]]; then
    # shellcheck source=/dev/null
    source "${_ORACLE_LIB_DIR}/core.sh"
fi

# Load all core Oracle modules
# Note: These modules handle their own dependency loading
# shellcheck source=/dev/null
[[ -z "${__ORACLE_CORE_LOADED:-}" ]] && source "${_ORACLE_LIB_DIR}/oracle_core.sh"
# shellcheck source=/dev/null
[[ -z "${__ORACLE_ENV_LOADED:-}" ]] && source "${_ORACLE_LIB_DIR}/oracle_env.sh"
# shellcheck source=/dev/null
[[ -z "${__ORACLE_CONFIG_LOADED:-}" ]] && source "${_ORACLE_LIB_DIR}/oracle_config.sh"
# shellcheck source=/dev/null
[[ -z "${__ORACLE_CLUSTER_LOADED:-}" ]] && source "${_ORACLE_LIB_DIR}/oracle_cluster.sh"
# shellcheck source=/dev/null
[[ -z "${__ORACLE_INSTANCE_LOADED:-}" ]] && source "${_ORACLE_LIB_DIR}/oracle_instance.sh"
# shellcheck source=/dev/null
[[ -z "${__ORACLE_SQL_LOADED:-}" ]] && source "${_ORACLE_LIB_DIR}/oracle_sql.sh"

#===============================================================================
# SECTION 2: Module Loading
#===============================================================================

# oracle_load_module - Load additional Oracle module
# Usage: oracle_load_module "datapump" "rman" "oci"
oracle_load_module() {
    local module
    for module in "$@"; do
        local module_name="oracle_${module}"
        local module_file="${_ORACLE_LIB_DIR}/oracle_${module}.sh"
        
        # Try core_load if available
        if declare -f core_load >/dev/null 2>&1; then
            core_load "${module_name}"
        elif [[ -f "${module_file}" ]]; then
            # Direct sourcing fallback
            # shellcheck source=/dev/null
            source "${module_file}"
        else
            warn "Oracle module not found: ${module}"
        fi
    done
}

# oracle_require - Ensure Oracle module(s) are loaded
# Usage: oracle_require "datapump" "rman"
oracle_require() {
    oracle_load_module "$@"
}

#===============================================================================
# SECTION 3: Initialization
#===============================================================================

# oracle_init - Initialize Oracle environment
# Usage: oracle_init [options]
# Options:
#   --config FILE       Load configuration from file
#   --logs-dir DIR      Initialize session logging
#   --logs-prefix NAME  Session log prefix (default: "oracle")
#   --require-sid       Require ORACLE_SID to be set
#   --require-sqlplus   Require sqlplus binary
#   --require-rman      Require rman binary
#   --require-datapump  Require impdp/expdp binaries
oracle_init() {
    # Delegate to oracle_env_init
    oracle_env_init "$@"
}

# oracle_setup - Full setup integrating core.sh and Oracle
# Usage: oracle_setup [core_setup_all options] [oracle options]
#
# Core options (passed to core_setup_all):
#   --logdir DIR          Initialize logging to directory
#   --logbase NAME        Log file base name
#   --session-dir DIR     Initialize session management
#   --session-prefix NAME Session log prefix
#   --queue-max N         Initialize queue with max concurrent jobs
#   --enable-err-trap     Enable error trap handler
#
# Oracle options:
#   --oracle-config FILE  Load Oracle configuration
#   --oracle-require-sid  Require ORACLE_SID
#   --oracle-require-sql  Require sqlplus
#   --oracle-require-rman Require rman
#   --oracle-require-datapump Require impdp/expdp
oracle_setup() {
    # Delegate to oracle_env_setup
    oracle_env_setup "$@"
}

#===============================================================================
# SECTION 4: Environment Information
#===============================================================================

# oracle_print_info - Print comprehensive Oracle environment information
# Usage: oracle_print_info
oracle_print_info() {
    echo
    echo "========================================================================"
    echo "                    ORACLE ENVIRONMENT INFORMATION"
    echo "========================================================================"
    
    # Environment
    oracle_core_print_env
    
    # Cluster information
    oracle_cluster_print_info
    
    # Instance information
    if [[ -n "${ORACLE_SID:-}" ]]; then
        oracle_instance_print_info
    fi
    
    # Paths if set
    if [[ -n "${ADMIN_DIR:-}" ]]; then
        oracle_config_print_paths
    fi
    
    echo "========================================================================"
}

# oracle_get_info - Get Oracle environment as associative array
# Usage: eval "$(oracle_get_info)"
oracle_get_info() {
    oracle_env_get_info
}

#===============================================================================
# SECTION 5: Convenience Functions
#===============================================================================

# oracle_validate - Validate Oracle environment
# Usage: oracle_validate [options]
oracle_validate() {
    oracle_env_validate "$@"
}

# oracle_switch_sid - Switch to different SID
# Usage: oracle_switch_sid "NEWSID"
oracle_switch_sid() {
    oracle_env_switch_sid "$@"
}

# oracle_use_home - Set ORACLE_HOME
# Usage: oracle_use_home "/path/to/oracle/home"
oracle_use_home() {
    oracle_env_use_home "$@"
}

#===============================================================================
# SECTION 7: Module Information
#===============================================================================

# oracle_list_loaded - List all loaded Oracle modules
# Usage: oracle_list_loaded
oracle_list_loaded() {
    echo "Loaded Oracle modules:"
    [[ -n "${__ORACLE_CORE_LOADED:-}" ]] && echo "  - oracle_core"
    [[ -n "${__ORACLE_ENV_LOADED:-}" ]] && echo "  - oracle_env"
    [[ -n "${__ORACLE_CONFIG_LOADED:-}" ]] && echo "  - oracle_config"
    [[ -n "${__ORACLE_CLUSTER_LOADED:-}" ]] && echo "  - oracle_cluster"
    [[ -n "${__ORACLE_INSTANCE_LOADED:-}" ]] && echo "  - oracle_instance"
    [[ -n "${__ORACLE_SQL_LOADED:-}" ]] && echo "  - oracle_sql"
    [[ -n "${__ORACLE_DATAPUMP_LOADED:-}" ]] && echo "  - oracle_datapump"
    [[ -n "${__ORACLE_RMAN_LOADED:-}" ]] && echo "  - oracle_rman"
    [[ -n "${__ORACLE_OCI_LOADED:-}" ]] && echo "  - oracle_oci"
}

# oracle_version - Print Oracle module versions
# Usage: oracle_version
oracle_version() {
    echo "Oracle Modules v2.0.0"
    echo "  oracle.sh         : 2.0.0 (Unified loader)"
    echo "  oracle_core.sh    : 1.0.0 (Base functionality)"
    echo "  oracle_env.sh     : 1.0.0 (Environment management)"
    echo "  oracle_config.sh  : 1.0.0 (Configuration & PFILE)"
    echo "  oracle_cluster.sh : 1.0.0 (RAC & Clusterware)"
    echo "  oracle_instance.sh: 1.0.0 (Instance lifecycle)"
    echo "  oracle_sql.sh     : 1.0.0 (SQL execution)"
}

#===============================================================================
# AUTO-INITIALIZATION
#===============================================================================

# Log that Oracle module is loaded
log_debug "Oracle unified module loaded (v2.0.0)"
