#!/usr/bin/env bash
#===============================================================================
# dc-scripts/lib/plugin.sh - Plugin Discovery & Loading
#===============================================================================
# Dependencies: yq, gum (optional)
# License: MIT
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DC_PLUGIN_LOADED:-}" ]] && return 0
declare -r _DC_PLUGIN_LOADED=1

#===============================================================================
# GLOBAL VARIABLES
#===============================================================================

# Plugin search directories (in order of priority)
declare -ga DC_PLUGIN_DIRS=()

# Loaded plugins registry
declare -gA _DC_LOADED_PLUGINS=()

# Plugin metadata cache
declare -gA _DC_PLUGIN_CACHE=()

#===============================================================================
# PLUGIN DISCOVERY
#===============================================================================

#-------------------------------------------------------------------------------
# dc_init_plugin_dirs - Initialize plugin search directories
#-------------------------------------------------------------------------------
dc_init_plugin_dirs() {
    DC_PLUGIN_DIRS=()

    # 1. Installation directory plugins
    local dc_home="${DC_HOME:-}"
    if [[ -n "$dc_home" && -d "$dc_home/plugins" ]]; then
        DC_PLUGIN_DIRS+=("$dc_home/plugins")
    fi

    # 2. User plugins ($XDG_CONFIG_HOME or ~/.config)
    local user_plugins="${XDG_CONFIG_HOME:-$HOME/.config}/dc-scripts/plugins"
    [[ -d "$user_plugins" ]] && DC_PLUGIN_DIRS+=("$user_plugins")

    # 3. System plugins (optional)
    [[ -d "/usr/local/share/dc-scripts/plugins" ]] && DC_PLUGIN_DIRS+=("/usr/local/share/dc-scripts/plugins")

    # 4. Local project plugins
    [[ -d ".dc-scripts/plugins" ]] && DC_PLUGIN_DIRS+=(".dc-scripts/plugins")

    return 0
}

#-------------------------------------------------------------------------------
# dc_discover_plugins - Discover all available plugins
#-------------------------------------------------------------------------------
# Returns: List of plugin directories (one per line)
#-------------------------------------------------------------------------------
dc_discover_plugins() {
    # Initialize dirs if not done
    [[ ${#DC_PLUGIN_DIRS[@]} -eq 0 ]] && dc_init_plugin_dirs

    for dir in "${DC_PLUGIN_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            for plugin in "$dir"/*/plugin.yaml "$dir"/*/plugin.yml; do
                if [[ -f "$plugin" ]]; then
                    dirname "$plugin"
                fi
            done
        fi
    done
}

#-------------------------------------------------------------------------------
# dc_plugin_info - Get plugin metadata
#-------------------------------------------------------------------------------
# Usage: dc_plugin_info /path/to/plugin [field]
# Returns: Full YAML or specific field value
#-------------------------------------------------------------------------------
dc_plugin_info() {
    local plugin_dir="$1"
    local field="${2:-}"

    local plugin_file=""
    if [[ -f "$plugin_dir/plugin.yaml" ]]; then
        plugin_file="$plugin_dir/plugin.yaml"
    elif [[ -f "$plugin_dir/plugin.yml" ]]; then
        plugin_file="$plugin_dir/plugin.yml"
    else
        echo "No plugin.yaml found in: $plugin_dir" >&2
        return 1
    fi

    if [[ -z "$field" ]]; then
        cat "$plugin_file"
    else
        yq -r ".$field // \"\"" "$plugin_file" 2>/dev/null
    fi
}

#===============================================================================
# PLUGIN LOADING
#===============================================================================

#-------------------------------------------------------------------------------
# dc_load_plugin - Load a plugin
#-------------------------------------------------------------------------------
# Usage: dc_load_plugin /path/to/plugin
#-------------------------------------------------------------------------------
dc_load_plugin() {
    local plugin_dir="$1"

    # Check if already loaded
    local plugin_name
    plugin_name=$(dc_plugin_info "$plugin_dir" "name")

    if [[ -z "$plugin_name" ]]; then
        echo "Could not determine plugin name from: $plugin_dir" >&2
        return 1
    fi

    if [[ -n "${_DC_LOADED_PLUGINS[$plugin_name]:-}" ]]; then
        return 0  # Already loaded
    fi

    # Get plugin version
    local plugin_version
    plugin_version=$(dc_plugin_info "$plugin_dir" "version")

    # Note: Version check (requires.dc-scripts) intentionally not implemented
    # YAGNI - implement when plugins actually specify minimum versions

    # Check command dependencies
    local requires_cmds
    requires_cmds=$(dc_plugin_info "$plugin_dir" "requires.commands")
    if [[ -n "$requires_cmds" && "$requires_cmds" != "null" ]]; then
        # Parse YAML array
        while IFS= read -r cmd; do
            [[ -z "$cmd" ]] && continue
            if ! command -v "$cmd" &>/dev/null; then
                echo "Plugin '$plugin_name' requires command: $cmd" >&2
                return 1
            fi
        done < <(echo "$requires_cmds" | yq -r '.[]' 2>/dev/null)
    fi

    # Add plugin lib to path
    if [[ -d "$plugin_dir/lib" ]]; then
        DC_LIB_PATH="${DC_LIB_PATH:-}:$plugin_dir/lib"
    fi

    # Add plugin bin to PATH
    if [[ -d "$plugin_dir/bin" ]]; then
        export PATH="$plugin_dir/bin:$PATH"
    fi

    # Source init script if exists
    if [[ -f "$plugin_dir/lib/init.sh" ]]; then
        # shellcheck source=/dev/null
        source "$plugin_dir/lib/init.sh"
    fi

    # Mark as loaded
    _DC_LOADED_PLUGINS[$plugin_name]="$plugin_dir"
    _DC_PLUGIN_CACHE[$plugin_name]="$plugin_version"

    # Debug output
    if [[ "${DC_DEBUG:-}" == "1" ]]; then
        echo "Loaded plugin: $plugin_name v$plugin_version"
    fi

    return 0
}

#-------------------------------------------------------------------------------
# dc_load_all_plugins - Load all discovered plugins
#-------------------------------------------------------------------------------
dc_load_all_plugins() {
    local plugins
    plugins=$(dc_discover_plugins)

    while IFS= read -r plugin_dir; do
        [[ -z "$plugin_dir" ]] && continue
        dc_load_plugin "$plugin_dir" || true
    done <<< "$plugins"
}

#-------------------------------------------------------------------------------
# dc_unload_plugin - Unload a plugin
#-------------------------------------------------------------------------------
# Note: Cannot fully unload sourced scripts, but removes from registry
#-------------------------------------------------------------------------------
dc_unload_plugin() {
    local name="$1"

    if [[ -z "${_DC_LOADED_PLUGINS[$name]:-}" ]]; then
        echo "Plugin not loaded: $name" >&2
        return 1
    fi

    unset "_DC_LOADED_PLUGINS[$name]"
    unset "_DC_PLUGIN_CACHE[$name]"

    echo "Unloaded plugin: $name (shell restart recommended)"
}

#===============================================================================
# PLUGIN MANAGEMENT
#===============================================================================

#-------------------------------------------------------------------------------
# _dc_find_plugin_by_name - Find plugin directory by name
#-------------------------------------------------------------------------------
_dc_find_plugin_by_name() {
    local name="$1"
    while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        [[ "$(dc_plugin_info "$dir" "name")" == "$name" ]] && echo "$dir" && return 0
    done < <(dc_discover_plugins)
    return 1
}

#-------------------------------------------------------------------------------
# dc_plugin_list - List plugins
#-------------------------------------------------------------------------------
dc_plugin_list() {
    local format="${1:-table}"  # table, json, simple

    local plugins
    plugins=$(dc_discover_plugins)

    case "$format" in
        json)
            echo "["
            local first=true
            while IFS= read -r plugin_dir; do
                [[ -z "$plugin_dir" ]] && continue
                local name version desc
                name=$(dc_plugin_info "$plugin_dir" "name")
                version=$(dc_plugin_info "$plugin_dir" "version")
                desc=$(dc_plugin_info "$plugin_dir" "description")
                local loaded="false"
                [[ -n "${_DC_LOADED_PLUGINS[$name]:-}" ]] && loaded="true"

                [[ "$first" == "true" ]] || echo ","
                first=false
                printf '  {"name": "%s", "version": "%s", "description": "%s", "loaded": %s, "path": "%s"}' \
                    "$name" "$version" "$desc" "$loaded" "$plugin_dir"
            done <<< "$plugins"
            echo ""
            echo "]"
            ;;

        simple)
            while IFS= read -r plugin_dir; do
                [[ -z "$plugin_dir" ]] && continue
                local name
                name=$(dc_plugin_info "$plugin_dir" "name")
                local status="[ ]"
                [[ -n "${_DC_LOADED_PLUGINS[$name]:-}" ]] && status="[x]"
                echo "$status $name"
            done <<< "$plugins"
            ;;

        table|*)
            printf "%-20s %-10s %-8s %s\n" "Name" "Version" "Loaded" "Path"
            printf "%-20s %-10s %-8s %s\n" "----" "-------" "------" "----"

            while IFS= read -r plugin_dir; do
                [[ -z "$plugin_dir" ]] && continue
                local name version
                name=$(dc_plugin_info "$plugin_dir" "name")
                version=$(dc_plugin_info "$plugin_dir" "version")
                local loaded="No"
                [[ -n "${_DC_LOADED_PLUGINS[$name]:-}" ]] && loaded="Yes"

                printf "%-20s %-10s %-8s %s\n" "$name" "$version" "$loaded" "$plugin_dir"
            done <<< "$plugins"
            ;;
    esac
}

#-------------------------------------------------------------------------------
# dc_plugin_install - Install a plugin from GitHub
#-------------------------------------------------------------------------------
dc_plugin_install() {
    local repo="$1"  # e.g., datacosmos-br/dc-scripts-oracle

    if [[ -z "$repo" ]]; then
        echo "Usage: dcx plugin install <github-repo>"
        echo "Example: dcx plugin install datacosmos-br/dc-scripts-oracle"
        return 1
    fi

    # Determine install directory
    local dest
    dest="${XDG_CONFIG_HOME:-$HOME/.config}/dc-scripts/plugins/$(basename "$repo")"

    if [[ -d "$dest" ]]; then
        echo "Plugin already installed: $dest"
        echo "Use 'dcx plugin update $(basename "$repo")' to update."
        return 1
    fi

    echo "Installing plugin: $repo"

    # Clone repository
    local install_msg="Cloning $repo..."
    local gum_bin="${GUM:-gum}"
    if command -v "$gum_bin" &>/dev/null; then
        "$gum_bin" spin --title "$install_msg" -- \
            git clone --depth 1 "https://github.com/$repo.git" "$dest"
    else
        echo "$install_msg"
        git clone --depth 1 "https://github.com/$repo.git" "$dest"
    fi

    if [[ ! -d "$dest" ]]; then
        echo "Failed to clone: $repo"
        return 1
    fi

    # Verify it's a valid plugin
    if [[ ! -f "$dest/plugin.yaml" && ! -f "$dest/plugin.yml" ]]; then
        echo "Warning: No plugin.yaml found in $repo"
        echo "This may not be a valid dc-scripts plugin."
    fi

    echo ""
    echo "Installed: $repo"
    echo "Location: $dest"
    echo ""
    echo "Load with: dc_load_plugin '$dest'"
}

#-------------------------------------------------------------------------------
# dc_plugin_remove - Remove an installed plugin
#-------------------------------------------------------------------------------
dc_plugin_remove() {
    local name="$1"
    [[ -z "$name" ]] && { echo "Usage: dcx plugin remove <plugin-name>"; return 1; }

    local plugin_dir
    plugin_dir=$(_dc_find_plugin_by_name "$name") || { echo "Plugin not found: $name"; return 1; }

    dc_confirm "Remove plugin '$name' from $plugin_dir?" || { echo "Cancelled."; return 0; }

    rm -rf "$plugin_dir"
    echo "Removed: $name"
    unset "_DC_LOADED_PLUGINS[$name]" 2>/dev/null || true
}

#-------------------------------------------------------------------------------
# dc_plugin_update - Update a plugin
#-------------------------------------------------------------------------------
dc_plugin_update() {
    local name="${1:-}"

    # Update all if no name specified
    if [[ -z "$name" ]]; then
        echo "Updating all plugins..."
        while IFS= read -r plugin_dir; do
            [[ -z "$plugin_dir" ]] && continue
            if [[ -d "$plugin_dir/.git" ]]; then
                echo "Updating: $(dc_plugin_info "$plugin_dir" "name")"
                (cd "$plugin_dir" && git pull --ff-only 2>/dev/null) || echo "  Failed to update"
            fi
        done < <(dc_discover_plugins)
        return 0
    fi

    # Update specific plugin
    local plugin_dir
    plugin_dir=$(_dc_find_plugin_by_name "$name") || { echo "Plugin not found: $name"; return 1; }
    [[ -d "$plugin_dir/.git" ]] || { echo "Plugin was not installed from git: $name"; return 1; }

    echo "Updating: $name"
    (cd "$plugin_dir" && git pull --ff-only)
}

#===============================================================================
# CLI COMMAND
#===============================================================================

#-------------------------------------------------------------------------------
# dc_plugin_cmd - CLI command handler for 'dcx plugin'
#-------------------------------------------------------------------------------
dc_plugin_cmd() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        list|ls)
            dc_plugin_list "${1:-table}"
            ;;
        install|add)
            dc_plugin_install "$@"
            ;;
        remove|rm)
            dc_plugin_remove "$@"
            ;;
        update|upgrade)
            dc_plugin_update "$@"
            ;;
        info)
            local name="$1" dir
            [[ -z "$name" ]] && { echo "Usage: dcx plugin info <name>"; return 1; }
            dir=$(_dc_find_plugin_by_name "$name") || { echo "Plugin not found: $name"; return 1; }
            dc_plugin_info "$dir"
            ;;
        load)
            local name="$1" dir
            [[ -z "$name" ]] && { echo "Usage: dcx plugin load <name>"; return 1; }
            dir=$(_dc_find_plugin_by_name "$name") || { echo "Plugin not found: $name"; return 1; }
            dc_load_plugin "$dir"
            echo "Loaded: $name"
            ;;
        help|*)
            cat << 'EOF'
Usage: dcx plugin <command> [options]

Commands:
  list [format]      List plugins (table, json, simple)
  install <repo>     Install plugin from GitHub
  remove <name>      Remove plugin
  update [name]      Update plugin(s)
  info <name>        Show plugin details
  load <name>        Load a plugin
  help               Show this help

Examples:
  dcx plugin list
  dcx plugin install datacosmos-br/dc-scripts-oracle
  dcx plugin remove dc-scripts-oracle
  dcx plugin update
EOF
            ;;
    esac
}
