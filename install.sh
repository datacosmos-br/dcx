#!/usr/bin/env bash
#===============================================================================
# install.sh - DCX Installer
#===============================================================================
# Usage:
#   From GitHub (remote):
#     curl -fsSL https://raw.githubusercontent.com/datacosmos-br/dc-scripts/main/install.sh | bash
#     curl -fsSL ... | bash -s -- --prefix /custom/path
#
#   From local clone:
#     ./install.sh [--prefix /path] [--version X.Y.Z]
#===============================================================================

set -euo pipefail

# Defaults (can be overridden by lib/constants.sh if available)
PROJECT_NAME="${DC_PROJECT_NAME:-DCX}"
PROJECT_REPO="${DC_GITHUB_REPO:-datacosmos-br/dc-scripts}"
DEFAULT_PREFIX="${HOME}/.local"

#===============================================================================
# ARGUMENT PARSING
#===============================================================================

PREFIX="$DEFAULT_PREFIX"
VERSION=""
LOCAL_INSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --local)
            LOCAL_INSTALL=true
            shift
            ;;
        --help|-h)
            cat << EOF
DCX Installer

Usage: $0 [OPTIONS]

Options:
  --prefix PATH     Installation prefix (default: ~/.local)
  --version X.Y.Z   Install specific version (default: latest)
  --local           Install from local directory (for development)
  --help            Show this help message

Examples:
  # Install latest from GitHub
  curl -fsSL https://raw.githubusercontent.com/datacosmos-br/dc-scripts/main/install.sh | bash

  # Install to custom prefix
  ./install.sh --prefix /opt/dcx

  # Install from local clone (development)
  ./install.sh --local
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

#===============================================================================
# DETECT INSTALLATION MODE
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""

# Check if running from local repository
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/lib/shared.sh" ]]; then
    #===========================================================================
    # LOCAL INSTALLATION (from git clone or extracted tarball)
    #===========================================================================

    # Load shared functions (includes constants.sh)
    # shellcheck source=lib/shared.sh
    source "$SCRIPT_DIR/lib/shared.sh"

    echo ""
    echo "${DC_PROJECT_NAME} - Local Installation"
    echo "========================================"
    echo ""

    dc_install_local "$SCRIPT_DIR" "$PREFIX"

else
    #===========================================================================
    # REMOTE INSTALLATION (from curl | bash)
    #===========================================================================

    echo ""
    echo "${PROJECT_NAME} - Remote Installation"
    echo "======================================="
    echo ""

    # Minimal bootstrap functions (no dependencies on lib/)

    _log() { echo "[INFO] $*"; }
    _error() { echo "[ERROR] $*" >&2; exit 1; }

    _detect_platform() {
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

    _download() {
        local url="$1" output="$2"
        if command -v curl &>/dev/null; then
            curl -fsSL "$url" -o "$output"
        elif command -v wget &>/dev/null; then
            wget -q "$url" -O "$output"
        else
            _error "Neither curl nor wget found"
        fi
    }

    _get_latest_version() {
        local api_url="https://api.github.com/repos/${PROJECT_REPO}/releases/latest"
        if command -v curl &>/dev/null; then
            curl -fsSL "$api_url" 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/'
        elif command -v wget &>/dev/null; then
            wget -qO- "$api_url" 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/'
        fi
    }

    # Check dependencies
    _log "Checking dependencies..."
    command -v curl &>/dev/null || command -v wget &>/dev/null || _error "curl or wget required"
    command -v tar &>/dev/null || _error "tar required"

    # Determine version
    if [[ -z "$VERSION" ]]; then
        _log "Fetching latest version..."
        VERSION=$(_get_latest_version)
        [[ -z "$VERSION" ]] && _error "Could not determine latest version"
    fi
    _log "Installing version: v${VERSION}"

    # Setup paths
    PLATFORM=$(_detect_platform)
    INSTALL_DIR="${PREFIX}/share/${PROJECT_NAME}"
    BIN_DIR="${PREFIX}/bin"

    # Create temp directory
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    # Download
    TARBALL_NAME="${PROJECT_NAME}-${VERSION}.tar.gz"
    DOWNLOAD_URL="https://github.com/${PROJECT_REPO}/releases/download/v${VERSION}/${TARBALL_NAME}"

    _log "Downloading ${TARBALL_NAME}..."
    _download "$DOWNLOAD_URL" "$TMP_DIR/$TARBALL_NAME"

    # Extract
    _log "Extracting..."
    tar -xzf "$TMP_DIR/$TARBALL_NAME" -C "$TMP_DIR"

    # Find extracted directory
    EXTRACTED_DIR=$(find "$TMP_DIR" -maxdepth 1 -type d -name "${PROJECT_NAME}-*" | head -1)
    [[ -z "$EXTRACTED_DIR" ]] && EXTRACTED_DIR="$TMP_DIR"

    # Install
    _log "Installing to ${INSTALL_DIR}..."
    mkdir -p "$INSTALL_DIR"/{bin,lib,etc,plugins,share/completions}
    mkdir -p "$BIN_DIR"

    cp -r "$EXTRACTED_DIR/lib/"* "$INSTALL_DIR/lib/" 2>/dev/null || true
    cp -r "$EXTRACTED_DIR/etc/"* "$INSTALL_DIR/etc/" 2>/dev/null || true
    cp -r "$EXTRACTED_DIR/bin/"* "$INSTALL_DIR/bin/" 2>/dev/null || true
    cp "$EXTRACTED_DIR/VERSION" "$INSTALL_DIR/" 2>/dev/null || true

    # Setup dcx command (only the wrapper is exposed to user's PATH)
    # Go binary and tools stay internal in share/DCX/bin/
    if [[ -f "$INSTALL_DIR/bin/dcx" ]]; then
        cp "$INSTALL_DIR/bin/dcx" "$BIN_DIR/dcx"
        chmod +x "$BIN_DIR/dcx"
    fi

    _log "Installation complete!"

    # Download tools for current platform
    _log "Downloading tools for ${PLATFORM}..."
    if "$BIN_DIR/dcx" tools install --all 2>/dev/null; then
        _log "Tools installed successfully"
    else
        echo "[WARN] Could not download tools automatically. Run 'dcx tools install --all' later."
    fi
fi

#===============================================================================
# POST-INSTALL MESSAGE
#===============================================================================

echo ""
echo "Installation complete!"
echo ""
echo "Usage:"
echo "  dcx version     # Show version"
echo "  dcx help        # Show help"
echo "  dcx update      # Check for updates"
echo ""

# Check if bin is in PATH
if [[ ":$PATH:" != *":${PREFIX}/bin:"* ]]; then
    echo "Add to your shell profile:"
    echo "  export PATH=\"${PREFIX}/bin:\$PATH\""
    echo ""
fi
