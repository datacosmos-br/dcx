#!/usr/bin/env bash
#===============================================================================
# dcx/lib/update.sh - Auto-Update & Version Management
#===============================================================================
# Dependencies: curl/wget, gum (optional for UI)
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DC_UPDATE_LOADED:-}" ]] && return 0
declare -r _DC_UPDATE_LOADED=1

# Load core (provides dc_detect_platform via Go), constants, and shared functions
# shellcheck source=core.sh
source "${BASH_SOURCE[0]%/*}/core.sh"
# shellcheck source=constants.sh
source "${BASH_SOURCE[0]%/*}/constants.sh"
# shellcheck source=shared.sh
source "${BASH_SOURCE[0]%/*}/shared.sh"

#===============================================================================
# VERSION FUNCTIONS
#===============================================================================

dc_current_version() {
    echo "$DCX_VERSION"
}

dc_get_latest_version() {
    local api_url="${DCX_GITHUB_RELEASES}/latest"
    local version=""

    if command -v curl &>/dev/null; then
        version=$(curl -fsSL "$api_url" 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    elif command -v wget &>/dev/null; then
        version=$(wget -qO- "$api_url" 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    fi

    echo "$version"
}

dc_check_update() {
    local current="$DCX_VERSION"

    if [[ "$current" == "unknown" || "$current" == "0.0.0" ]]; then
        echo ""
        return 1
    fi

    local latest
    latest=$(dc_get_latest_version)

    if [[ -z "$latest" ]]; then
        echo ""
        return 1
    fi

    if [[ "$current" != "$latest" ]]; then
        echo "$latest"
        return 0
    fi

    echo ""
    return 1
}

#===============================================================================
# UPDATE FUNCTIONS
#===============================================================================

dc_self_update() {
    local target_version="${1:-}"

    echo "${DCX_PROJECT_NAME} - Update"
    echo "========================"
    echo ""
    echo "Current version: v${DCX_VERSION}"

    # Get latest if not specified
    if [[ -z "$target_version" ]]; then
        echo "Checking for updates..."
        target_version=$(dc_get_latest_version)

        if [[ -z "$target_version" ]]; then
            echo "Could not determine latest version."
            return 1
        fi
    fi

    echo "Latest version:  v${target_version}"

    # Check if update needed
    if [[ "$DCX_VERSION" == "$target_version" ]]; then
        echo ""
        echo "Already up to date!"
        return 0
    fi

    # Confirm update (non-interactive mode auto-proceeds)
    if [[ ! -t 0 || ! -t 1 ]]; then
        echo "Non-interactive mode: proceeding with update..."
    elif ! dc_confirm "Update to v${target_version}?"; then
        echo "Update cancelled."
        return 0
    fi

    # Perform update
    _dc_perform_update "$target_version"
}

_dc_perform_update() {
    local version="$1"
    local dc_home="${DCX_HOME}"

    echo ""

    # Backup current installation
    if [[ -d "$dc_home" ]]; then
        local backup_dir="${dc_home}.backup.$(date +%Y%m%d%H%M%S)"
        echo "Backing up to: $backup_dir"
        cp -r "$dc_home" "$backup_dir"
    fi

    # Use shared installation function
    dc_install_version "$version" "$dc_home"

    echo ""
    echo "Successfully updated to v${version}!"
    echo ""
    echo "Restart your shell or run: source ${dc_home}/lib/core.sh"
}

#===============================================================================
# BINARY MANAGEMENT
#===============================================================================

dc_check_binaries() {
    local dc_home="${DCX_HOME}"
    local platform="${DCX_PLATFORM}"

    local missing=()
    local present=()

    echo "Platform: $platform"
    echo ""

    # Check Go tools
    for tool in gum yq; do
        if [[ -x "$dc_home/bin/${tool}-${platform}" ]] || [[ -x "$dc_home/bin/$tool" ]]; then
            present+=("$tool")
        else
            missing+=("$tool")
        fi
    done

    # Check Rust tools
    for tool in rg fd sd; do
        if [[ -x "$dc_home/bin/${tool}-${platform}" ]] || [[ -x "$dc_home/bin/$tool" ]]; then
            present+=("$tool")
        else
            missing+=("$tool (optional)")
        fi
    done

    echo "Present binaries:"
    for tool in "${present[@]}"; do
        echo "  [OK] $tool"
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        echo "Missing binaries:"
        for tool in "${missing[@]}"; do
            echo "  [!] $tool"
        done
        return 1
    fi

    return 0
}

#===============================================================================
# AUTO-UPDATE CHECK
#===============================================================================

dc_maybe_check_update() {
    local dc_home="${DCX_HOME}"
    local last_check_file="$dc_home/.last_update_check"
    local check_interval="${DCX_UPDATE_CHECK_INTERVAL:-86400}"

    # Skip if auto-check disabled
    if [[ "${DCX_UPDATE_AUTO_CHECK:-true}" == "false" ]]; then
        return 0
    fi

    # Get last check time
    local last_check=0
    [[ -f "$last_check_file" ]] && last_check=$(cat "$last_check_file" 2>/dev/null || echo 0)

    local now
    now=$(date +%s)
    local elapsed=$((now - last_check))

    # Check if interval has passed
    [[ $elapsed -lt $check_interval ]] && return 0

    # Update last check time
    echo "$now" > "$last_check_file" 2>/dev/null || true

    # Check for updates in background
    (
        local latest
        latest=$(dc_get_latest_version 2>/dev/null)

        if [[ -n "$latest" && "$DCX_VERSION" != "$latest" && "$DCX_VERSION" != "unknown" ]]; then
            echo ""
            echo "New version available: v$latest (current: v$DCX_VERSION)"
            echo "Run 'dcx update' to install."
            echo ""
        fi
    ) &
}

#===============================================================================
# RELEASE INFO
#===============================================================================

dc_release_notes() {
    local version="${1:-}"

    [[ -z "$version" ]] && version=$(dc_get_latest_version)

    if [[ -z "$version" ]]; then
        echo "Could not determine version."
        return 1
    fi

    local url="${DCX_GITHUB_RELEASES}/tags/v${version}"

    echo "Release notes for v$version:"
    echo ""

    if command -v curl &>/dev/null; then
        curl -fsSL "$url" 2>/dev/null | grep '"body"' | sed 's/.*"body": "\(.*\)".*/\1/' | sed 's/\\n/\n/g' | sed 's/\\r//g'
    elif command -v wget &>/dev/null; then
        wget -qO- "$url" 2>/dev/null | grep '"body"' | sed 's/.*"body": "\(.*\)".*/\1/' | sed 's/\\n/\n/g' | sed 's/\\r//g'
    fi
}
