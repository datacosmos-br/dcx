#!/usr/bin/env bash
#===============================================================================
# dc-scripts/lib/constants.sh - Project Constants
#===============================================================================
# Provides project-specific constants (name, repo, etc.)
# Paths and platform detection are in core.sh
#===============================================================================

[[ -n "${_DC_CONSTANTS_LOADED:-}" ]] && return 0
declare -r _DC_CONSTANTS_LOADED=1

# Source core.sh for DC_HOME, DC_PLATFORM, etc.
# shellcheck source=core.sh
source "${BASH_SOURCE[0]%/*}/core.sh"

# DC_ETC_DIR (not in core.sh)
DC_ETC_DIR="${DC_HOME}/etc"
export DC_ETC_DIR

# Project constants
DC_PROJECT_NAME="DCX"
DC_PROJECT_FULL_NAME="Datacosmos Command eXecutor"
DC_GITHUB_REPO="datacosmos-br/dc-scripts"
DC_GITHUB_API="https://api.github.com/repos/${DC_GITHUB_REPO}"
DC_GITHUB_RELEASES="${DC_GITHUB_API}/releases"
export DC_PROJECT_NAME DC_PROJECT_FULL_NAME DC_GITHUB_REPO DC_GITHUB_API DC_GITHUB_RELEASES
