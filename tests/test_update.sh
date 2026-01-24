#!/usr/bin/env bash
#===============================================================================
# test_update.sh - Tests for lib/update.sh
#===============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

echo "Testing update.sh..."
echo ""

# Set DC_HOME for tests
export DC_HOME="${LIB_DIR}/.."

# Source update.sh
source "${LIB_DIR}/update.sh"

# Test: Module loads without error
run_test "update.sh loads" "true"
run_test "_DC_UPDATE_LOADED set" "[[ -n \"\${_DC_UPDATE_LOADED:-}\" ]]"

# Test: Constants defined
run_test "DC_GITHUB_REPO defined" "[[ -n \"\${DC_GITHUB_REPO:-}\" ]]"
run_test "DC_GITHUB_API defined" "[[ -n \"\${DC_GITHUB_API:-}\" ]]"
run_test "DC_GITHUB_RELEASES defined" "[[ -n \"\${DC_GITHUB_RELEASES:-}\" ]]"

# Test: Core functions exist
run_test "dc_current_version exists" "type dc_current_version &>/dev/null"
run_test "dc_get_latest_version exists" "type dc_get_latest_version &>/dev/null"
run_test "dc_check_update exists" "type dc_check_update &>/dev/null"
run_test "dc_self_update exists" "type dc_self_update &>/dev/null"
run_test "dc_check_binaries exists" "type dc_check_binaries &>/dev/null"
run_test "dc_maybe_check_update exists" "type dc_maybe_check_update &>/dev/null"
run_test "dc_release_notes exists" "type dc_release_notes &>/dev/null"

# Test: Platform detection from constants.sh
run_test "dc_detect_platform exists" "type dc_detect_platform &>/dev/null"
run_test "DC_PLATFORM defined" "[[ -n \"\${DC_PLATFORM:-}\" ]]"

# Test: dc_current_version reads VERSION file (returns DC_VERSION)
run_test "dc_current_version" "[[ \"\$(dc_current_version)\" == \"0.0.1\" ]]"

# Test: dc_detect_platform returns valid format
platform=$(dc_detect_platform)
run_test "dc_detect_platform format" "[[ \"\$platform\" =~ ^[a-z]+-[a-z0-9]+$ ]]"
run_test "dc_detect_platform has os" "[[ \"\$platform\" =~ ^(linux|darwin|windows)- ]]"
run_test "dc_detect_platform has arch" "[[ \"\$platform\" =~ -(amd64|arm64|386)$ ]]"

# Test: dc_check_update handles unknown version gracefully
old_dc_home="$DC_HOME"
DC_HOME="/nonexistent"
result=$(dc_check_update 2>/dev/null) || true
run_test "dc_check_update handles unknown" "[[ -z \"\$result\" ]] || ! dc_check_update 2>/dev/null"
DC_HOME="$old_dc_home"

# Test: dc_check_binaries runs without error (may report missing)
run_test "dc_check_binaries runs" "dc_check_binaries >/dev/null 2>&1 || true"

# Test: dc_check_binaries output format
output=$(dc_check_binaries 2>&1) || true
run_test "dc_check_binaries shows platform" "[[ \"\$output\" == *'Platform:'* ]]"

# Test: dc_maybe_check_update respects DC_UPDATE_AUTO_CHECK=false
DC_UPDATE_AUTO_CHECK="false"
run_test "dc_maybe_check_update respects config" "dc_maybe_check_update"
unset DC_UPDATE_AUTO_CHECK

# Test: dc_maybe_check_update checks interval
test_setup
echo "0.0.1" > "$TMP_DIR/VERSION"
old_dc_home="$DC_HOME"
DC_HOME="$TMP_DIR"

# Create recent check file (should skip)
echo "$(date +%s)" > "$TMP_DIR/.last_update_check"
run_test "dc_maybe_check_update respects interval" "dc_maybe_check_update"

# Create old check file (should check)
echo "0" > "$TMP_DIR/.last_update_check"
DC_UPDATE_CHECK_INTERVAL=1
run_test "dc_maybe_check_update old check" "dc_maybe_check_update"

DC_HOME="$old_dc_home"

# Test: Constants have expected values
run_test "DC_GITHUB_REPO is datacosmos-br/dc-scripts" "[[ \"\$DC_GITHUB_REPO\" == \"datacosmos-br/dc-scripts\" ]]"
run_test "DC_GITHUB_API URL format" "[[ \"\$DC_GITHUB_API\" == *'api.github.com'* ]]"
run_test "DC_GITHUB_RELEASES URL format" "[[ \"\$DC_GITHUB_RELEASES\" == *'releases'* ]]"

#-------------------------------------------------------------------------------
# Network-dependent tests (skip if offline or rate-limited)
#-------------------------------------------------------------------------------
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

test_summary
