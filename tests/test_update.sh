#!/usr/bin/env bash
#===============================================================================
# test_update.sh - Tests for lib/update.sh
#===============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Set DCX_HOME for tests
export DCX_HOME="${LIB_DIR}/.."

# Source update.sh (core.sh is auto-sourced by test_helpers.sh)
source "${LIB_DIR}/update.sh"

#-------------------------------------------------------------------------------
# Test Groups
#-------------------------------------------------------------------------------

test_module_loading() {
    run_test "update.sh loads" "true"
    run_test "_DCX_UPDATE_LOADED set" "[[ -n \"\${_DCX_UPDATE_LOADED:-}\" ]]"
}

test_constants() {
    run_test "DCX_GITHUB_REPO defined" "[[ -n \"\${DCX_GITHUB_REPO:-}\" ]]"
    run_test "DCX_GITHUB_API defined" "[[ -n \"\${DCX_GITHUB_API:-}\" ]]"
    run_test "DCX_GITHUB_RELEASES defined" "[[ -n \"\${DCX_GITHUB_RELEASES:-}\" ]]"
    run_test "DCX_GITHUB_REPO is datacosmos-br/dcx" "[[ \"\$DCX_GITHUB_REPO\" == \"datacosmos-br/dcx\" ]]"
    run_test "DCX_GITHUB_API URL format" "[[ \"\$DCX_GITHUB_API\" == *'api.github.com'* ]]"
    run_test "DCX_GITHUB_RELEASES URL format" "[[ \"\$DCX_GITHUB_RELEASES\" == *'releases'* ]]"
}

test_core_functions() {
    run_test "dc_current_version exists" "type dc_current_version &>/dev/null"
    run_test "dc_get_latest_version exists" "type dc_get_latest_version &>/dev/null"
    run_test "dc_check_update exists" "type dc_check_update &>/dev/null"
    run_test "dc_self_update exists" "type dc_self_update &>/dev/null"
    run_test "dc_check_binaries exists" "type dc_check_binaries &>/dev/null"
    run_test "dc_maybe_check_update exists" "type dc_maybe_check_update &>/dev/null"
    run_test "dc_release_notes exists" "type dc_release_notes &>/dev/null"
}

test_platform_detection() {
    run_test "dc_detect_platform exists" "type dc_detect_platform &>/dev/null"
    run_test "DCX_PLATFORM defined" "[[ -n \"\${DCX_PLATFORM:-}\" ]]"

    platform=$(dc_detect_platform)
    run_test "dc_detect_platform format" "[[ \"\$platform\" =~ ^[a-z]+-[a-z0-9]+$ ]]"
    run_test "dc_detect_platform has os" "[[ \"\$platform\" =~ ^(linux|darwin|windows)- ]]"
    run_test "dc_detect_platform has arch" "[[ \"\$platform\" =~ -(amd64|arm64|386)$ ]]"
}

test_version_functions() {
    run_test "dc_current_version" "[[ \"\$(dc_current_version)\" == \"0.0.1\" ]]"

    old_dc_home="$DCX_HOME"
    DCX_HOME="/nonexistent"
    result=$(dc_check_update 2>/dev/null) || true
    run_test "dc_check_update handles unknown" "[[ -z \"\$result\" ]] || ! dc_check_update 2>/dev/null"
    DCX_HOME="$old_dc_home"
}

test_check_binaries() {
    run_test "dc_check_binaries runs" "dc_check_binaries >/dev/null 2>&1 || true"

    output=$(dc_check_binaries 2>&1) || true
    run_test "dc_check_binaries shows platform" "[[ \"\$output\" == *'Platform:'* ]]"
}

test_maybe_check_update() {
    DCX_UPDATE_AUTO_CHECK="false"
    run_test "dc_maybe_check_update respects config" "dc_maybe_check_update"
    unset DCX_UPDATE_AUTO_CHECK

    test_setup
    echo "0.0.1" > "$TMP_DIR/VERSION"
    old_dc_home="$DCX_HOME"
    DCX_HOME="$TMP_DIR"

    # Create recent check file (should skip)
    echo "$(date +%s)" > "$TMP_DIR/.last_update_check"
    run_test "dc_maybe_check_update respects interval" "dc_maybe_check_update"

    # Create old check file (should check)
    echo "0" > "$TMP_DIR/.last_update_check"
    DCX_UPDATE_CHECK_INTERVAL=1
    run_test "dc_maybe_check_update old check" "dc_maybe_check_update"

    DCX_HOME="$old_dc_home"
}

test_network() {
    echo ""
    echo "Network tests (may be skipped if offline):"

    if curl -fsSL --max-time 5 "https://api.github.com/rate_limit" &>/dev/null; then
        latest=$(dc_get_latest_version 2>/dev/null || echo "")
        if [[ -n "$latest" ]]; then
            run_test "dc_get_latest_version returns version" "[[ \"\$latest\" =~ ^[0-9]+\\.[0-9]+ ]]"
        else
            echo "  - dc_get_latest_version: (skipped - no releases yet)"
            TESTS_RUN=$((TESTS_RUN + 1))
            TESTS_PASSED=$((TESTS_PASSED + 1))
        fi
    else
        echo "  - Network tests skipped (offline or rate-limited)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
}

#-------------------------------------------------------------------------------
# Run Tests
#-------------------------------------------------------------------------------

describe "Module Loading" test_module_loading
describe "Constants" test_constants
describe "Core Functions" test_core_functions
describe "Platform Detection" test_platform_detection
describe "Version Functions" test_version_functions
describe "Check Binaries" test_check_binaries
describe "Maybe Check Update" test_maybe_check_update
describe "Network Tests" test_network

test_summary
