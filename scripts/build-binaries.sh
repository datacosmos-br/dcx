#!/usr/bin/env bash
#===============================================================================
# scripts/build-binaries.sh - Download/Build DCX bundled binaries
#===============================================================================
# Downloads pre-built binaries from official releases
# Uses etc/project.yaml for version configuration
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load constants
source "$PROJECT_DIR/lib/constants.sh"

#===============================================================================
# CONFIGURATION
#===============================================================================

BIN_DIR="$PROJECT_DIR/bin"

# Tool versions (from constants.sh or defaults)
GUM_VERSION="${DCX_TOOL_GUM_VERSION:-0.14.5}"
YQ_VERSION="${DCX_TOOL_YQ_VERSION:-4.44.3}"
RG_VERSION="${DCX_TOOL_RG_VERSION:-14.1.1}"
FD_VERSION="${DCX_TOOL_FD_VERSION:-10.2.0}"
SD_VERSION="${DCX_TOOL_SD_VERSION:-1.0.0}"

#===============================================================================
# HELPER FUNCTIONS
#===============================================================================

log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
error() { echo "[ERROR] $*" >&2; exit 1; }

download() {
    local url="$1" output="$2"
    log "Downloading: $url"
    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget &>/dev/null; then
        wget -q "$url" -O "$output"
    else
        error "Neither curl nor wget found"
    fi
}

#===============================================================================
# GUM (charmbracelet/gum)
#===============================================================================

download_gum() {
    local platform="$1"
    local version="$GUM_VERSION"

    local os arch
    os="${platform%-*}"
    arch="${platform#*-}"

    # Map arch names
    case "$arch" in
        amd64) arch="x86_64" ;;
        arm64) arch="arm64" ;;
    esac

    # Map os names for gum
    local gum_os="$os"
    [[ "$os" == "darwin" ]] && gum_os="Darwin"
    [[ "$os" == "linux" ]] && gum_os="Linux"

    local url="https://github.com/charmbracelet/gum/releases/download/v${version}/gum_${version}_${gum_os}_${arch}.tar.gz"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" RETURN

    download "$url" "$tmp_dir/gum.tar.gz"
    tar -xzf "$tmp_dir/gum.tar.gz" -C "$tmp_dir"

    # Find and copy binary
    local binary
    binary=$(find "$tmp_dir" -name "gum" -type f | head -1)
    if [[ -n "$binary" ]]; then
        cp "$binary" "$BIN_DIR/gum-${platform}"
        chmod +x "$BIN_DIR/gum-${platform}"
        log "Installed: gum-${platform}"
    else
        warn "Could not find gum binary in archive"
        return 1
    fi
}

#===============================================================================
# YQ (mikefarah/yq)
#===============================================================================

download_yq() {
    local platform="$1"
    local version="$YQ_VERSION"

    local os arch
    os="${platform%-*}"
    arch="${platform#*-}"

    local url="https://github.com/mikefarah/yq/releases/download/v${version}/yq_${os}_${arch}"

    download "$url" "$BIN_DIR/yq-${platform}"
    chmod +x "$BIN_DIR/yq-${platform}"
    log "Installed: yq-${platform}"
}

#===============================================================================
# RIPGREP (BurntSushi/ripgrep) - Optional
#===============================================================================

download_rg() {
    local platform="$1"
    local version="$RG_VERSION"

    local os arch
    os="${platform%-*}"
    arch="${platform#*-}"

    # Map platform for ripgrep naming
    local rg_target
    case "$platform" in
        linux-amd64) rg_target="x86_64-unknown-linux-musl" ;;
        linux-arm64) rg_target="aarch64-unknown-linux-gnu" ;;
        darwin-amd64) rg_target="x86_64-apple-darwin" ;;
        darwin-arm64) rg_target="aarch64-apple-darwin" ;;
        *) warn "Unsupported platform for rg: $platform"; return 1 ;;
    esac

    local url="https://github.com/BurntSushi/ripgrep/releases/download/${version}/ripgrep-${version}-${rg_target}.tar.gz"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" RETURN

    download "$url" "$tmp_dir/rg.tar.gz"
    tar -xzf "$tmp_dir/rg.tar.gz" -C "$tmp_dir"

    local binary
    binary=$(find "$tmp_dir" -name "rg" -type f | head -1)
    if [[ -n "$binary" ]]; then
        cp "$binary" "$BIN_DIR/rg-${platform}"
        chmod +x "$BIN_DIR/rg-${platform}"
        log "Installed: rg-${platform}"
    fi
}

#===============================================================================
# FD (sharkdp/fd) - Optional
#===============================================================================

download_fd() {
    local platform="$1"
    local version="$FD_VERSION"

    local os arch
    os="${platform%-*}"
    arch="${platform#*-}"

    local fd_target
    case "$platform" in
        linux-amd64) fd_target="x86_64-unknown-linux-musl" ;;
        linux-arm64) fd_target="aarch64-unknown-linux-gnu" ;;
        darwin-amd64) fd_target="x86_64-apple-darwin" ;;
        darwin-arm64) fd_target="aarch64-apple-darwin" ;;
        *) warn "Unsupported platform for fd: $platform"; return 1 ;;
    esac

    local url="https://github.com/sharkdp/fd/releases/download/v${version}/fd-v${version}-${fd_target}.tar.gz"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" RETURN

    download "$url" "$tmp_dir/fd.tar.gz"
    tar -xzf "$tmp_dir/fd.tar.gz" -C "$tmp_dir"

    local binary
    binary=$(find "$tmp_dir" -name "fd" -type f | head -1)
    if [[ -n "$binary" ]]; then
        cp "$binary" "$BIN_DIR/fd-${platform}"
        chmod +x "$BIN_DIR/fd-${platform}"
        log "Installed: fd-${platform}"
    fi
}

#===============================================================================
# SYMLINKS
#===============================================================================

create_symlinks() {
    local platform="$1"

    log "Creating symlinks for $platform..."

    for tool in gum yq rg fd sd; do
        if [[ -f "$BIN_DIR/${tool}-${platform}" ]]; then
            ln -sf "${tool}-${platform}" "$BIN_DIR/${tool}"
            log "  ${tool} -> ${tool}-${platform}"
        fi
    done
}

#===============================================================================
# MAIN
#===============================================================================

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

Commands:
  all           Download all binaries for current platform (default)
  required      Download only required binaries (gum, yq)
  list          List configured tool versions
  check         Check which binaries are present

Options:
  --platform P  Target platform (default: current)
  --all-platforms  Download for all supported platforms
  --help        Show this help

Examples:
  $0                    # Download all for current platform
  $0 required           # Download only gum and yq
  $0 --all-platforms    # Download for all platforms
EOF
}

main() {
    local cmd="all"
    local platform="$DCX_PLATFORM"
    local all_platforms=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --platform)
                platform="$2"
                shift 2
                ;;
            --all-platforms)
                all_platforms=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            list|check|all|required)
                cmd="$1"
                shift
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done

    mkdir -p "$BIN_DIR"

    case "$cmd" in
        list)
            echo "Tool Versions:"
            echo "  gum: $GUM_VERSION"
            echo "  yq:  $YQ_VERSION"
            echo "  rg:  $RG_VERSION"
            echo "  fd:  $FD_VERSION"
            echo "  sd:  $SD_VERSION"
            ;;

        check)
            echo "Checking binaries for $platform..."
            for tool in gum yq rg fd sd; do
                if [[ -x "$BIN_DIR/${tool}-${platform}" ]] || [[ -x "$BIN_DIR/${tool}" ]]; then
                    echo "  [OK] $tool"
                else
                    echo "  [--] $tool (not found)"
                fi
            done
            ;;

        required)
            if $all_platforms; then
                for p in linux-amd64 linux-arm64 darwin-amd64 darwin-arm64; do
                    log "=== Platform: $p ==="
                    download_gum "$p" || true
                    download_yq "$p" || true
                done
            else
                download_gum "$platform"
                download_yq "$platform"
                create_symlinks "$platform"
            fi
            ;;

        all)
            if $all_platforms; then
                for p in linux-amd64 linux-arm64 darwin-amd64 darwin-arm64; do
                    log "=== Platform: $p ==="
                    download_gum "$p" || true
                    download_yq "$p" || true
                    download_rg "$p" || true
                    download_fd "$p" || true
                done
            else
                download_gum "$platform"
                download_yq "$platform"
                download_rg "$platform" || warn "rg download failed (optional)"
                download_fd "$platform" || warn "fd download failed (optional)"
                create_symlinks "$platform"
            fi
            ;;
    esac

    log "Done!"
}

main "$@"
