#!/usr/bin/env bash
#===============================================================================
# install.sh - dc-scripts installer
#===============================================================================
# Downloads dc-scripts from GitHub Releases (includes pre-compiled binaries)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/datacosmos-br/dc-scripts/main/install.sh | bash
#   ./install.sh [--prefix /custom/path] [--version 0.2.0]
#===============================================================================

set -euo pipefail

# Configuration
NAME="dc-scripts"
REPO="datacosmos-br/dc-scripts"
DEFAULT_PREFIX="${HOME}/.local"

# Parse arguments
PREFIX="$DEFAULT_PREFIX"
VERSION=""
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
        --help|-h)
            echo "Usage: $0 [--prefix /path] [--version X.Y.Z]"
            echo ""
            echo "Options:"
            echo "  --prefix PATH     Installation prefix (default: ~/.local)"
            echo "  --version X.Y.Z   Specific version to install (default: latest)"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

INSTALL_DIR="${PREFIX}/share/${NAME}"
BIN_DIR="${PREFIX}/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${CYAN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }

#-------------------------------------------------------------------------------
# Detect platform
#-------------------------------------------------------------------------------
detect_platform() {
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

#-------------------------------------------------------------------------------
# Get latest version from GitHub API
#-------------------------------------------------------------------------------
get_latest_version() {
    local api_url="https://api.github.com/repos/${REPO}/releases/latest"

    if command -v curl &>/dev/null; then
        curl -fsSL "$api_url" 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/' || echo ""
    elif command -v wget &>/dev/null; then
        wget -qO- "$api_url" 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/' || echo ""
    fi
}

#-------------------------------------------------------------------------------
# Check basic dependencies (curl or wget)
#-------------------------------------------------------------------------------
check_deps() {
    log "Checking dependencies..."

    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi

    if ! command -v tar &>/dev/null; then
        error "tar not found. Please install tar."
        exit 1
    fi

    success "Dependencies OK"
}

#-------------------------------------------------------------------------------
# Install from local directory (for local ./install.sh runs)
#-------------------------------------------------------------------------------
install_local() {
    local source_dir="$1"

    log "Installing from local directory: $source_dir"

    # Create directories
    mkdir -p "$INSTALL_DIR"/{bin,lib,etc,plugins}
    mkdir -p "$BIN_DIR"

    # Copy files
    cp -r "${source_dir}/lib/"* "$INSTALL_DIR/lib/" 2>/dev/null || true
    cp -r "${source_dir}/etc/"* "$INSTALL_DIR/etc/" 2>/dev/null || true
    cp -r "${source_dir}/bin/"* "$INSTALL_DIR/bin/" 2>/dev/null || true
    cp "${source_dir}/VERSION" "$INSTALL_DIR/" 2>/dev/null || true

    # Create platform symlinks for binaries
    local platform
    platform=$(detect_platform)

    if [[ -f "$INSTALL_DIR/bin/gum-${platform}" ]]; then
        ln -sf "gum-${platform}" "$INSTALL_DIR/bin/gum"
    fi
    if [[ -f "$INSTALL_DIR/bin/yq-${platform}" ]]; then
        ln -sf "yq-${platform}" "$INSTALL_DIR/bin/yq"
    fi

    # Copy dcx to user bin (or create symlink)
    if [[ -f "$INSTALL_DIR/bin/dcx" ]]; then
        cp "$INSTALL_DIR/bin/dcx" "$BIN_DIR/dcx"
        chmod +x "$BIN_DIR/dcx"
    fi

    success "Installed to $INSTALL_DIR"
}

#-------------------------------------------------------------------------------
# Install from GitHub Releases
#-------------------------------------------------------------------------------
install_github() {
    local version="$1"
    local platform
    platform=$(detect_platform)

    log "Installing dc-scripts v${version} for ${platform}..."

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    # Try platform-specific release first (smaller download)
    local platform_url="https://github.com/${REPO}/releases/download/v${version}/${NAME}-${version}-${platform}.tar.gz"
    local full_url="https://github.com/${REPO}/releases/download/v${version}/${NAME}-${version}.tar.gz"

    local download_url=""
    local download_name=""

    # Check if platform-specific release exists
    if command -v curl &>/dev/null; then
        if curl -fsSL --head "$platform_url" &>/dev/null; then
            download_url="$platform_url"
            download_name="${NAME}-${version}-${platform}.tar.gz"
        else
            download_url="$full_url"
            download_name="${NAME}-${version}.tar.gz"
        fi
    else
        # Fallback to full release
        download_url="$full_url"
        download_name="${NAME}-${version}.tar.gz"
    fi

    log "Downloading from ${download_url}..."

    # Download and extract
    if command -v curl &>/dev/null; then
        curl -fsSL "$download_url" -o "$tmp_dir/$download_name"
    else
        wget -q "$download_url" -O "$tmp_dir/$download_name"
    fi

    # Extract
    tar -xzf "$tmp_dir/$download_name" -C "$tmp_dir"

    # Find extracted directory
    local extracted_dir
    extracted_dir=$(find "$tmp_dir" -maxdepth 1 -type d -name "${NAME}-*" | head -1)

    if [[ -z "$extracted_dir" ]]; then
        # Files might be extracted directly
        extracted_dir="$tmp_dir"
    fi

    install_local "$extracted_dir"
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    echo ""
    echo "dc-scripts Installer"
    echo "===================="
    echo ""

    check_deps

    # Determine installation source
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ -f "${script_dir}/lib/core.sh" ]]; then
        # Local installation (running from cloned repo or extracted tarball)
        install_local "$script_dir"
    else
        # Remote installation from GitHub Releases
        if [[ -z "$VERSION" ]]; then
            log "Fetching latest version..."
            VERSION=$(get_latest_version)
            if [[ -z "$VERSION" ]]; then
                error "Could not determine latest version. Please specify with --version"
                exit 1
            fi
            log "Latest version: $VERSION"
        fi

        install_github "$VERSION"
    fi

    # Show post-install message
    echo ""
    success "Installation complete!"
    echo ""
    echo "Usage:"
    echo ""
    echo "  dcx version             # Show version"
    echo "  dcx help                # Show help"
    echo "  dcx update              # Check for updates"
    echo "  dcx plugin list         # List plugins"
    echo ""
    echo "In your scripts:"
    echo ""
    echo "  source ${INSTALL_DIR}/lib/core.sh"
    echo "  dc_load"
    echo ""

    # Check if bin is in PATH
    if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
        warn "Add ${BIN_DIR} to your PATH:"
        echo ""
        echo "  export PATH=\"\$PATH:${BIN_DIR}\""
        echo ""
    fi
}

main "$@"
