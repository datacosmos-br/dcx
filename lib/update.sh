#!/usr/bin/env bash
#===============================================================================
# dc-scripts/lib/update.sh - Auto-Update & Version Management
#===============================================================================
# Dependencies: curl/wget, gum (optional)
# License: MIT
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DC_UPDATE_LOADED:-}" ]] && return 0
declare -r _DC_UPDATE_LOADED=1

# Load shared functions
if [[ -f "${DC_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/shared.sh" ]]; then
    # shellcheck source=/dev/null
    source "${DC_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/shared.sh"
fi

#===============================================================================
# CONSTANTS
#===============================================================================

readonly DC_GITHUB_REPO="datacosmos-br/dcx"
readonly DC_GITHUB_API="https://api.github.com/repos/${DC_GITHUB_REPO}"
readonly DC_GITHUB_RELEASES="${DC_GITHUB_API}/releases"

#===============================================================================
# VERSION FUNCTIONS
#===============================================================================

#-------------------------------------------------------------------------------
# dc_current_version - Get current installed version
#-------------------------------------------------------------------------------
dc_current_version() {
    local version_file="${DC_HOME:-}/VERSION"
    if [[ -f "$version_file" ]]; then
        cat "$version_file"
    else
        echo "unknown"
    fi
}

#-------------------------------------------------------------------------------
# dc_get_latest_version - Get latest version from GitHub
#-------------------------------------------------------------------------------
dc_get_latest_version() {
    local api_url="${DC_GITHUB_RELEASES}/latest"
    local version=""

    if command -v curl &>/dev/null; then
        version=$(curl -fsSL "$api_url" 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    elif command -v wget &>/dev/null; then
        version=$(wget -qO- "$api_url" 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    fi

    echo "$version"
}

#-------------------------------------------------------------------------------
# dc_check_update - Check if update is available
#-------------------------------------------------------------------------------
# Returns: New version string if update available, empty otherwise
#-------------------------------------------------------------------------------
dc_check_update() {
    local current
    current=$(dc_current_version)

    if [[ "$current" == "unknown" ]]; then
        echo ""
        return 1
    fi

    local latest
    latest=$(dc_get_latest_version)

    if [[ -z "$latest" ]]; then
        echo ""
        return 1
    fi

    # Compare versions (simple string comparison)
    if [[ "$current" != "$latest" ]]; then
        echo "$latest"
        return 0
    fi

    echo ""
    return 1
}

#===============================================================================
# PLATFORM DETECTION
#===============================================================================

#-------------------------------------------------------------------------------
# _dc_detect_platform - Alias for dc_detect_platform (shared)
#-------------------------------------------------------------------------------
_dc_detect_platform() {
    dc_detect_platform
}

#===============================================================================
# UPDATE FUNCTIONS
#===============================================================================

#-------------------------------------------------------------------------------
# dc_self_update - Download and install latest version
#-------------------------------------------------------------------------------
dc_self_update() {
    local target_version="${1:-}"

    # Get current version
    local current
    current=$(dc_current_version)
    echo "Current version: v$current"

    # Get latest if not specified
    if [[ -z "$target_version" ]]; then
        echo "Checking for updates..."
        target_version=$(dc_get_latest_version)

        if [[ -z "$target_version" ]]; then
            echo "Could not determine latest version."
            return 1
        fi
    fi

    echo "Latest version: v$target_version"

    # Check if update needed
    if [[ "$current" == "$target_version" ]]; then
        echo ""
        echo "Already up to date!"
        return 0
    fi

    # Confirm update
    local do_update=false
    if [[ -t 0 && -t 1 ]]; then
        # Interactive mode - ask for confirmation
        if command -v gum &>/dev/null; then
            if gum confirm "Update from v$current to v$target_version?"; then
                do_update=true
            fi
        else
            read -r -p "Update from v$current to v$target_version? [y/N] " response
            [[ "$response" =~ ^[Yy] ]] && do_update=true
        fi
    else
        # Non-interactive mode - assume yes
        echo "Non-interactive mode: proceeding with update..."
        do_update=true
    fi

    if [[ "$do_update" != "true" ]]; then
        echo "Update cancelled."
        return 0
    fi

    # Perform update
    _dc_download_and_install "$target_version"
}

#-------------------------------------------------------------------------------
# _dc_download_and_install - Download and install specific version
#-------------------------------------------------------------------------------
_dc_download_and_install() {
    local version="$1"
    local platform
    platform=$(_dc_detect_platform)

    # Create temp directory
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    # Try platform-specific release first
    local platform_url="https://github.com/${DC_GITHUB_REPO}/releases/download/v${version}/dc-scripts-${version}-${platform}.tar.gz"
    local full_url="https://github.com/${DC_GITHUB_REPO}/releases/download/v${version}/dc-scripts-${version}.tar.gz"

    local download_url=""
    local download_name=""

    echo ""
    echo "Detecting best download..."

    # Check if platform-specific release exists
    if command -v curl &>/dev/null; then
        if curl -fsSL --head "$platform_url" &>/dev/null; then
            download_url="$platform_url"
            download_name="dc-scripts-${version}-${platform}.tar.gz"
        else
            download_url="$full_url"
            download_name="dc-scripts-${version}.tar.gz"
        fi
    else
        download_url="$full_url"
        download_name="dc-scripts-${version}.tar.gz"
    fi

    echo "Downloading: $download_name"

    # Download
    local download_msg="Downloading update..."
    echo "$download_msg"
    dc_download_file "$download_url" "$tmp_dir/$download_name"

    echo "Extracting..."
    dc_extract_tarball "$tmp_dir/$download_name" "$tmp_dir"

    # Find extracted directory
    local extracted_dir
    extracted_dir=$(find "$tmp_dir" -maxdepth 1 -type d -name "dc-scripts-*" | head -1)

    if [[ -z "$extracted_dir" ]]; then
        extracted_dir="$tmp_dir"
    fi

    # Install
    local dc_home="${DC_HOME:-$HOME/.local/share/DCX}"

    # Backup current installation
    if [[ -d "$dc_home" ]]; then
        local backup_dir
        backup_dir="${dc_home}.backup.$(date +%Y%m%d%H%M%S)"
        echo "Backing up to: $backup_dir"
        mv "$dc_home" "$backup_dir"
    fi

    dc_install_version "$version" "$dc_home" "$DC_GITHUB_REPO"

    echo ""
    echo "Successfully updated to v$version!"
    echo ""
    echo "Restart your shell or run: source $dc_home/lib/core.sh"
}

#===============================================================================
# BINARY MANAGEMENT
#===============================================================================

#-------------------------------------------------------------------------------
# dc_check_binaries - Check if required binaries are present
#-------------------------------------------------------------------------------
dc_check_binaries() {
    local dc_home="${DC_HOME:-$HOME/.local/share/dc-scripts}"
    local platform
    platform=$(_dc_detect_platform)

    local missing=()
    local present=()

    # Check Go tools
    for tool in gum yq; do
        if [[ -x "$dc_home/bin/${tool}-${platform}" ]] || [[ -x "$dc_home/bin/$tool" ]]; then
            present+=("$tool")
        else
            missing+=("$tool")
        fi
    done

    # Check Rust tools
    for tool in rg fd sd frawk coreutils; do
        if [[ -x "$dc_home/bin/${tool}-${platform}" ]] || [[ -x "$dc_home/bin/$tool" ]]; then
            present+=("$tool")
        else
            missing+=("$tool")
        fi
    done

    # Report
    echo "Platform: $platform"
    echo ""
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
        echo ""
        echo "Run 'dcx update' to download missing binaries."
        return 1
    fi

    return 0
}

#-------------------------------------------------------------------------------
# dc_install_binary - Download and install a specific binary
#-------------------------------------------------------------------------------
dc_install_binary() {
    local tool="$1"
    local platform
    platform=$(_dc_detect_platform)

    local dc_home="${DC_HOME:-$HOME/.local/share/dc-scripts}"
    local version
    version=$(dc_current_version)

    if [[ "$version" == "unknown" ]]; then
        echo "Cannot determine version. Please run: dcx update"
        return 1
    fi

    local url="https://github.com/${DC_GITHUB_REPO}/releases/download/v${version}/${tool}-${platform}"

    echo "Downloading $tool for $platform..."

    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$dc_home/bin/${tool}-${platform}"
    else
        wget -q "$url" -O "$dc_home/bin/${tool}-${platform}"
    fi

    if [[ -f "$dc_home/bin/${tool}-${platform}" ]]; then
        chmod +x "$dc_home/bin/${tool}-${platform}"
        ln -sf "${tool}-${platform}" "$dc_home/bin/$tool"
        echo "Installed: $tool"
    else
        echo "Failed to download: $tool"
        return 1
    fi
}

#===============================================================================
# AUTO-UPDATE CHECK
#===============================================================================

#-------------------------------------------------------------------------------
# dc_maybe_check_update - Check for updates if interval has passed
#-------------------------------------------------------------------------------
dc_maybe_check_update() {
    local dc_home="${DC_HOME:-$HOME/.local/share/dc-scripts}"
    local last_check_file="$dc_home/.last_update_check"
    local check_interval="${DC_UPDATE_CHECK_INTERVAL:-86400}"  # Default: 24 hours

    # Skip if auto-check disabled
    if [[ "${DC_UPDATE_AUTO_CHECK:-true}" == "false" ]]; then
        return 0
    fi

    # Get last check time
    local last_check=0
    if [[ -f "$last_check_file" ]]; then
        last_check=$(cat "$last_check_file" 2>/dev/null || echo 0)
    fi

    local now
    now=$(date +%s)
    local elapsed=$((now - last_check))

    # Check if interval has passed
    if [[ $elapsed -lt $check_interval ]]; then
        return 0
    fi

    # Update last check time
    echo "$now" > "$last_check_file"

    # Check for updates (in background to not block startup)
    (
        local latest
        latest=$(dc_get_latest_version 2>/dev/null)
        local current
        current=$(dc_current_version)

        if [[ -n "$latest" && "$current" != "$latest" && "$current" != "unknown" ]]; then
            echo ""
            echo "New version available: v$latest (current: v$current)"
            echo "Run 'dcx update' to install."
            echo ""
        fi
    ) &
}

#===============================================================================
# RELEASE INFO
#===============================================================================

#-------------------------------------------------------------------------------
# dc_release_notes - Get release notes for a version
#-------------------------------------------------------------------------------
dc_release_notes() {
    local version="${1:-}"

    if [[ -z "$version" ]]; then
        version=$(dc_get_latest_version)
    fi

    if [[ -z "$version" ]]; then
        echo "Could not determine version."
        return 1
    fi

    local url="${DC_GITHUB_RELEASES}/tags/v${version}"

    echo "Release notes for v$version:"
    echo ""

    if command -v curl &>/dev/null; then
        curl -fsSL "$url" 2>/dev/null | grep '"body"' | sed 's/.*"body": "\(.*\)".*/\1/' | sed 's/\\n/\n/g' | sed 's/\\r//g'
    elif command -v wget &>/dev/null; then
        wget -qO- "$url" 2>/dev/null | grep '"body"' | sed 's/.*"body": "\(.*\)".*/\1/' | sed 's/\\n/\n/g' | sed 's/\\r//g'
    fi
}
