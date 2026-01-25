#!/usr/bin/env bash
#===============================================================================
# dcx/lib/shared.sh - Shared Utility Functions
#===============================================================================
# Functions shared between install.sh, update.sh, and Makefile
# NOTE: Platform detection and constants are in lib/constants.sh
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DC_SHARED_LOADED:-}" ]] && return 0
declare -r _DC_SHARED_LOADED=1

# Load constants (provides dc_detect_platform, DCX_GITHUB_REPO, etc.)
# shellcheck source=constants.sh
source "${BASH_SOURCE[0]%/*}/constants.sh"

#===============================================================================
# LOGGING
#===============================================================================

dc_log() {
    echo "[INFO] $*"
}

dc_warn() {
    echo "[WARN] $*" >&2
}

dc_error() {
    echo "[ERROR] $*" >&2
    exit 1
}

#===============================================================================
# DIRECTORY MANAGEMENT
#===============================================================================

dc_create_install_dirs() {
    local install_dir="$1"
    mkdir -p "$install_dir"/{bin,lib,etc,plugins,share/completions}
}

dc_copy_install_files() {
    local source_dir="$1"
    local install_dir="$2"

    # Ensure directories exist
    mkdir -p "$install_dir"/{bin,lib,etc}

    # Copy core files
    cp -r "${source_dir}/lib/"* "$install_dir/lib/" 2>/dev/null || true
    cp -r "${source_dir}/etc/"* "$install_dir/etc/" 2>/dev/null || true
    [[ -d "${source_dir}/bin/completions" ]] && cp -r "${source_dir}/bin/completions" "$install_dir/bin/" 2>/dev/null || true
    [[ -f "${source_dir}/bin/dcx" ]] && cp "${source_dir}/bin/dcx" "$install_dir/bin/" 2>/dev/null || true
    cp "${source_dir}/VERSION" "$install_dir/" 2>/dev/null || true

    # Copy Go binaries (dcx-linux-amd64, dcx-darwin-arm64, etc.)
    for binary in "${source_dir}"/bin/dcx-*; do
        [[ -f "$binary" ]] && cp "$binary" "$install_dir/bin/" 2>/dev/null || true
    done
}

#===============================================================================
# BINARY MANAGEMENT
#===============================================================================

dc_setup_binary_symlinks() {
    local install_dir="$1"
    local platform="${2:-$DCX_PLATFORM}"

    # Go tools
    for tool in gum yq; do
        if [[ -f "$install_dir/bin/${tool}-${platform}" ]]; then
            ln -sf "${tool}-${platform}" "$install_dir/bin/${tool}"
        fi
    done

    # Rust tools (optional)
    for tool in rg fd sd; do
        if [[ -f "$install_dir/bin/${tool}-${platform}" ]]; then
            ln -sf "${tool}-${platform}" "$install_dir/bin/${tool}"
        fi
    done
}

#===============================================================================
# DOWNLOAD AND EXTRACTION
#===============================================================================

dc_download_file() {
    local url="$1"
    local output="$2"

    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget &>/dev/null; then
        wget -q "$url" -O "$output"
    else
        dc_error "Neither curl nor wget found"
    fi
}

dc_extract_tarball() {
    local tarball="$1"
    local dest_dir="$2"

    tar -xzf "$tarball" -C "$dest_dir"
}

#===============================================================================
# INSTALLATION
#===============================================================================

# Install from local source directory
dc_install_local() {
    local source_dir="$1"
    local prefix="${2:-$HOME/.local}"
    local install_dir="${prefix}/share/${DCX_PROJECT_NAME}"

    dc_log "Installing ${DCX_PROJECT_NAME} v${DCX_VERSION} from local source..."

    # Create directories
    dc_create_install_dirs "$install_dir"
    mkdir -p "${prefix}/bin"

    # Copy files
    dc_copy_install_files "$source_dir" "$install_dir"

    # Setup binary symlinks
    dc_setup_binary_symlinks "$install_dir"

    # Copy dcx wrapper to prefix/bin (only this is exposed to PATH)
    # The wrapper auto-detects DCX_HOME and finds binaries in share/dcx/bin/
    if [[ -f "$install_dir/bin/dcx" ]]; then
        cp "$install_dir/bin/dcx" "${prefix}/bin/dcx"
        chmod +x "${prefix}/bin/dcx"
    fi

    dc_log "Installed to ${install_dir}"
    echo ""
    echo "Add to your shell profile:"
    echo "  export PATH=\"${prefix}/bin:\$PATH\""
}

# Install specific version from GitHub
dc_install_version() {
    local version="$1"
    local target_dir="$2"
    local repo="${3:-$DCX_GITHUB_REPO}"
    local platform="${DCX_PLATFORM}"

    # Create temp directory
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    # Determine download URLs
    local name="${DCX_PROJECT_NAME}"
    local platform_url="https://github.com/${repo}/releases/download/v${version}/${name}-${version}-${platform}.tar.gz"
    local full_url="https://github.com/${repo}/releases/download/v${version}/${name}-${version}.tar.gz"

    local download_url=""
    local download_name=""

    dc_log "Detecting best download for v${version}..."

    # Check if platform-specific release exists
    if command -v curl &>/dev/null; then
        if curl -fsSL --head "$platform_url" &>/dev/null 2>&1; then
            download_url="$platform_url"
            download_name="${name}-${version}-${platform}.tar.gz"
        else
            download_url="$full_url"
            download_name="${name}-${version}.tar.gz"
        fi
    else
        download_url="$full_url"
        download_name="${name}-${version}.tar.gz"
    fi

    dc_log "Downloading ${download_name}..."
    dc_download_file "$download_url" "$tmp_dir/$download_name"

    dc_log "Extracting..."
    dc_extract_tarball "$tmp_dir/$download_name" "$tmp_dir"

    # Find extracted directory
    local extracted_dir
    extracted_dir=$(find "$tmp_dir" -maxdepth 1 -type d -name "${name}-*" | head -1)
    [[ -z "$extracted_dir" ]] && extracted_dir="$tmp_dir"

    # Install to target directory
    dc_log "Installing to ${target_dir}..."
    dc_create_install_dirs "$target_dir"
    dc_copy_install_files "$extracted_dir" "$target_dir"
    dc_setup_binary_symlinks "$target_dir"

    dc_log "Installation complete: ${target_dir}"
}
