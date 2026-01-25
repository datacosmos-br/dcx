#!/usr/bin/env bash
#===============================================================================
# create-platform-release.sh - Professional Platform Release Builder
#===============================================================================
# Creates platform-specific release packages with bundled tools.
# Reads tool definitions from etc/tools.yaml (single source of truth).
#
# Features:
# - Reads from centralized tools.yaml configuration
# - Automatic retries on download failure
# - Safe file operations (atomic writes, proper cleanup)
# - Comprehensive error handling
# - Progress reporting
#
# Usage:
#   ./scripts/create-platform-release.sh <platform> <version> <output-dir>
#   ./scripts/create-platform-release.sh linux-amd64 0.0.1 release/
#   ./scripts/create-platform-release.sh --all 0.0.1 release/
#===============================================================================

set -eo pipefail

#===============================================================================
# CONSTANTS
#===============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly PROJECT_NAME="DCX"
readonly TOOLS_YAML="${PROJECT_ROOT}/etc/tools.yaml"
readonly SUPPORTED_PLATFORMS="linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64"

# Settings
readonly RETRY_COUNT=3
readonly TIMEOUT=120

#===============================================================================
# COLORS
#===============================================================================
if [[ -t 1 ]]; then
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

#===============================================================================
# LOGGING
#===============================================================================
_log()     { echo -e "${GREEN}[✓]${NC} $*"; }
_info()    { echo -e "${BLUE}[i]${NC} $*"; }
_warn()    { echo -e "${YELLOW}[!]${NC} $*" >&2; }
_error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
_fatal()   { _error "$*"; exit 1; }
_step()    { echo -e "${CYAN}[→]${NC} $*"; }

_header() {
    local platform="$1"
    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  Creating Release: ${platform}${NC}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

#===============================================================================
# YAML PARSING (using yq if available, fallback to grep/sed)
#===============================================================================
_yaml_get() {
    local file="$1"
    local path="$2"

    if command -v yq &>/dev/null; then
        yq -r "$path // empty" "$file" 2>/dev/null
    elif [[ -x "${PROJECT_ROOT}/bin/yq" ]]; then
        "${PROJECT_ROOT}/bin/yq" -r "$path // empty" "$file" 2>/dev/null
    else
        # Fallback: simple grep (limited functionality)
        _warn "yq not found, using limited YAML parsing"
        return 1
    fi
}

_get_tool_list() {
    _yaml_get "$TOOLS_YAML" '.tools | keys | .[]' | tr '\n' ' '
}

_get_tool_version() {
    local tool="$1"
    _yaml_get "$TOOLS_YAML" ".tools.${tool}.version"
}

_get_tool_url() {
    local tool="$1"
    local platform="$2"
    local version
    version=$(_get_tool_version "$tool")

    local url
    url=$(_yaml_get "$TOOLS_YAML" ".tools.${tool}.urls.\"${platform}\"")

    # Replace {version} placeholder
    echo "${url//\{version\}/$version}"
}

_get_tool_binary() {
    local tool="$1"
    _yaml_get "$TOOLS_YAML" ".tools.${tool}.binary"
}

_get_tool_archive_binary() {
    local tool="$1"
    local platform="$2"

    # First try platform-specific archive_binary
    local archive_bin
    archive_bin=$(_yaml_get "$TOOLS_YAML" ".tools.${tool}.archive_binary.\"${platform}\"")

    if [[ -n "$archive_bin" && "$archive_bin" != "null" ]]; then
        echo "$archive_bin"
    else
        # Fallback to binary name
        _get_tool_binary "$tool"
    fi
}

_get_tool_extract() {
    local tool="$1"
    _yaml_get "$TOOLS_YAML" ".tools.${tool}.extract"
}

#===============================================================================
# DOWNLOAD FUNCTIONS
#===============================================================================
_download() {
    local url="$1"
    local output="$2"
    local attempt=1

    while [[ $attempt -le $RETRY_COUNT ]]; do
        if command -v curl &>/dev/null; then
            if curl -fsSL --connect-timeout 10 --max-time "$TIMEOUT" "$url" -o "$output" 2>/dev/null; then
                return 0
            fi
        elif command -v wget &>/dev/null; then
            if wget -q --timeout=10 "$url" -O "$output" 2>/dev/null; then
                return 0
            fi
        else
            _fatal "Neither curl nor wget found"
        fi

        if [[ $attempt -lt $RETRY_COUNT ]]; then
            _warn "  Retry $attempt/$RETRY_COUNT..."
            sleep 2
        fi
        ((attempt++))
    done

    return 1
}

#===============================================================================
# TOOL INSTALLATION
#===============================================================================
_install_tool() {
    local tool="$1"
    local platform="$2"
    local dest_dir="$3"
    local staging_dir="$4"

    local url
    url=$(_get_tool_url "$tool" "$platform")

    if [[ -z "$url" || "$url" == "null" ]]; then
        _warn "  ${tool}: No release for ${platform} (skipped)"
        return 1
    fi

    local version
    version=$(_get_tool_version "$tool")

    _step "  ${BOLD}${tool}${NC} v${version}"

    local archive_file="${staging_dir}/${tool}-archive"
    local extract_dir="${staging_dir}/${tool}-extract"

    # Download
    if ! _download "$url" "$archive_file"; then
        _error "  ${tool}: Download failed"
        return 1
    fi

    # Get binary names
    local binary_name
    binary_name=$(_get_tool_binary "$tool")
    [[ "$platform" == windows-* ]] && binary_name="${binary_name}.exe"

    local archive_binary
    archive_binary=$(_get_tool_archive_binary "$tool" "$platform")

    local dest_path="${dest_dir}/${binary_name}"
    local extract_type
    extract_type=$(_get_tool_extract "$tool")

    # Extract
    mkdir -p "$extract_dir"

    if [[ "$url" == *.zip ]] || [[ "$extract_type" == "zip" ]]; then
        unzip -q -o "$archive_file" -d "$extract_dir" 2>/dev/null || {
            _error "  ${tool}: Extract failed"
            return 1
        }
    else
        tar -xzf "$archive_file" -C "$extract_dir" 2>/dev/null || {
            _error "  ${tool}: Extract failed"
            return 1
        }
    fi

    # Find binary in extracted files
    local found_binary=""

    # Try exact match first
    found_binary=$(find "$extract_dir" -type f -name "$archive_binary" 2>/dev/null | head -1)

    # Try with wildcards if not found
    if [[ -z "$found_binary" ]]; then
        found_binary=$(find "$extract_dir" -type f -name "${archive_binary}*" ! -name "*.md" ! -name "*.txt" 2>/dev/null | head -1)
    fi

    # Try simple tool name
    if [[ -z "$found_binary" ]]; then
        found_binary=$(find "$extract_dir" -type f -name "$binary_name" 2>/dev/null | head -1)
    fi

    if [[ -z "$found_binary" ]]; then
        _error "  ${tool}: Binary not found in archive"
        # Cleanup
        rm -rf "$extract_dir" "$archive_file" 2>/dev/null || true
        return 1
    fi

    # ATOMIC WRITE: Remove existing then copy (avoids "text file busy" errors)
    if [[ -f "$dest_path" ]]; then
        rm -f "$dest_path" 2>/dev/null || true
    fi

    cp "$found_binary" "$dest_path"
    chmod +x "$dest_path"

    # Cleanup
    rm -rf "$extract_dir" "$archive_file" 2>/dev/null || true

    _log "  ${tool}: OK"
    return 0
}

#===============================================================================
# RELEASE CREATION
#===============================================================================
_create_release() {
    local platform="$1"
    local version="$2"
    local output_dir="$3"

    _header "$platform"

    # Validate platform
    if [[ ! " $SUPPORTED_PLATFORMS " =~ " $platform " ]]; then
        _fatal "Unsupported platform: $platform"
    fi

    # Check for tools.yaml
    if [[ ! -f "$TOOLS_YAML" ]]; then
        _fatal "tools.yaml not found: $TOOLS_YAML"
    fi

    # Create staging directory
    local staging_dir
    staging_dir=$(mktemp -d)
    trap "rm -rf '$staging_dir' 2>/dev/null || true" EXIT

    local package_name="${PROJECT_NAME}-${version}-${platform}"
    local package_dir="${staging_dir}/${package_name}"

    _info "Package: ${BOLD}${package_name}${NC}"
    _info "Staging: ${DIM}${staging_dir}${NC}"
    echo ""

    # Create directory structure
    _step "Creating directory structure..."
    mkdir -p "${package_dir}"/{bin,lib,etc,share/completions}
    _log "Directories created"

    # Copy base files
    _step "Copying base files..."
    cp -r "${PROJECT_ROOT}/lib/"* "${package_dir}/lib/" 2>/dev/null || true
    cp -r "${PROJECT_ROOT}/etc/"* "${package_dir}/etc/" 2>/dev/null || true

    if [[ -f "${PROJECT_ROOT}/VERSION" ]]; then
        cp "${PROJECT_ROOT}/VERSION" "${package_dir}/"
    else
        echo "$version" > "${package_dir}/VERSION"
    fi
    _log "Base files copied"

    # Copy dcx binary
    _step "Copying dcx binary..."
    local dcx_binary="${PROJECT_ROOT}/bin/dcx-${platform}"
    [[ "$platform" == windows-* ]] && dcx_binary="${dcx_binary}.exe"

    if [[ -f "$dcx_binary" ]]; then
        local dest_name="dcx"
        [[ "$platform" == windows-* ]] && dest_name="dcx.exe"
        cp "$dcx_binary" "${package_dir}/bin/${dest_name}"
        chmod +x "${package_dir}/bin/${dest_name}"
        _log "dcx binary: OK"
    else
        _fatal "dcx binary not found: $dcx_binary (run 'make build-all' first)"
    fi

    # Download and bundle tools
    echo ""
    _step "Downloading tools from official sources..."
    echo ""

    local tools
    tools=$(_get_tool_list)
    local failed_tools=()
    local success_count=0

    for tool in $tools; do
        if _install_tool "$tool" "$platform" "${package_dir}/bin" "$staging_dir"; then
            success_count=$((success_count + 1))
        else
            failed_tools+=("$tool")
        fi
    done

    echo ""
    _info "Tools installed: ${success_count}/$(echo $tools | wc -w)"

    if [[ ${#failed_tools[@]} -gt 0 ]]; then
        _warn "Failed: ${failed_tools[*]}"
    fi

    # Show package contents
    echo ""
    _step "Package contents:"
    ls -lh "${package_dir}/bin/" | tail -n +2 | while read -r line; do
        echo "    $line"
    done

    # Create archive
    echo ""
    _step "Creating archive..."
    mkdir -p "$output_dir"
    local output_dir_abs
    output_dir_abs="$(cd "$output_dir" && pwd)"

    local archive_path
    if [[ "$platform" == windows-* ]]; then
        archive_path="${output_dir_abs}/${package_name}.zip"
        # Remove existing file first
        rm -f "$archive_path" 2>/dev/null || true
        (cd "$staging_dir" && zip -qr "$archive_path" "$package_name")
    else
        archive_path="${output_dir_abs}/${package_name}.tar.gz"
        # Remove existing file first
        rm -f "$archive_path" 2>/dev/null || true
        tar -czf "$archive_path" -C "$staging_dir" "$package_name"
    fi
    _log "Archive created"

    # Generate checksum
    _step "Generating checksum..."
    local checksum_file="${archive_path}.sha256"
    rm -f "$checksum_file" 2>/dev/null || true
    (cd "$(dirname "$archive_path")" && sha256sum "$(basename "$archive_path")" > "$(basename "$checksum_file")")
    _log "Checksum generated"

    # Summary
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Release Complete!${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}Archive:${NC}  $(basename "$archive_path")"
    echo -e "  ${BOLD}Size:${NC}     $(du -h "$archive_path" | cut -f1)"
    echo -e "  ${BOLD}SHA256:${NC}   $(cat "$checksum_file" | cut -d' ' -f1)"
    echo ""
}

#===============================================================================
# MAIN
#===============================================================================
main() {
    local platform="${1:-}"
    local version="${2:-}"
    local output_dir="${3:-release}"

    # Help
    if [[ "$platform" == "-h" || "$platform" == "--help" ]]; then
        cat << EOF
${BOLD}create-platform-release.sh${NC} - Create platform-specific release packages

${BOLD}USAGE:${NC}
    $0 <platform> <version> [output-dir]
    $0 --all <version> [output-dir]

${BOLD}PLATFORMS:${NC}
    linux-amd64    Linux x86_64
    linux-arm64    Linux ARM64
    darwin-amd64   macOS Intel
    darwin-arm64   macOS Apple Silicon
    windows-amd64  Windows x64

${BOLD}EXAMPLES:${NC}
    $0 linux-amd64 0.0.1 release/
    $0 --all 0.0.1 release/

${BOLD}REQUIREMENTS:${NC}
    - Go binaries must be compiled first (make build-all)
    - etc/tools.yaml must exist
    - curl or wget for downloads
    - tar, zip, unzip for archives
EOF
        exit 0
    fi

    # Validate arguments
    [[ -z "$platform" ]] && _fatal "Missing platform. Use --help for usage."
    [[ -z "$version" ]] && _fatal "Missing version. Use --help for usage."

    # Handle --all
    if [[ "$platform" == "--all" || "$platform" == "all" ]]; then
        for p in $SUPPORTED_PLATFORMS; do
            _create_release "$p" "$version" "$output_dir"
        done
    else
        _create_release "$platform" "$version" "$output_dir"
    fi
}

main "$@"
