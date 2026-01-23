#!/usr/bin/env bash
#===============================================================================
# dc-scripts Installer
#===============================================================================
# One-liner installation:
#   curl -fsSL https://raw.githubusercontent.com/datacosmos-br/dc-scripts/main/install.sh | bash
#
# Options:
#   --upgrade     Upgrade existing installation
#   --uninstall   Remove dc-scripts
#   --prefix DIR  Install to custom prefix (default: /usr/local)
#   --help        Show this help
#===============================================================================

set -euo pipefail

# Configuration
REPO="datacosmos-br/dc-scripts"
NAME="dc-scripts"
DEFAULT_PREFIX="/usr/local"
CONFIG_DIR="${HOME}/.config/${NAME}"

# Colors (disable if not terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

#===============================================================================
# Functions
#===============================================================================

log_info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat << EOF
${NAME} Installer

Usage: $0 [OPTIONS]

Options:
    --upgrade       Upgrade existing installation to latest version
    --uninstall     Remove ${NAME} from system
    --prefix DIR    Install to custom prefix (default: ${DEFAULT_PREFIX})
    --version VER   Install specific version (default: latest)
    --help          Show this help message

One-liner installation:
    curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash

One-liner upgrade:
    curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash -s -- --upgrade

EOF
}

get_latest_version() {
    local version
    version=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | \
              grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/' || echo "")

    if [[ -z "${version}" ]]; then
        # Fallback: get from main branch VERSION file
        version=$(curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/VERSION" 2>/dev/null || echo "0.1.0")
    fi
    echo "${version}"
}

get_installed_version() {
    local version_file="${CONFIG_DIR}/version"
    if [[ -f "${version_file}" ]]; then
        cat "${version_file}"
    else
        echo ""
    fi
}

check_dependencies() {
    local missing=()

    for cmd in curl tar; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing+=("${cmd}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}

download_release() {
    local version="$1"
    local dest="$2"
    local url

    # Try release tarball first
    url="https://github.com/${REPO}/archive/refs/tags/v${version}.tar.gz"
    log_info "Downloading ${NAME} v${version}..."

    if ! curl -fsSL "${url}" -o "${dest}" 2>/dev/null; then
        # Fallback: download from main branch
        url="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
        log_warn "Release not found, downloading from main branch..."
        if ! curl -fsSL "${url}" -o "${dest}"; then
            log_error "Failed to download ${NAME}"
            exit 1
        fi
    fi
}

install_files() {
    local prefix="$1"
    local version="$2"
    local install_dir="${prefix}/share/${NAME}"
    local bin_dir="${prefix}/bin"
    local temp_dir

    temp_dir=$(mktemp -d)
    trap "rm -rf '${temp_dir}'" EXIT

    # Download
    download_release "${version}" "${temp_dir}/release.tar.gz"

    # Extract
    log_info "Extracting..."
    tar -xzf "${temp_dir}/release.tar.gz" -C "${temp_dir}"

    # Find extracted directory
    local src_dir
    src_dir=$(find "${temp_dir}" -maxdepth 1 -type d -name "${NAME}*" -o -name "dc-scripts*" | head -1)
    if [[ -z "${src_dir}" ]] || [[ "${src_dir}" == "${temp_dir}" ]]; then
        src_dir=$(find "${temp_dir}" -maxdepth 1 -type d ! -name "$(basename "${temp_dir}")" | head -1)
    fi

    if [[ -z "${src_dir}" ]]; then
        log_error "Could not find extracted source directory"
        exit 1
    fi

    # Create directories
    log_info "Installing to ${install_dir}..."
    sudo mkdir -p "${install_dir}"
    sudo mkdir -p "${bin_dir}"
    mkdir -p "${CONFIG_DIR}"

    # Copy files
    sudo cp -r "${src_dir}/lib" "${install_dir}/"
    sudo cp -r "${src_dir}/docs" "${install_dir}/" 2>/dev/null || true
    sudo cp -r "${src_dir}/examples" "${install_dir}/" 2>/dev/null || true
    sudo cp -r "${src_dir}/tests" "${install_dir}/" 2>/dev/null || true
    sudo cp "${src_dir}/restore.sh" "${install_dir}/"
    sudo cp "${src_dir}/migrate_v2.sh" "${install_dir}/"
    sudo cp "${src_dir}/VERSION" "${install_dir}/"
    sudo cp "${src_dir}/Makefile" "${install_dir}/" 2>/dev/null || true

    # Make scripts executable
    sudo chmod +x "${install_dir}/restore.sh"
    sudo chmod +x "${install_dir}/migrate_v2.sh"

    # Create symlinks
    log_info "Creating symlinks..."
    sudo ln -sf "${install_dir}/restore.sh" "${bin_dir}/dc-restore"
    sudo ln -sf "${install_dir}/migrate_v2.sh" "${bin_dir}/dc-migrate"

    # Save version to config
    echo "${version}" > "${CONFIG_DIR}/version"
    echo "${install_dir}" > "${CONFIG_DIR}/install_dir"
    date +%Y-%m-%d > "${CONFIG_DIR}/install_date"

    log_ok "Installed ${NAME} v${version}"
    log_ok "Commands available: dc-restore, dc-migrate"
    log_ok "Config directory: ${CONFIG_DIR}"
}

uninstall() {
    local prefix="$1"
    local install_dir="${prefix}/share/${NAME}"
    local bin_dir="${prefix}/bin"

    log_info "Uninstalling ${NAME}..."

    # Remove symlinks
    sudo rm -f "${bin_dir}/dc-restore"
    sudo rm -f "${bin_dir}/dc-migrate"

    # Remove install directory
    sudo rm -rf "${install_dir}"

    log_ok "Uninstalled ${NAME}"
    log_info "Config preserved in ${CONFIG_DIR}"
    log_info "To remove config: rm -rf ${CONFIG_DIR}"
}

upgrade() {
    local prefix="$1"
    local current_version
    local latest_version

    current_version=$(get_installed_version)
    latest_version=$(get_latest_version)

    if [[ -z "${current_version}" ]]; then
        log_warn "No existing installation found. Running fresh install..."
        install_files "${prefix}" "${latest_version}"
        return
    fi

    log_info "Current version: ${current_version}"
    log_info "Latest version:  ${latest_version}"

    if [[ "${current_version}" == "${latest_version}" ]]; then
        log_ok "Already at latest version (${current_version})"
        return
    fi

    log_info "Upgrading ${current_version} -> ${latest_version}..."
    install_files "${prefix}" "${latest_version}"
    log_ok "Upgraded to v${latest_version}"
}

#===============================================================================
# Main
#===============================================================================

main() {
    local action="install"
    local prefix="${DEFAULT_PREFIX}"
    local version=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --upgrade)
                action="upgrade"
                shift
                ;;
            --uninstall)
                action="uninstall"
                shift
                ;;
            --prefix)
                prefix="$2"
                shift 2
                ;;
            --version)
                version="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Check dependencies
    check_dependencies

    # Execute action
    case "${action}" in
        install)
            if [[ -z "${version}" ]]; then
                version=$(get_latest_version)
            fi
            log_info "Installing ${NAME} v${version}..."
            install_files "${prefix}" "${version}"
            ;;
        upgrade)
            upgrade "${prefix}"
            ;;
        uninstall)
            uninstall "${prefix}"
            ;;
    esac

    echo ""
    log_ok "Done!"
}

main "$@"
