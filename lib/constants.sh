#!/usr/bin/env bash
#===============================================================================
# dcx/lib/constants.sh - Project Constants
#===============================================================================
# Provides project-specific constants (name, repo, etc.)
# Paths and platform detection are in core.sh
#===============================================================================

[[ -n "${_DCX_CONSTANTS_LOADED:-}" ]] && return 0
declare -r _DCX_CONSTANTS_LOADED=1

# Source core.sh for DCX_HOME, DCX_PLATFORM, etc.
# shellcheck source=core.sh
source "${BASH_SOURCE[0]%/*}/core.sh"

# DCX_ETC_DIR (not in core.sh)
DCX_ETC_DIR="${DCX_HOME}/etc"
export DCX_ETC_DIR

# Project constants
DCX_PROJECT_NAME="dcx"
DCX_PROJECT_FULL_NAME="Datacosmos Command eXecutor"
DCX_GITHUB_REPO="datacosmos-br/dcx"
DCX_GITHUB_API="https://api.github.com/repos/${DCX_GITHUB_REPO}"
DCX_GITHUB_RELEASES="${DCX_GITHUB_API}/releases"
export DCX_PROJECT_NAME DCX_PROJECT_FULL_NAME DCX_GITHUB_REPO DCX_GITHUB_API DCX_GITHUB_RELEASES
