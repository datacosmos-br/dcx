#!/usr/bin/env bash
#===============================================================================
# dcx/lib/config.sh - Configuration Management via Go binary
#===============================================================================
# Requires: core.sh (for DCX_GO binary)
# License: MIT
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DCX_CONFIG_LOADED:-}" ]] && return 0
declare -r _DCX_CONFIG_LOADED=1

#-------------------------------------------------------------------------------
# config_get - Get a single value from config file
#-------------------------------------------------------------------------------
# Usage: config_get config.yaml "database.host" "localhost"
# Arguments:
#   $1 - Config file path
#   $2 - Key path (dot notation, e.g., "database.host")
#   $3 - Default value (optional)
#-------------------------------------------------------------------------------
config_get() {
    local file="$1"
    local key="$2"
    local default="${3:-}"

    "$DCX_GO" config yaml-get "$file" "$key" "$default"
}

#-------------------------------------------------------------------------------
# config_set - Set a value in config file
#-------------------------------------------------------------------------------
# Usage: config_set config.yaml "database.host" "newhost"
# Creates the file if it doesn't exist.
#-------------------------------------------------------------------------------
config_set() {
    local file="$1"
    local key="$2"
    local value="$3"

    "$DCX_GO" config yaml-set "$file" "$key" "$value"
}

#-------------------------------------------------------------------------------
# config_has - Check if a key exists in config
#-------------------------------------------------------------------------------
# Usage: config_has config.yaml "database.host"
# Returns 0 if key exists, 1 otherwise.
#-------------------------------------------------------------------------------
config_has() {
    local file="$1"
    local key="$2"

    "$DCX_GO" config yaml-has "$file" "$key"
}

#-------------------------------------------------------------------------------
# config_keys - List all keys at a given path
#-------------------------------------------------------------------------------
# Usage: config_keys config.yaml "database"
# Returns keys as newline-separated list.
#-------------------------------------------------------------------------------
config_keys() {
    local file="$1"
    local path="${2:-.}"

    "$DCX_GO" config yaml-keys "$file" "$path"
}

#-------------------------------------------------------------------------------
# dc_config_cmd - CLI command handler for 'dcx config'
#-------------------------------------------------------------------------------
dc_config_cmd() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/dcx/config.yaml"

    case "$subcmd" in
        get)
            local key="${1:-}"
            local default="${2:-}"
            [[ -z "$key" ]] && { echo "Usage: dcx config get <key> [default]"; return 1; }
            config_get "$config_file" "$key" "$default"
            ;;
        set)
            local key="${1:-}"
            local value="${2:-}"
            [[ -z "$key" || -z "$value" ]] && { echo "Usage: dcx config set <key> <value>"; return 1; }
            config_set "$config_file" "$key" "$value"
            echo "Set $key = $value"
            ;;
        show)
            if [[ -f "$config_file" ]]; then
                cat "$config_file"
            else
                echo "No config file found: $config_file"
            fi
            ;;
        path)
            echo "$config_file"
            ;;
        help|*)
            cat << 'EOF'
Usage: dcx config <command> [options]

Commands:
  get <key> [default]   Get config value
  set <key> <value>     Set config value
  show                  Show config file
  path                  Show config file path
  help                  Show this help

Examples:
  dcx config get log.level info
  dcx config set parallel.max_jobs 8
  dcx config show
EOF
            ;;
    esac
}
