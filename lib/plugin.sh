#!/usr/bin/env bash
#===============================================================================
# dcx/lib/plugin.sh - Plugin Discovery & Loading
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
declare -ga DCX_PLUGIN_DIRS=()

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
    DCX_PLUGIN_DIRS=()

    # 1. Installation directory plugins
    local dc_home="${DCX_HOME:-}"
    if [[ -n "$dc_home" && -d "$dc_home/plugins" ]]; then
        DCX_PLUGIN_DIRS+=("$dc_home/plugins")
    fi

    # 2. User plugins ($XDG_CONFIG_HOME or ~/.config)
    local user_plugins="${XDG_CONFIG_HOME:-$HOME/.config}/dcx/plugins"
    [[ -d "$user_plugins" ]] && DCX_PLUGIN_DIRS+=("$user_plugins")

    # 3. System plugins (optional)
    [[ -d "/usr/local/share/dcx/plugins" ]] && DCX_PLUGIN_DIRS+=("/usr/local/share/dcx/plugins")

    # 4. Local project plugins
    [[ -d ".dcx/plugins" ]] && DCX_PLUGIN_DIRS+=(".dcx/plugins")

    return 0
}

#-------------------------------------------------------------------------------
# dc_discover_plugins - Discover all available plugins
#-------------------------------------------------------------------------------
# Returns: List of plugin directories (one per line)
#-------------------------------------------------------------------------------
dc_discover_plugins() {
    # Initialize dirs if not done
    [[ ${#DCX_PLUGIN_DIRS[@]} -eq 0 ]] && dc_init_plugin_dirs

    for dir in "${DCX_PLUGIN_DIRS[@]}"; do
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

    # Note: Version check (requires.dcx) intentionally not implemented
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
        DCX_LIB_PATH="${DCX_LIB_PATH:-}:$plugin_dir/lib"
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
    if [[ "${DCX_DEBUG:-}" == "1" ]]; then
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
# dc_plugin_install - Install plugin(s) from GitHub
#-------------------------------------------------------------------------------
# Usage:
#   dcx plugin install oracle                    # Short name → dcx-oracle
#   dcx plugin install datacosmos-br/dcx-oracle  # Full repo path
#   dcx plugin install oracle,monitor,backup     # Multiple plugins
#-------------------------------------------------------------------------------

# Default plugin organization
DCX_PLUGIN_ORG="${DCX_PLUGIN_ORG:-datacosmos-br}"

# Resolve short plugin name to full repo
_dc_resolve_plugin_name() {
    local name="$1"

    # If already has a slash, it's a full repo path
    if [[ "$name" == *"/"* ]]; then
        echo "$name"
        return 0
    fi

    # Short name → datacosmos-br/dcx-<name>
    echo "${DCX_PLUGIN_ORG}/dcx-${name}"
}

# Install single plugin
_dc_install_single_plugin() {
    local input="$1"
    local repo

    repo=$(_dc_resolve_plugin_name "$input")
    local plugin_name
    plugin_name=$(basename "$repo")

    # Determine install directory
    local dest
    dest="${XDG_CONFIG_HOME:-$HOME/.config}/dcx/plugins/${plugin_name}"

    if [[ -d "$dest" ]]; then
        echo "Plugin already installed: $plugin_name"
        echo "Use 'dcx plugin update $plugin_name' to update."
        return 1
    fi

    echo "Installing plugin: $plugin_name (from $repo)"

    # Try install.sh first (preferred method)
    local install_url="https://raw.githubusercontent.com/${repo}/main/install.sh"
    local tmp_installer="/tmp/dcx-plugin-install-$$.sh"

    if curl -fsSL "$install_url" -o "$tmp_installer" 2>/dev/null; then
        echo "Using install.sh from $repo..."
        local gum_bin="${GUM:-gum}"
        if command -v "$gum_bin" &>/dev/null; then
            "$gum_bin" spin --title "Installing $plugin_name..." -- \
                bash "$tmp_installer" --prefix "${XDG_CONFIG_HOME:-$HOME/.config}/dcx/plugins"
        else
            bash "$tmp_installer" --prefix "${XDG_CONFIG_HOME:-$HOME/.config}/dcx/plugins"
        fi
        rm -f "$tmp_installer"
    else
        # Fallback: git clone
        echo "No install.sh found, using git clone..."
        local install_msg="Cloning $repo..."
        local gum_bin="${GUM:-gum}"
        if command -v "$gum_bin" &>/dev/null; then
            "$gum_bin" spin --title "$install_msg" -- \
                git clone --depth 1 "https://github.com/$repo.git" "$dest"
        else
            echo "$install_msg"
            git clone --depth 1 "https://github.com/$repo.git" "$dest"
        fi
    fi

    if [[ ! -d "$dest" ]]; then
        echo "Failed to install: $plugin_name"
        return 1
    fi

    # Verify it's a valid plugin
    if [[ ! -f "$dest/plugin.yaml" && ! -f "$dest/plugin.yml" ]]; then
        echo "Warning: No plugin.yaml found in $plugin_name"
        echo "This may not be a valid dcx plugin."
    fi

    echo ""
    echo "✓ Installed: $plugin_name"
    echo "  Location: $dest"
    return 0
}

dc_plugin_install() {
    local input="$1"

    if [[ -z "$input" || "$input" == "--help" || "$input" == "-h" ]]; then
        cat << 'EOF'
Usage: dcx plugin install <plugin> [plugin2] [plugin3] ...

Plugin names:
  oracle              Short name → datacosmos-br/dcx-oracle
  org/repo            Full GitHub repo path
  oracle,monitor      Comma-separated list

Examples:
  dcx plugin install oracle
  dcx plugin install oracle monitor backup
  dcx plugin install datacosmos-br/dcx-oracle
  dcx plugin install oracle,monitor,backup
EOF
        return 0
    fi

    # Collect all plugins to install
    local -a plugins=()

    # Process all arguments
    for arg in "$@"; do
        # Split by comma if present
        IFS=',' read -ra parts <<< "$arg"
        for part in "${parts[@]}"; do
            # Trim whitespace
            part="${part#"${part%%[![:space:]]*}"}"
            part="${part%"${part##*[![:space:]]}"}"
            [[ -n "$part" ]] && plugins+=("$part")
        done
    done

    # Install each plugin
    local success=0 failed=0
    for plugin in "${plugins[@]}"; do
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if _dc_install_single_plugin "$plugin"; then
            ((success++)) || true
        else
            ((failed++)) || true
        fi
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Installation complete: $success succeeded, $failed failed"

    [[ $failed -eq 0 ]]
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
  install <plugin>   Install plugin(s) from GitHub
  remove <name>      Remove plugin
  update [name]      Update plugin(s)
  info <name>        Show plugin details
  load <name>        Load a plugin
  help               Show this help

Install plugin names:
  oracle             Short name → datacosmos-br/dcx-oracle
  org/repo           Full GitHub repo path
  oracle,monitor     Comma-separated list

Examples:
  dcx plugin list
  dcx plugin install oracle
  dcx plugin install oracle monitor backup
  dcx plugin install datacosmos-br/dcx-oracle
  dcx plugin remove oracle
  dcx plugin update
EOF
            ;;
    esac
}
