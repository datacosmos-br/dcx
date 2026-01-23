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