#!/usr/bin/env bash
#===============================================================================
# Datacosmos - Keyring CLI
#
# Copyright (c) 2026 Datacosmos
# Licensed under the Apache License, Version 2.0
#===============================================================================
# File    : keyring.sh
# Version : 1.0.0
# Date    : 2026-01-16
#===============================================================================
#
# DESCRIPTION:
#   Command-line interface for managing encrypted credential keyring.
#   Provides secure storage for database credentials with master password
#   protection. Supports Oracle Wallet generation for automated jobs.
#
# USAGE:
#   ./keyring.sh <command> [options]
#
# COMMANDS:
#   init                    Create new keyring (prompts for master password)
#   open                    Open existing keyring
#   close                   Close keyring (clear from memory)
#   status                  Show keyring status
#
#   env add <name>          Add environment (interactive)
#   env list                List all environments
#   env show <name>         Show environment details (masks password)
#   env remove <name>       Remove environment
#   env export <name>       Export environment to shell vars
#
#   wallet create <name>    Create Oracle Wallet for environment
#   wallet create-all       Create wallets for all environments
#   wallet delete <name>    Delete wallet for environment
#   wallet list             List existing wallets
#
# EXAMPLES:
#   ./keyring.sh init                    # Create new keyring
#   ./keyring.sh env add PRD             # Add PRD environment
#   ./keyring.sh wallet create PRD       # Create wallet for PRD
#   eval $(./keyring.sh env export PRD)  # Export PRD to shell
#
#===============================================================================
set -euo pipefail

#===============================================================================
# Script Setup
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load required libraries
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/runtime.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/keyring.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/oracle_config.sh"

#===============================================================================
# Usage and Help
#===============================================================================

usage() {
    cat <<'EOF'
Usage: keyring.sh <command> [options]

Keyring Commands:
  init                    Create new keyring (prompts for master password)
  open                    Open existing keyring
  close                   Close keyring (clear from memory)
  status                  Show keyring status

Environment Commands:
  env add <name>          Add environment (interactive prompts)
  env list                List all environments
  env show <name>         Show environment details (masks password)
  env remove <name>       Remove environment
  env export <name>       Export environment to shell variables

Wallet Commands:
  wallet create <name>    Create Oracle Wallet for environment
  wallet create-all       Create wallets for all environments
  wallet delete <name>    Delete wallet for environment
  wallet list             List existing wallets

Options:
  -h, --help              Show this help message
  -v, --verbose           Enable verbose output
  -q, --quiet             Suppress non-essential output

Examples:
  keyring.sh init                    # Create new keyring
  keyring.sh env add PRD             # Add PRD environment (interactive)
  keyring.sh env list                # List environments
  keyring.sh wallet create PRD       # Create Oracle Wallet for PRD
  eval $(keyring.sh env export PRD)  # Export credentials to shell

Note:
  The keyring file is stored at: ~/.oracle_keyring.enc
  Wallets are stored at: ~/.wallets/<env_name>/
EOF
}

#===============================================================================
# Command Handlers
#===============================================================================

cmd_init() {
    keyring_init
}

cmd_open() {
    keyring_open
    log_success "Keyring opened successfully"
}

cmd_close() {
    keyring_close
    log_success "Keyring closed"
}

cmd_status() {
    local keyring_file="${KEYRING_FILE:-${HOME}/.oracle_keyring.enc}"

    echo "Keyring Status"
    echo "=============="
    echo

    if [[ -f "${keyring_file}" ]]; then
        echo "Keyring file: ${keyring_file}"
        echo "File exists:  yes"
        echo "File size:    $(stat -c%s "${keyring_file}" 2>/dev/null || stat -f%z "${keyring_file}") bytes"
        echo "Permissions:  $(stat -c%a "${keyring_file}" 2>/dev/null || stat -f%OLp "${keyring_file}")"

        if keyring_is_open; then
            echo "State:        OPEN"
            local envs
            envs=$(keyring_env_list 2>/dev/null || echo "")
            local count=0
            while IFS= read -r env; do
                [[ -n "${env}" ]] && count=$((count + 1))
            done <<< "${envs}"
            echo "Environments: ${count}"
        else
            echo "State:        CLOSED"
        fi
    else
        echo "Keyring file: ${keyring_file}"
        echo "File exists:  no"
        echo
        echo "Run 'keyring.sh init' to create a new keyring"
    fi
}

cmd_env_add() {
    local name="${1:-}"
    [[ -z "${name}" ]] && { echo "Error: Environment name required" >&2; exit 1; }

    keyring_open 2>/dev/null || true
    if ! keyring_is_open; then
        die "Cannot add environment: keyring not open"
    fi

    keyring_env_add "${name}"
}

cmd_env_list() {
    keyring_open 2>/dev/null || true
    if ! keyring_is_open; then
        die "Cannot list environments: keyring not open"
    fi

    echo "Environments:"
    echo

    local envs
    envs=$(keyring_env_list)

    if [[ -z "${envs}" ]]; then
        echo "  (no environments configured)"
        echo
        echo "Use 'keyring.sh env add <name>' to add an environment"
        return 0
    fi

    while IFS= read -r env; do
        [[ -z "${env}" ]] && continue
        local user tns dbid
        user=$(keyring_env_get "${env}" "user" 2>/dev/null || echo "?")
        tns=$(keyring_env_get "${env}" "tns" 2>/dev/null || echo "?")
        dbid=$(keyring_env_get "${env}" "dbid" 2>/dev/null || echo "")

        echo "  ${env}:"
        echo "    User: ${user}"
        echo "    TNS:  ${tns}"
        [[ -n "${dbid}" ]] && echo "    DBID: ${dbid}"
        echo
    done <<< "${envs}"
}

cmd_env_show() {
    local name="${1:-}"
    [[ -z "${name}" ]] && { echo "Error: Environment name required" >&2; exit 1; }

    keyring_open 2>/dev/null || true
    if ! keyring_is_open; then
        die "Cannot show environment: keyring not open"
    fi

    local user tns dbid
    user=$(keyring_env_get "${name}" "user" 2>/dev/null) || { echo "Environment not found: ${name}" >&2; exit 1; }
    tns=$(keyring_env_get "${name}" "tns" 2>/dev/null || echo "")
    dbid=$(keyring_env_get "${name}" "dbid" 2>/dev/null || echo "")

    echo "Environment: ${name}"
    echo "============"
    echo "User:     ${user}"
    echo "Password: ********"
    echo "TNS:      ${tns}"
    [[ -n "${dbid}" ]] && echo "DBID:     ${dbid}"
}

cmd_env_remove() {
    local name="${1:-}"
    [[ -z "${name}" ]] && { echo "Error: Environment name required" >&2; exit 1; }

    keyring_open 2>/dev/null || true
    if ! keyring_is_open; then
        die "Cannot remove environment: keyring not open"
    fi

    keyring_env_remove "${name}"
}

cmd_env_export() {
    local name="${1:-}"
    [[ -z "${name}" ]] && { echo "Error: Environment name required" >&2; exit 1; }

    keyring_open 2>/dev/null || true
    if ! keyring_is_open; then
        echo "# Error: keyring not open" >&2
        exit 1
    fi

    # Get values
    local user password tns dbid
    user=$(keyring_env_get "${name}" "user" 2>/dev/null) || { echo "# Environment not found: ${name}" >&2; exit 1; }
    password=$(keyring_env_get "${name}" "password" 2>/dev/null) || { echo "# Failed to get password" >&2; exit 1; }
    tns=$(keyring_env_get "${name}" "tns" 2>/dev/null || echo "")
    dbid=$(keyring_env_get "${name}" "dbid" 2>/dev/null || echo "")

    # Output export statements (to be eval'd)
    echo "export DB_ADMIN_USER='${user}'"
    echo "export DB_ADMIN_PASSWORD='${password}'"
    [[ -n "${tns}" ]] && echo "export DB_TNS_ALIAS='${tns}'"
    [[ -n "${tns}" ]] && echo "export DB_CONNECTION_STRING='${tns}'"
    [[ -n "${dbid}" ]] && echo "export DBID='${dbid}'"
}

cmd_wallet_create() {
    local name="${1:-}"
    [[ -z "${name}" ]] && { echo "Error: Environment name required" >&2; exit 1; }

    keyring_open 2>/dev/null || true
    if ! keyring_is_open; then
        die "Cannot create wallet: keyring not open"
    fi

    oracle_config_wallet_create_from_keyring "${name}"
}

cmd_wallet_create_all() {
    keyring_open 2>/dev/null || true
    if ! keyring_is_open; then
        die "Cannot create wallets: keyring not open"
    fi

    oracle_config_wallet_create_all
}

cmd_wallet_delete() {
    local name="${1:-}"
    [[ -z "${name}" ]] && { echo "Error: Environment name required" >&2; exit 1; }

    local wallet_dir="${WALLET_BASE:-${HOME}/.wallets}/${name}"
    oracle_config_wallet_delete "${wallet_dir}"
}

cmd_wallet_list() {
    oracle_config_wallet_list
}

#===============================================================================
# Main
#===============================================================================

main() {
    local verbose=0
    local quiet=0

    # Parse global options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help|help)
                usage
                exit 0
                ;;
            -v|--verbose)
                verbose=1
                export LOG_LEVEL="debug"
                shift
                ;;
            -q|--quiet)
                quiet=1
                export LOG_LEVEL="error"
                shift
                ;;
            -*)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done

    # Get command
    local cmd="${1:-}"
    shift || true

    case "${cmd}" in
        init)
            cmd_init "$@"
            ;;
        open)
            cmd_open "$@"
            ;;
        close)
            cmd_close "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        env)
            local subcmd="${1:-}"
            shift || true
            case "${subcmd}" in
                add)
                    cmd_env_add "$@"
                    ;;
                list)
                    cmd_env_list "$@"
                    ;;
                show)
                    cmd_env_show "$@"
                    ;;
                remove)
                    cmd_env_remove "$@"
                    ;;
                export)
                    cmd_env_export "$@"
                    ;;
                *)
                    echo "Unknown env subcommand: ${subcmd}" >&2
                    echo "Valid subcommands: add, list, show, remove, export" >&2
                    exit 1
                    ;;
            esac
            ;;
        wallet)
            local subcmd="${1:-}"
            shift || true
            case "${subcmd}" in
                create)
                    cmd_wallet_create "$@"
                    ;;
                create-all)
                    cmd_wallet_create_all "$@"
                    ;;
                delete)
                    cmd_wallet_delete "$@"
                    ;;
                list)
                    cmd_wallet_list "$@"
                    ;;
                *)
                    echo "Unknown wallet subcommand: ${subcmd}" >&2
                    echo "Valid subcommands: create, create-all, delete, list" >&2
                    exit 1
                    ;;
            esac
            ;;
        "")
            usage
            exit 1
            ;;
        *)
            echo "Unknown command: ${cmd}" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
