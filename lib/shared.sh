#!/usr/bin/env bash
#===============================================================================
# dc-scripts/lib/shared.sh - Shared functions for install.sh, update.sh, Makefile
#===============================================================================
# Functions shared between installation scripts and build tools
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DC_SHARED_LOADED:-}" ]] && return 0
declare -r _DC_SHARED_LOADED=1

#===============================================================================
# PLATFORM DETECTION
#===============================================================================

#-------------------------------------------------------------------------------
# dc_detect_platform - Detect current platform (shared implementation)
#-------------------------------------------------------------------------------
dc_detect_platform() {
    local os arch
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)

    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        i386|i686) arch="386" ;;
    esac

    echo "${os}-${arch}"
}

#===============================================================================
# DIRECTORY MANAGEMENT
#===============================================================================

#-------------------------------------------------------------------------------
# dc_create_install_dirs - Create standard installation directories
#-------------------------------------------------------------------------------
dc_create_install_dirs() {
    local install_dir="$1"
    mkdir -p "$install_dir"/{bin,lib,etc,plugins,share/completions}
}

#-------------------------------------------------------------------------------
# dc_copy_install_files - Copy files to installation directory
#-------------------------------------------------------------------------------
dc_copy_install_files() {
    local source_dir="$1"
    local install_dir="$2"

    # Copy core files
    cp -r "${source_dir}/lib/"* "$install_dir/lib/" 2>/dev/null || true
    cp -r "${source_dir}/etc/"* "$install_dir/etc/" 2>/dev/null || true
    cp -r "${source_dir}/bin/completions" "$install_dir/bin/" 2>/dev/null || true
    cp "${source_dir}/VERSION" "$install_dir/" 2>/dev/null || true
}

#===============================================================================
# BINARY MANAGEMENT
#===============================================================================

#-------------------------------------------------------------------------------
# dc_setup_binary_symlinks - Create symlinks for platform-specific binaries
#-------------------------------------------------------------------------------
dc_setup_binary_symlinks() {
    local install_dir="$1"
    local platform="$2"

    # Go tools
    for tool in gum yq; do
        if [[ -f "$install_dir/bin/${tool}-${platform}" ]]; then
            ln -sf "${tool}-${platform}" "$install_dir/bin/${tool}"
        fi
    done

    # Rust tools (optional)
    for tool in rg fd sd frawk coreutils; do
        if [[ -f "$install_dir/bin/${tool}-${platform}" ]]; then
            ln -sf "${tool}-${platform}" "$install_dir/bin/${tool}"
        fi
    done

    # Bash (optional)
    if [[ -f "$install_dir/bin/bash-${platform}" ]]; then
        ln -sf "bash-${platform}" "$install_dir/bin/bash"
    fi
}

#===============================================================================
# DOWNLOAD AND EXTRACTION
#===============================================================================

#-------------------------------------------------------------------------------
# dc_download_file - Download file with fallback to curl/wget
#-------------------------------------------------------------------------------
dc_download_file() {
    local url="$1"
    local output="$2"

    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget &>/dev/null; then
        wget -q "$url" -O "$output"
    else
        echo "ERROR: Neither curl nor wget found" >&2
        return 1
    fi
}

#-------------------------------------------------------------------------------
# dc_extract_tarball - Extract tarball to directory
#-------------------------------------------------------------------------------
dc_extract_tarball() {
    local tarball="$1"
    local dest_dir="$2"

    tar -xzf "$tarball" -C "$dest_dir"
}

#===============================================================================
# INSTALLATION
#===============================================================================

#-------------------------------------------------------------------------------
# dc_install_version - Install a specific version to target directory
#-------------------------------------------------------------------------------
dc_install_version() {
    local version="$1"
    local target_dir="$2"
    local repo="${3:-datacosmos-br/dcx}"

    local platform
    platform=$(dc_detect_platform)

    # Create temp directory
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    # Determine download URLs
    local platform_url="https://github.com/${repo}/releases/download/v${version}/dcx-${version}-${platform}.tar.gz"
    local full_url="https://github.com/${repo}/releases/download/v${version}/dcx-${version}.tar.gz"

    local download_url=""
    local download_name=""

    dc_log "Detecting best download for ${version}..."

    # Check if platform-specific release exists
    if command -v curl &>/dev/null; then
        if curl -fsSL --head "$platform_url" &>/dev/null 2>&1; then
            download_url="$platform_url"
            download_name="dcx-${version}-${platform}.tar.gz"
        else
            download_url="$full_url"
            download_name="dcx-${version}.tar.gz"
        fi
    else
        download_url="$full_url"
        download_name="dcx-${version}.tar.gz"
    fi

    dc_log "Downloading ${download_name}..."
    dc_download_file "$download_url" "$tmp_dir/$download_name"

    dc_log "Extracting..."
    dc_extract_tarball "$tmp_dir/$download_name" "$tmp_dir"

    # Find extracted directory
    local extracted_dir
    extracted_dir=$(find "$tmp_dir" -maxdepth 1 -type d -name "dcx-*" | head -1)

    if [[ -z "$extracted_dir" ]]; then
        # Files might be extracted directly
        extracted_dir="$tmp_dir"
    fi

    # Install to target directory
    dc_log "Installing to ${target_dir}..."
    dc_create_install_dirs "$target_dir"
    dc_copy_install_files "$extracted_dir" "$target_dir"
    dc_setup_binary_symlinks "$target_dir" "$platform"

    # Copy default config if it doesn't exist
    if [[ ! -f "$target_dir/etc/defaults.yaml" ]] && [[ -f "$extracted_dir/etc/defaults.yaml" ]]; then
        mkdir -p "$target_dir/etc"
        cp "$extracted_dir/etc/defaults.yaml" "$target_dir/etc/"
    fi

    dc_log "Installation complete: ${target_dir}"
}

#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

#-------------------------------------------------------------------------------
# dc_log - Simple logging function for scripts
#-------------------------------------------------------------------------------
dc_log() {
    echo "[INFO] $*"
}

#-------------------------------------------------------------------------------
# dc_warn - Warning message
#-------------------------------------------------------------------------------
dc_warn() {
    echo "[WARN] $*" >&2
}

#-------------------------------------------------------------------------------
# dc_error - Error message and exit
#-------------------------------------------------------------------------------
dc_error() {
    echo "[ERROR] $*" >&2
    exit 1
}