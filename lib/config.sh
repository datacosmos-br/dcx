#!/usr/bin/env bash
#===============================================================================
# dc-scripts/lib/config.sh - Configuration Management via yq
#===============================================================================
# Version: 0.2.0
# Dependencies: yq (kislyuk/yq - jq wrapper for YAML)
# License: MIT
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DC_CONFIG_LOADED:-}" ]] && return 0
declare -r _DC_CONFIG_LOADED=1

#===============================================================================
# GLOBAL VARIABLES
#===============================================================================

# Config search paths (hierarchical order - later overrides earlier)
declare -ga _DC_CONFIG_PATHS=()

# Registered schemas for validation
declare -gA _DC_CONFIG_SCHEMAS=()

# Merged config cache
declare -g _DC_CONFIG_CACHE=""
declare -g _DC_CONFIG_CACHE_FILE=""

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

    if [[ ! -f "$file" ]]; then
        echo "$default"
        return 1
    fi

    local value
    value=$(yq -r ".${key} // \"${default}\"" "$file" 2>/dev/null)

    # Handle null/empty values
    if [[ "$value" == "null" || -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
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

    # Create empty YAML if file doesn't exist
    if [[ ! -f "$file" ]]; then
        echo "---" > "$file"
    fi

    # Use yq with -y for YAML output and -i for in-place
    yq -y -i ".${key} = \"${value}\"" "$file" 2>/dev/null || {
        gum log --level error "Failed to set config: $key"
        return 1
    }
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

    [[ -f "$file" ]] || return 1

    local result
    result=$(yq -r ".${key}" "$file" 2>/dev/null)

    [[ "$result" != "null" && -n "$result" ]]
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

    [[ -f "$file" ]] || return 1

    if [[ "$path" == "." ]]; then
        yq -r 'keys | .[]' "$file" 2>/dev/null
    else
        yq -r ".${path} | keys | .[]" "$file" 2>/dev/null
    fi
}

#-------------------------------------------------------------------------------
# config_merge - Merge two config files
#-------------------------------------------------------------------------------
# Usage: config_merge base.yaml overlay.yaml > merged.yaml
# Overlay values override base values.
#-------------------------------------------------------------------------------
config_merge() {
    local base="$1"
    local overlay="$2"

    if [[ ! -f "$base" ]]; then
        gum log --level error "Base config not found: $base"
        return 1
    fi

    if [[ ! -f "$overlay" ]]; then
        # No overlay, just output base
        cat "$base"
        return 0
    fi

    # Use yq slurp mode to merge files
    yq -y -s '.[0] * .[1]' "$base" "$overlay" 2>/dev/null
}

#-------------------------------------------------------------------------------
# config_validate - Validate config against schema (basic)
#-------------------------------------------------------------------------------
# Usage: config_validate config.yaml required_key1 required_key2 ...
# Returns 0 if all required keys exist, 1 otherwise.
#-------------------------------------------------------------------------------
config_validate() {
    local file="$1"
    shift
    local required_keys=("$@")

    [[ -f "$file" ]] || {
        gum log --level error "Config not found: $file"
        return 1
    }

    local missing=()
    for key in "${required_keys[@]}"; do
        if ! config_has "$file" "$key"; then
            missing+=("$key")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        gum log --level error "Missing required config keys: ${missing[*]}"
        return 1
    fi

    return 0
}

#-------------------------------------------------------------------------------
# config_to_env - Export config as environment variables with prefix
#-------------------------------------------------------------------------------
# Usage: config_to_env config.yaml "APP_"
# Exports: APP_DATABASE_HOST, APP_DATABASE_PORT, etc.
# Note: Only exports scalar values, nested objects become flattened keys.
#-------------------------------------------------------------------------------
config_to_env() {
    local file="$1"
    local prefix="${2:-}"

    [[ -f "$file" ]] || return 1

    # Use jq to flatten and export
    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue
        # Convert dots to underscores, uppercase
        local env_key="${prefix}${key//./_}"
        env_key="${env_key^^}"
        # Remove surrounding quotes if present
        value="${value%\"}"
        value="${value#\"}"
        export "$env_key=$value"
    done < <(yq -r 'paths(scalars) as $p | "\($p | join("."))=\(getpath($p))"' "$file" 2>/dev/null)
}

#-------------------------------------------------------------------------------
# config_load - Load config and export top-level keys
#-------------------------------------------------------------------------------
# Usage: config_load config.yaml
# Exports top-level keys as environment variables.
# For nested configs, use config_to_env with a prefix instead.
#-------------------------------------------------------------------------------
config_load() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        gum log --level error "Config not found: $file"
        return 1
    fi

    # Export using config_to_env with no prefix
    config_to_env "$file" ""
}

#===============================================================================
# HIERARCHICAL CONFIG LOADING
#===============================================================================

#-------------------------------------------------------------------------------
# config_init_paths - Initialize hierarchical config search paths
#-------------------------------------------------------------------------------
# Sets up the standard config hierarchy:
#   1. defaults (lowest priority) - bundled with dc-scripts
#   2. global   - /etc/dc-scripts/ or $XDG_CONFIG_HOME
#   3. local    - current directory .dc-scripts/
#   4. env      - environment variable overrides (highest)
#-------------------------------------------------------------------------------
config_init_paths() {
    local dc_home="${DC_HOME:-}"

    _DC_CONFIG_PATHS=()

    # 1. Defaults (bundled with dc-scripts)
    if [[ -n "$dc_home" && -f "$dc_home/etc/defaults.yaml" ]]; then
        _DC_CONFIG_PATHS+=("$dc_home/etc/defaults.yaml")
    fi

    # 2. System-wide (optional, typically /etc/dc-scripts/)
    if [[ -f "/etc/dc-scripts/config.yaml" ]]; then
        _DC_CONFIG_PATHS+=("/etc/dc-scripts/config.yaml")
    fi

    # 3. User global ($XDG_CONFIG_HOME or ~/.config)
    local user_config="${XDG_CONFIG_HOME:-$HOME/.config}/dc-scripts/config.yaml"
    if [[ -f "$user_config" ]]; then
        _DC_CONFIG_PATHS+=("$user_config")
    fi

    # 4. DC_HOME config (installation directory)
    if [[ -n "$dc_home" && -f "$dc_home/etc/dc-scripts.yaml" ]]; then
        _DC_CONFIG_PATHS+=("$dc_home/etc/dc-scripts.yaml")
    fi

    # 5. Local config (current project)
    if [[ -f ".dc-scripts/config.yaml" ]]; then
        _DC_CONFIG_PATHS+=(".dc-scripts/config.yaml")
    elif [[ -f "dc-scripts.yaml" ]]; then
        _DC_CONFIG_PATHS+=("dc-scripts.yaml")
    fi
}

#-------------------------------------------------------------------------------
# config_load_hierarchical - Load and merge configs from all paths
#-------------------------------------------------------------------------------
# Usage: config_load_hierarchical [output_file]
# Merges all configs in order (later overrides earlier).
# If output_file provided, writes merged config there.
# Returns: Merged YAML on stdout (or writes to file)
#-------------------------------------------------------------------------------
config_load_hierarchical() {
    local output_file="${1:-}"

    # Initialize paths if not done
    [[ ${#_DC_CONFIG_PATHS[@]} -eq 0 ]] && config_init_paths

    # No configs found
    if [[ ${#_DC_CONFIG_PATHS[@]} -eq 0 ]]; then
        echo "---"
        return 0
    fi

    # Start with first config
    local merged_content
    local first_config="${_DC_CONFIG_PATHS[0]}"

    if [[ -f "$first_config" ]]; then
        merged_content=$(cat "$first_config")
    else
        merged_content="---"
    fi

    # Merge remaining configs
    local i
    for ((i = 1; i < ${#_DC_CONFIG_PATHS[@]}; i++)); do
        local next_config="${_DC_CONFIG_PATHS[$i]}"
        if [[ -f "$next_config" ]]; then
            merged_content=$(echo "$merged_content" | yq -y -s '.[0] * .[1]' - "$next_config" 2>/dev/null) || true
        fi
    done

    # Cache the result
    _DC_CONFIG_CACHE="$merged_content"

    # Output
    if [[ -n "$output_file" ]]; then
        echo "$merged_content" > "$output_file"
        _DC_CONFIG_CACHE_FILE="$output_file"
    else
        echo "$merged_content"
    fi
}

#-------------------------------------------------------------------------------
# config_get_merged - Get value from merged hierarchical config
#-------------------------------------------------------------------------------
# Usage: config_get_merged "key.path" "default"
# Uses cached merged config or loads it if not available.
#-------------------------------------------------------------------------------
config_get_merged() {
    local key="$1"
    local default="${2:-}"

    # Load merged config if not cached
    if [[ -z "$_DC_CONFIG_CACHE" ]]; then
        _DC_CONFIG_CACHE=$(config_load_hierarchical)
    fi

    local value
    value=$(echo "$_DC_CONFIG_CACHE" | yq -r ".${key} // \"${default}\"" 2>/dev/null)

    if [[ "$value" == "null" || -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

#-------------------------------------------------------------------------------
# config_load_profile - Load a named profile (dev/staging/prod)
#-------------------------------------------------------------------------------
# Usage: config_load_profile "production"
# Looks for profile files: config.production.yaml, config-production.yaml
# Merges profile on top of base config.
#-------------------------------------------------------------------------------
config_load_profile() {
    local profile="$1"
    local base_config="${2:-}"

    # Search for profile config in standard locations
    local profile_files=(
        ".dc-scripts/config.${profile}.yaml"
        ".dc-scripts/config-${profile}.yaml"
        "dc-scripts.${profile}.yaml"
        "dc-scripts-${profile}.yaml"
    )

    # Add XDG location
    local xdg_profile="${XDG_CONFIG_HOME:-$HOME/.config}/dc-scripts/config.${profile}.yaml"
    profile_files+=("$xdg_profile")

    local profile_config=""
    for pf in "${profile_files[@]}"; do
        if [[ -f "$pf" ]]; then
            profile_config="$pf"
            break
        fi
    done

    if [[ -z "$profile_config" ]]; then
        echo "Profile not found: $profile" >&2
        return 1
    fi

    # Get base config (merged hierarchical or specified file)
    local base
    if [[ -n "$base_config" && -f "$base_config" ]]; then
        base=$(cat "$base_config")
    elif [[ -n "$_DC_CONFIG_CACHE" ]]; then
        base="$_DC_CONFIG_CACHE"
    else
        base=$(config_load_hierarchical)
    fi

    # Merge profile on top of base
    echo "$base" | yq -y -s '.[0] * .[1]' - "$profile_config" 2>/dev/null
}

#===============================================================================
# SCHEMA VALIDATION
#===============================================================================

#-------------------------------------------------------------------------------
# config_register_schema - Register a schema for validation
#-------------------------------------------------------------------------------
# Usage: config_register_schema "module_name" "required.key1" "required.key2" ...
# Registers which keys are required for a module's config.
#-------------------------------------------------------------------------------
config_register_schema() {
    local name="$1"
    shift
    local keys=("$@")

    # Store as space-separated string
    _DC_CONFIG_SCHEMAS[$name]="${keys[*]}"
}

#-------------------------------------------------------------------------------
# config_validate_schema - Validate config against registered schema
#-------------------------------------------------------------------------------
# Usage: config_validate_schema config.yaml "module_name"
# Returns 0 if valid, 1 if invalid (prints errors)
#-------------------------------------------------------------------------------
config_validate_schema() {
    local file="$1"
    local schema_name="$2"

    if [[ -z "${_DC_CONFIG_SCHEMAS[$schema_name]:-}" ]]; then
        echo "Schema not found: $schema_name" >&2
        return 1
    fi

    # Convert space-separated string back to array
    local -a required_keys
    IFS=' ' read -ra required_keys <<< "${_DC_CONFIG_SCHEMAS[$schema_name]}"

    config_validate "$file" "${required_keys[@]}"
}

#-------------------------------------------------------------------------------
# config_print - Print config with masked sensitive values
#-------------------------------------------------------------------------------
# Usage: config_print config.yaml
# Masks values containing: password, secret, key, token
#-------------------------------------------------------------------------------
config_print() {
    local file="$1"

    [[ -f "$file" ]] || {
        echo "Config not found: $file" >&2
        return 1
    }

    # Use yq to mask sensitive values
    yq -y 'walk(
        if type == "object" then
            with_entries(
                if (.key | test("password|secret|key|token|credential"; "i")) and (.value | type == "string")
                then .value = "********"
                else .
                end
            )
        else .
        end
    )' "$file" 2>/dev/null
}

#===============================================================================
# INTERACTIVE CONFIG
#===============================================================================

#-------------------------------------------------------------------------------
# config_init_interactive - Create initial config interactively
#-------------------------------------------------------------------------------
# Usage: config_init_interactive [output_file]
# Prompts user for common config values using gum.
#-------------------------------------------------------------------------------
config_init_interactive() {
    local output_file="${1:-.dc-scripts/config.yaml}"
    local output_dir
    output_dir=$(dirname "$output_file")

    # Create directory if needed
    [[ -d "$output_dir" ]] || mkdir -p "$output_dir"

    # Prompt for values using gum
    local log_level
    log_level=$(gum choose --header "Log level:" "debug" "info" "warn" "error" 2>/dev/null) || log_level="info"

    local max_jobs
    max_jobs=$(gum input --header "Max parallel jobs:" --value "4" 2>/dev/null) || max_jobs="4"

    local auto_update
    auto_update=$(gum choose --header "Auto-check updates:" "true" "false" 2>/dev/null) || auto_update="true"

    # Write config
    cat > "$output_file" << EOF
# dc-scripts configuration
# Generated: $(date -Iseconds)

log:
  level: ${log_level}
  format: text

parallel:
  max_jobs: ${max_jobs}

update:
  auto_check: ${auto_update}
EOF

    echo "Config created: $output_file"
}

#-------------------------------------------------------------------------------
# config_edit - Open config in editor
#-------------------------------------------------------------------------------
# Usage: config_edit [config_file]
# Opens config in $EDITOR (default: vi)
#-------------------------------------------------------------------------------
config_edit() {
    local file="${1:-}"

    # Find config file if not specified
    if [[ -z "$file" ]]; then
        if [[ -f ".dc-scripts/config.yaml" ]]; then
            file=".dc-scripts/config.yaml"
        elif [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/dc-scripts/config.yaml" ]]; then
            file="${XDG_CONFIG_HOME:-$HOME/.config}/dc-scripts/config.yaml"
        else
            echo "No config file found. Run: config_init_interactive" >&2
            return 1
        fi
    fi

    "${EDITOR:-vi}" "$file"
}

#-------------------------------------------------------------------------------
# dc_config_cmd - CLI command handler for 'dcx config'
#-------------------------------------------------------------------------------
dc_config_cmd() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        get)
            local key="${1:-}"
            local default="${2:-}"
            [[ -z "$key" ]] && { echo "Usage: dcx config get <key> [default]"; return 1; }
            config_get_merged "$key" "$default"
            ;;
        set)
            local key="${1:-}"
            local value="${2:-}"
            [[ -z "$key" || -z "$value" ]] && { echo "Usage: dcx config set <key> <value>"; return 1; }
            local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/dc-scripts/config.yaml"
            mkdir -p "$(dirname "$config_file")"
            config_set "$config_file" "$key" "$value"
            echo "Set $key = $value"
            ;;
        show)
            config_load_hierarchical
            ;;
        paths)
            config_init_paths
            for path in "${_DC_CONFIG_PATHS[@]}"; do
                if [[ -f "$path" ]]; then
                    echo "[exists] $path"
                else
                    echo "[missing] $path"
                fi
            done
            ;;
        init)
            config_init_interactive "$@"
            ;;
        edit)
            config_edit "$@"
            ;;
        help|*)
            cat << 'EOF'
Usage: dcx config <command> [options]

Commands:
  get <key> [default]   Get config value
  set <key> <value>     Set config value in user config
  show                  Show merged config
  paths                 Show config search paths
  init [file]           Create initial config interactively
  edit [file]           Edit config in $EDITOR
  help                  Show this help

Examples:
  dcx config get log.level info
  dcx config set parallel.max_jobs 8
  dcx config show
  dcx config paths
EOF
            ;;
    esac
}
