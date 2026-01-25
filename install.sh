#!/usr/bin/env bash
#===============================================================================
# install.sh - DCX Installer
#===============================================================================
# Professional, resilient installer with:
# - curl | bash compatibility
# - Platform-specific packages with bundled tools
# - Automatic retries and fallbacks
# - Checksum verification
# - Self-update capability
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/datacosmos-br/dc-scripts/main/install.sh | bash
#   curl -fsSL ... | bash -s -- --prefix /custom/path --version 0.0.1
#
#   ./install.sh [--prefix PATH] [--version X.Y.Z] [--force] [--no-tools]
#===============================================================================

# Strict mode (but handle unbound vars gracefully for curl|bash)
set -eo pipefail

#===============================================================================
# CONSTANTS
#===============================================================================
readonly PROJECT_NAME="${DC_PROJECT_NAME:-DCX}"
readonly PROJECT_REPO="${DC_GITHUB_REPO:-datacosmos-br/dc-scripts}"
readonly GITHUB_RAW="https://raw.githubusercontent.com/${PROJECT_REPO}/main"
readonly GITHUB_API="https://api.github.com/repos/${PROJECT_REPO}"
readonly GITHUB_RELEASES="https://github.com/${PROJECT_REPO}/releases/download"
readonly DEFAULT_PREFIX="${HOME}/.local"
readonly INSTALLER_VERSION="1.0.0"

#===============================================================================
# COLORS AND OUTPUT
#===============================================================================
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

_header() {
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}${PROJECT_NAME} Installer${NC}                                         ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

_log()     { echo -e "${GREEN}[✓]${NC} $*"; }
_info()    { echo -e "${BLUE}[i]${NC} $*"; }
_warn()    { echo -e "${YELLOW}[!]${NC} $*" >&2; }
_error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
_fatal()   { _error "$*"; exit 1; }
_step()    { echo -e "${CYAN}[→]${NC} $*"; }
_success() { echo -e "${GREEN}${BOLD}[✓]${NC} ${GREEN}$*${NC}"; }

_spinner() {
    local pid=$1 msg="${2:-Working...}"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}[%s]${NC} %s" "${spin:i++%${#spin}:1}" "$msg"
        sleep 0.1
    done
    printf "\r"
}

#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

_detect_platform() {
    local os arch
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)

    case "$os" in
        linux)   os="linux" ;;
        darwin)  os="darwin" ;;
        mingw*|msys*|cygwin*) os="windows" ;;
        *)       _fatal "Unsupported OS: $os" ;;
    esac

    case "$arch" in
        x86_64|amd64)     arch="amd64" ;;
        aarch64|arm64)    arch="arm64" ;;
        i386|i686)        arch="386" ;;
        *)                _fatal "Unsupported architecture: $arch" ;;
    esac

    echo "${os}-${arch}"
}

_command_exists() {
    command -v "$1" &>/dev/null
}

_download() {
    local url="$1" output="$2" retries="${3:-3}"
    local attempt=1

    while [[ $attempt -le $retries ]]; do
        if _command_exists curl; then
            if curl -fsSL --connect-timeout 10 --max-time 120 "$url" -o "$output" 2>/dev/null; then
                return 0
            fi
        elif _command_exists wget; then
            if wget -q --timeout=10 "$url" -O "$output" 2>/dev/null; then
                return 0
            fi
        else
            _fatal "Neither curl nor wget found. Please install one."
        fi

        if [[ $attempt -lt $retries ]]; then
            _warn "Download failed, retrying ($attempt/$retries)..."
            sleep 2
        fi
        ((attempt++))
    done

    return 1
}

_download_with_progress() {
    local url="$1" output="$2" desc="${3:-Downloading...}"

    _step "$desc"

    if _command_exists curl; then
        if [[ -t 1 ]]; then
            curl -fSL --connect-timeout 10 --max-time 300 --progress-bar "$url" -o "$output" 2>&1 | \
                grep --line-buffered -o '[0-9]*\.[0-9]%\|[0-9]*%' | tail -1 || true
        else
            curl -fsSL --connect-timeout 10 --max-time 300 "$url" -o "$output"
        fi
    elif _command_exists wget; then
        wget -q --show-progress --timeout=10 "$url" -O "$output" 2>&1 || \
            wget -q --timeout=10 "$url" -O "$output"
    fi
}

_get_latest_version() {
    local api_url="${GITHUB_API}/releases/latest"
    local response version

    if _command_exists curl; then
        response=$(curl -fsSL --connect-timeout 5 "$api_url" 2>/dev/null) || return 1
    elif _command_exists wget; then
        response=$(wget -qO- --timeout=5 "$api_url" 2>/dev/null) || return 1
    fi

    # Extract version from tag_name
    version=$(echo "$response" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name"[^"]*"\([^"]*\)".*/\1/' | sed 's/^v//')

    [[ -n "$version" ]] && echo "$version" && return 0
    return 1
}

_verify_checksum() {
    local file="$1" expected="$2"
    local actual

    if _command_exists sha256sum; then
        actual=$(sha256sum "$file" | cut -d' ' -f1)
    elif _command_exists shasum; then
        actual=$(shasum -a 256 "$file" | cut -d' ' -f1)
    else
        _warn "No checksum tool found, skipping verification"
        return 0
    fi

    [[ "$actual" == "$expected" ]]
}

_cleanup() {
    if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR" 2>/dev/null || true
    fi
}

_check_existing_install() {
    local install_dir="$1"

    if [[ -f "$install_dir/VERSION" ]]; then
        local installed_version
        installed_version=$(cat "$install_dir/VERSION" 2>/dev/null || echo "unknown")
        echo "$installed_version"
        return 0
    fi
    return 1
}

#===============================================================================
# INSTALLATION FUNCTIONS
#===============================================================================

_install_remote() {
    local prefix="$1"
    local version="${2:-}"
    local force="${3:-false}"
    local platform

    platform=$(_detect_platform)

    local install_dir="${prefix}/share/${PROJECT_NAME}"
    local bin_dir="${prefix}/bin"

    # Check existing installation
    local existing_version
    if existing_version=$(_check_existing_install "$install_dir"); then
        if [[ "$force" != "true" ]]; then
            _info "Found existing installation: v${existing_version}"
            if [[ -n "$version" && "$existing_version" == "$version" ]]; then
                _log "Version v${version} is already installed. Use --force to reinstall."
                return 0
            fi
        fi
    fi

    # Get version
    if [[ -z "$version" ]]; then
        _step "Fetching latest version..."
        version=$(_get_latest_version) || _fatal "Could not determine latest version. Check your internet connection."
    fi

    _info "Version: ${BOLD}v${version}${NC}"
    _info "Platform: ${BOLD}${platform}${NC}"
    _info "Prefix: ${BOLD}${prefix}${NC}"
    echo ""

    # Create temp directory
    TMP_DIR=$(mktemp -d)
    trap _cleanup EXIT INT TERM

    # Determine tarball name
    local tarball_name ext="tar.gz"
    [[ "$platform" == windows-* ]] && ext="zip"

    # Try platform-specific first, then fallback to universal
    local download_success=false
    local tools_bundled=false

    for tarball_pattern in "${PROJECT_NAME}-${version}-${platform}.${ext}" "${PROJECT_NAME}-${version}.tar.gz"; do
        tarball_name="$tarball_pattern"
        local download_url="${GITHUB_RELEASES}/v${version}/${tarball_name}"
        local tarball_path="${TMP_DIR}/${tarball_name}"

        _step "Downloading ${tarball_name}..."

        if _download "$download_url" "$tarball_path" 3; then
            download_success=true

            # Check if this is the platform-specific tarball (has bundled tools)
            if [[ "$tarball_name" == *"-${platform}."* ]]; then
                tools_bundled=true
                _log "Downloaded platform-specific package (tools included)"
            else
                _log "Downloaded universal package"
            fi
            break
        else
            _warn "Not found: ${tarball_name}"
        fi
    done

    if [[ "$download_success" != "true" ]]; then
        _fatal "Failed to download ${PROJECT_NAME}. Check your internet connection or try a specific version."
    fi

    # Optional: verify checksum
    local checksum_url="${GITHUB_RELEASES}/v${version}/${tarball_name}.sha256"
    local checksum_file="${TMP_DIR}/${tarball_name}.sha256"

    if _download "$checksum_url" "$checksum_file" 1 2>/dev/null; then
        local expected_checksum
        expected_checksum=$(cat "$checksum_file" | awk '{print $1}')

        _step "Verifying checksum..."
        if _verify_checksum "$tarball_path" "$expected_checksum"; then
            _log "Checksum verified"
        else
            _fatal "Checksum verification failed! The download may be corrupted."
        fi
    fi

    # Extract
    _step "Extracting..."
    if [[ "$tarball_name" == *.zip ]]; then
        if _command_exists unzip; then
            unzip -q "$tarball_path" -d "$TMP_DIR"
        else
            _fatal "unzip not found. Please install it."
        fi
    else
        tar -xzf "$tarball_path" -C "$TMP_DIR"
    fi
    _log "Extracted"

    # Find extracted directory
    local extracted_dir
    extracted_dir=$(find "$TMP_DIR" -maxdepth 1 -type d -name "${PROJECT_NAME}-*" 2>/dev/null | head -1)
    [[ -z "$extracted_dir" ]] && extracted_dir="$TMP_DIR"

    # Install files
    _step "Installing to ${install_dir}..."
    mkdir -p "$install_dir"/{bin,lib,etc,plugins,share/completions}
    mkdir -p "$bin_dir"

    # Copy files (ignore errors for optional directories)
    cp -r "$extracted_dir/lib/"* "$install_dir/lib/" 2>/dev/null || true
    cp -r "$extracted_dir/etc/"* "$install_dir/etc/" 2>/dev/null || true
    cp -r "$extracted_dir/bin/"* "$install_dir/bin/" 2>/dev/null || true
    cp "$extracted_dir/VERSION" "$install_dir/" 2>/dev/null || echo "$version" > "$install_dir/VERSION"

    # Setup dcx command in user's PATH
    if [[ -f "$install_dir/bin/dcx" ]]; then
        cp "$install_dir/bin/dcx" "$bin_dir/dcx"
        chmod +x "$bin_dir/dcx"
        _log "Installed dcx to ${bin_dir}/dcx"
    elif [[ -f "$install_dir/bin/dcx.exe" ]]; then
        cp "$install_dir/bin/dcx.exe" "$bin_dir/dcx.exe"
        _log "Installed dcx.exe to ${bin_dir}/dcx.exe"
    fi

    # Handle tools
    if [[ "$tools_bundled" == "true" ]]; then
        _log "Tools bundled in package - no additional downloads needed"
    else
        _step "Installing tools..."
        if [[ -x "$bin_dir/dcx" ]]; then
            if "$bin_dir/dcx" tools install --all 2>/dev/null; then
                _log "Tools installed"
            else
                _warn "Some tools could not be installed. Run 'dcx tools install --all' later."
            fi
        fi
    fi

    return 0
}

_install_local() {
    local script_dir="$1"
    local prefix="$2"

    if [[ -f "$script_dir/lib/shared.sh" ]]; then
        # shellcheck source=lib/shared.sh
        source "$script_dir/lib/shared.sh"
        dc_install_local "$script_dir" "$prefix"
    else
        _fatal "Local installation requires lib/shared.sh. Run from repository root."
    fi
}

_print_success() {
    local prefix="$1"
    local version="$2"

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}${GREEN}Installation Complete!${NC}                                     ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Version:${NC}  v${version}"
    echo -e "  ${BOLD}Location:${NC} ${prefix}/share/${PROJECT_NAME}"
    echo -e "  ${BOLD}Binary:${NC}   ${prefix}/bin/dcx"
    echo ""
    echo -e "  ${BOLD}Quick Start:${NC}"
    echo -e "    ${CYAN}dcx version${NC}     Show version"
    echo -e "    ${CYAN}dcx help${NC}        Show help"
    echo -e "    ${CYAN}dcx tools list${NC}  List available tools"
    echo -e "    ${CYAN}dcx update${NC}      Check for updates"
    echo ""

    # Check PATH
    if [[ ":$PATH:" != *":${prefix}/bin:"* ]]; then
        echo -e "  ${YELLOW}Note:${NC} Add to your shell profile:"
        echo -e "    ${DIM}export PATH=\"${prefix}/bin:\$PATH\"${NC}"
        echo ""
    fi
}

#===============================================================================
# ARGUMENT PARSING
#===============================================================================

_parse_args() {
    PREFIX="$DEFAULT_PREFIX"
    VERSION=""
    FORCE=false
    LOCAL_INSTALL=false
    HELP=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --prefix|-p)
                PREFIX="${2:-$DEFAULT_PREFIX}"
                shift 2 || shift
                ;;
            --version|-v)
                VERSION="${2:-}"
                shift 2 || shift
                ;;
            --force|-f)
                FORCE=true
                shift
                ;;
            --local|-l)
                LOCAL_INSTALL=true
                shift
                ;;
            --help|-h)
                HELP=true
                shift
                ;;
            --update|-u)
                # Self-update: download and run latest installer
                _info "Updating installer..."
                exec bash <(curl -fsSL "${GITHUB_RAW}/install.sh") "$@"
                ;;
            *)
                _warn "Unknown option: $1"
                shift
                ;;
        esac
    done
}

_show_help() {
    cat << EOF
${BOLD}${PROJECT_NAME} Installer v${INSTALLER_VERSION}${NC}

${BOLD}USAGE:${NC}
    ${CYAN}curl -fsSL ... | bash${NC}
    ${CYAN}curl -fsSL ... | bash -s -- [OPTIONS]${NC}
    ${CYAN}./install.sh [OPTIONS]${NC}

${BOLD}OPTIONS:${NC}
    -p, --prefix PATH     Installation prefix (default: ~/.local)
    -v, --version X.Y.Z   Install specific version (default: latest)
    -f, --force           Force reinstall even if already installed
    -l, --local           Install from local repository clone
    -u, --update          Self-update installer and run
    -h, --help            Show this help message

${BOLD}EXAMPLES:${NC}
    # Install latest version
    ${DIM}curl -fsSL https://raw.githubusercontent.com/${PROJECT_REPO}/main/install.sh | bash${NC}

    # Install specific version
    ${DIM}curl -fsSL ... | bash -s -- --version 0.0.1${NC}

    # Install to custom location
    ${DIM}./install.sh --prefix /opt/dcx${NC}

    # Force reinstall
    ${DIM}./install.sh --force${NC}

${BOLD}ENVIRONMENT:${NC}
    DC_PROJECT_NAME    Override project name (default: DCX)
    DC_GITHUB_REPO     Override repository (default: datacosmos-br/dc-scripts)
    NO_COLOR           Disable colored output

EOF
}

#===============================================================================
# MAIN
#===============================================================================

main() {
    _parse_args "$@"

    if [[ "$HELP" == "true" ]]; then
        _show_help
        exit 0
    fi

    _header

    # Detect installation mode
    # Safe handling of BASH_SOURCE for curl|bash compatibility
    local script_dir=""
    if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || script_dir=""
    fi

    if [[ "$LOCAL_INSTALL" == "true" || (-n "$script_dir" && -f "$script_dir/lib/shared.sh") ]]; then
        _info "Mode: Local installation"
        _install_local "$script_dir" "$PREFIX"
    else
        _info "Mode: Remote installation"
        _install_remote "$PREFIX" "$VERSION" "$FORCE"
    fi

    # Get installed version for success message
    local installed_version
    installed_version=$(cat "${PREFIX}/share/${PROJECT_NAME}/VERSION" 2>/dev/null || echo "$VERSION")

    _print_success "$PREFIX" "$installed_version"
}

# Run main with all arguments
main "$@"
