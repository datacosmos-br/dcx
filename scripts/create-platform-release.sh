#!/usr/bin/env bash
#===============================================================================
# create-platform-release.sh - Cria tarball com tools para uma plataforma
#===============================================================================
# Usage: ./scripts/create-platform-release.sh <platform> <version> <output-dir>
# Example: ./scripts/create-platform-release.sh linux-amd64 0.0.1 release/
#
# Creates a platform-specific release tarball containing:
# - dcx binary for the target platform
# - All bundled tools (gum, yq, rg, fd, sd, sg) for the target platform
# - lib/, etc/, VERSION files
#===============================================================================

set -euo pipefail

# Arguments
PLATFORM="${1:?Usage: $0 <platform> <version> <output-dir>}"
VERSION="${2:?Missing version}"
OUTPUT_DIR="${3:?Missing output directory}"

# Constants
PROJECT_NAME="DCX"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

#===============================================================================
# TOOL DEFINITIONS
#===============================================================================
# URLs from etc/tools.yaml - hardcoded here for standalone operation

declare -A TOOL_URLS

# gum v0.14.5
TOOL_URLS["gum:linux-amd64"]="https://github.com/charmbracelet/gum/releases/download/v0.14.5/gum_0.14.5_Linux_x86_64.tar.gz"
TOOL_URLS["gum:linux-arm64"]="https://github.com/charmbracelet/gum/releases/download/v0.14.5/gum_0.14.5_Linux_arm64.tar.gz"
TOOL_URLS["gum:darwin-amd64"]="https://github.com/charmbracelet/gum/releases/download/v0.14.5/gum_0.14.5_Darwin_x86_64.tar.gz"
TOOL_URLS["gum:darwin-arm64"]="https://github.com/charmbracelet/gum/releases/download/v0.14.5/gum_0.14.5_Darwin_arm64.tar.gz"
TOOL_URLS["gum:windows-amd64"]="https://github.com/charmbracelet/gum/releases/download/v0.14.5/gum_0.14.5_Windows_x86_64.zip"

# yq v4.44.3
TOOL_URLS["yq:linux-amd64"]="https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64.tar.gz"
TOOL_URLS["yq:linux-arm64"]="https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_arm64.tar.gz"
TOOL_URLS["yq:darwin-amd64"]="https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_darwin_amd64.tar.gz"
TOOL_URLS["yq:darwin-arm64"]="https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_darwin_arm64.tar.gz"
TOOL_URLS["yq:windows-amd64"]="https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_windows_amd64.zip"

# rg (ripgrep) v14.1.1
TOOL_URLS["rg:linux-amd64"]="https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz"
TOOL_URLS["rg:linux-arm64"]="https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-aarch64-unknown-linux-gnu.tar.gz"
TOOL_URLS["rg:darwin-amd64"]="https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-apple-darwin.tar.gz"
TOOL_URLS["rg:darwin-arm64"]="https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-aarch64-apple-darwin.tar.gz"
TOOL_URLS["rg:windows-amd64"]="https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-pc-windows-msvc.zip"

# fd v10.2.0
TOOL_URLS["fd:linux-amd64"]="https://github.com/sharkdp/fd/releases/download/v10.2.0/fd-v10.2.0-x86_64-unknown-linux-musl.tar.gz"
TOOL_URLS["fd:linux-arm64"]="https://github.com/sharkdp/fd/releases/download/v10.2.0/fd-v10.2.0-aarch64-unknown-linux-gnu.tar.gz"
TOOL_URLS["fd:darwin-amd64"]="https://github.com/sharkdp/fd/releases/download/v10.2.0/fd-v10.2.0-x86_64-apple-darwin.tar.gz"
TOOL_URLS["fd:darwin-arm64"]="https://github.com/sharkdp/fd/releases/download/v10.2.0/fd-v10.2.0-aarch64-apple-darwin.tar.gz"
TOOL_URLS["fd:windows-amd64"]="https://github.com/sharkdp/fd/releases/download/v10.2.0/fd-v10.2.0-x86_64-pc-windows-msvc.zip"

# sd v1.0.0
TOOL_URLS["sd:linux-amd64"]="https://github.com/chmln/sd/releases/download/v1.0.0/sd-v1.0.0-x86_64-unknown-linux-musl.tar.gz"
TOOL_URLS["sd:linux-arm64"]="https://github.com/chmln/sd/releases/download/v1.0.0/sd-v1.0.0-aarch64-unknown-linux-gnu.tar.gz"
TOOL_URLS["sd:darwin-amd64"]="https://github.com/chmln/sd/releases/download/v1.0.0/sd-v1.0.0-x86_64-apple-darwin.tar.gz"
TOOL_URLS["sd:darwin-arm64"]="https://github.com/chmln/sd/releases/download/v1.0.0/sd-v1.0.0-aarch64-apple-darwin.tar.gz"
TOOL_URLS["sd:windows-amd64"]="https://github.com/chmln/sd/releases/download/v1.0.0/sd-v1.0.0-x86_64-pc-windows-msvc.zip"

# sg (ast-grep) v0.40.5
TOOL_URLS["sg:linux-amd64"]="https://github.com/ast-grep/ast-grep/releases/download/0.40.5/app-x86_64-unknown-linux-gnu.zip"
TOOL_URLS["sg:linux-arm64"]="https://github.com/ast-grep/ast-grep/releases/download/0.40.5/app-aarch64-unknown-linux-gnu.zip"
TOOL_URLS["sg:darwin-amd64"]="https://github.com/ast-grep/ast-grep/releases/download/0.40.5/app-x86_64-apple-darwin.zip"
TOOL_URLS["sg:darwin-arm64"]="https://github.com/ast-grep/ast-grep/releases/download/0.40.5/app-aarch64-apple-darwin.zip"
TOOL_URLS["sg:windows-amd64"]="https://github.com/ast-grep/ast-grep/releases/download/0.40.5/app-x86_64-pc-windows-msvc.zip"

# Binary names inside archives (when different from tool name)
declare -A ARCHIVE_BINARIES
ARCHIVE_BINARIES["yq:linux-amd64"]="yq_linux_amd64"
ARCHIVE_BINARIES["yq:linux-arm64"]="yq_linux_arm64"
ARCHIVE_BINARIES["yq:darwin-amd64"]="yq_darwin_amd64"
ARCHIVE_BINARIES["yq:darwin-arm64"]="yq_darwin_arm64"
ARCHIVE_BINARIES["yq:windows-amd64"]="yq_windows_amd64.exe"
ARCHIVE_BINARIES["sg:linux-amd64"]="ast-grep"
ARCHIVE_BINARIES["sg:linux-arm64"]="ast-grep"
ARCHIVE_BINARIES["sg:darwin-amd64"]="ast-grep"
ARCHIVE_BINARIES["sg:darwin-arm64"]="ast-grep"
ARCHIVE_BINARIES["sg:windows-amd64"]="ast-grep.exe"

#===============================================================================
# FUNCTIONS
#===============================================================================

download_and_extract_tool() {
    local tool="$1"
    local platform="$2"
    local dest_dir="$3"
    local staging_dir="$4"

    local key="${tool}:${platform}"
    local url="${TOOL_URLS[$key]:-}"

    if [[ -z "$url" ]]; then
        warn "No URL for ${tool} on ${platform}, skipping"
        return 1
    fi

    log "  -> ${tool}"

    local archive_file="${staging_dir}/${tool}-archive"
    local extract_dir="${staging_dir}/${tool}-extract"

    # Download
    if ! curl -fsSL "$url" -o "$archive_file" 2>/dev/null; then
        warn "Failed to download ${tool}"
        return 1
    fi

    # Determine binary name
    local binary_name="$tool"
    local archive_binary="${ARCHIVE_BINARIES[$key]:-$tool}"
    [[ "$platform" == windows-* ]] && binary_name="${tool}.exe"

    local dest_path="${dest_dir}/${binary_name}"

    # Extract
    mkdir -p "$extract_dir"

    if [[ "$url" == *.zip ]]; then
        unzip -q -o "$archive_file" -d "$extract_dir" 2>/dev/null || true
    else
        tar -xzf "$archive_file" -C "$extract_dir" 2>/dev/null || true
    fi

    # Find and copy binary
    local found=0

    # Try exact match first
    local found_binary
    found_binary=$(find "$extract_dir" -type f -name "$archive_binary" 2>/dev/null | head -1)

    if [[ -z "$found_binary" ]]; then
        # Try with wildcard for versioned names like yq_linux_amd64
        found_binary=$(find "$extract_dir" -type f -name "${archive_binary}*" 2>/dev/null | head -1)
    fi

    if [[ -z "$found_binary" ]]; then
        # Try the simple tool name
        found_binary=$(find "$extract_dir" -type f -name "$tool" 2>/dev/null | head -1)
    fi

    if [[ -z "$found_binary" && "$platform" == windows-* ]]; then
        # Windows: try with .exe
        found_binary=$(find "$extract_dir" -type f -name "${tool}.exe" 2>/dev/null | head -1)
    fi

    if [[ -n "$found_binary" ]]; then
        cp "$found_binary" "$dest_path"
        chmod +x "$dest_path" 2>/dev/null || true
        found=1
    fi

    # Cleanup
    rm -rf "$extract_dir" "$archive_file"

    if [[ $found -eq 0 ]]; then
        warn "Binary not found for ${tool}"
        return 1
    fi

    return 0
}

#===============================================================================
# MAIN
#===============================================================================

echo ""
echo "=============================================="
echo "Creating release for ${PLATFORM}"
echo "=============================================="
echo ""

# Validate platform
case "$PLATFORM" in
    linux-amd64|linux-arm64|darwin-amd64|darwin-arm64|windows-amd64)
        ;;
    *)
        error "Unknown platform: $PLATFORM"
        error "Valid platforms: linux-amd64, linux-arm64, darwin-amd64, darwin-arm64, windows-amd64"
        exit 1
        ;;
esac

# Create staging directory
STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

PACKAGE_NAME="${PROJECT_NAME}-${VERSION}-${PLATFORM}"
PACKAGE_DIR="${STAGING_DIR}/${PACKAGE_NAME}"

log "Staging directory: $STAGING_DIR"
log "Package name: $PACKAGE_NAME"

# 1. Create directory structure
log "Creating directory structure..."
mkdir -p "${PACKAGE_DIR}"/{bin,lib,etc,share/completions}

# 2. Copy base files
log "Copying base files..."
cp -r "${PROJECT_ROOT}/lib/"* "${PACKAGE_DIR}/lib/" 2>/dev/null || true
cp -r "${PROJECT_ROOT}/etc/"* "${PACKAGE_DIR}/etc/" 2>/dev/null || true
cp "${PROJECT_ROOT}/VERSION" "${PACKAGE_DIR}/" 2>/dev/null || echo "$VERSION" > "${PACKAGE_DIR}/VERSION"

# 3. Copy dcx binary for target platform
log "Copying dcx binary..."
DCX_BINARY="${PROJECT_ROOT}/bin/dcx-${PLATFORM}"
[[ "$PLATFORM" == windows-* ]] && DCX_BINARY="${DCX_BINARY}.exe"

if [[ -f "$DCX_BINARY" ]]; then
    if [[ "$PLATFORM" == windows-* ]]; then
        cp "$DCX_BINARY" "${PACKAGE_DIR}/bin/dcx.exe"
    else
        cp "$DCX_BINARY" "${PACKAGE_DIR}/bin/dcx"
    fi
    chmod +x "${PACKAGE_DIR}/bin/dcx"* 2>/dev/null || true
    log "  -> dcx binary copied"
else
    error "Binary not found: $DCX_BINARY"
    error "Run 'make build-all' first to compile binaries"
    exit 1
fi

# 4. Download and bundle tools
log "Downloading tools for ${PLATFORM}..."
TOOLS=(gum yq rg fd sd sg)
FAILED_TOOLS=()

for tool in "${TOOLS[@]}"; do
    if ! download_and_extract_tool "$tool" "$PLATFORM" "${PACKAGE_DIR}/bin" "$STAGING_DIR"; then
        FAILED_TOOLS+=("$tool")
    fi
done

if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
    warn "Failed to bundle: ${FAILED_TOOLS[*]}"
fi

# 5. Show package contents
echo ""
log "Package contents (bin/):"
ls -lh "${PACKAGE_DIR}/bin/"

# 6. Create archive
log "Creating archive..."
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR_ABS="$(cd "$OUTPUT_DIR" && pwd)"

if [[ "$PLATFORM" == windows-* ]]; then
    # ZIP for Windows
    ARCHIVE="${OUTPUT_DIR_ABS}/${PACKAGE_NAME}.zip"
    (cd "$STAGING_DIR" && zip -qr "$ARCHIVE" "$PACKAGE_NAME")
else
    # tar.gz for Unix
    ARCHIVE="${OUTPUT_DIR}/${PACKAGE_NAME}.tar.gz"
    tar -czf "$ARCHIVE" -C "$STAGING_DIR" "$PACKAGE_NAME"
fi

# 7. Generate checksum
log "Generating checksum..."
CHECKSUM_FILE="${ARCHIVE}.sha256"
(cd "$(dirname "$ARCHIVE")" && sha256sum "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM_FILE")")

# Summary
echo ""
echo "=============================================="
echo "Release created successfully!"
echo "=============================================="
echo "Archive:  $ARCHIVE"
echo "Size:     $(du -h "$ARCHIVE" | cut -f1)"
echo "SHA256:   $(cat "$CHECKSUM_FILE")"
echo ""
