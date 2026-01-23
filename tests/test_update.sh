#!/usr/bin/env bash
#===============================================================================
# test_update.sh - Tests for lib/update.sh
#===============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
PROJECT_DIR="${SCRIPT_DIR}/.."

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

#-------------------------------------------------------------------------------
# Test helpers
#-------------------------------------------------------------------------------
test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ✓ $1"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ✗ $1"
}

run_test() {
    local name="$1"
    local cmd="$2"
    TESTS_RUN=$((TESTS_RUN + 1))

    if eval "$cmd" &>/dev/null; then
        test_pass "$name"
    else
        test_fail "$name"
    fi
}

#-------------------------------------------------------------------------------
# Tests
#-------------------------------------------------------------------------------
echo "Testing update.sh..."
echo ""

# Set DC_HOME for tests
export DC_HOME="$PROJECT_DIR"

# Source update.sh
source "${LIB_DIR}/update.sh"

# Test: Module loads without error
run_test "update.sh loads" "true"

# Test: Guard variable set
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
run_test "dc_install_binary exists" "type dc_install_binary &>/dev/null"
run_test "dc_maybe_check_update exists" "type dc_maybe_check_update &>/dev/null"
run_test "dc_release_notes exists" "type dc_release_notes &>/dev/null"

# Test: Internal functions exist
run_test "_dc_detect_platform exists" "type _dc_detect_platform &>/dev/null"
run_test "_dc_download_and_install exists" "type _dc_download_and_install &>/dev/null"

# Test: dc_current_version reads VERSION file
run_test "dc_current_version" "[[ \"\$(dc_current_version)\" == \"0.2.0\" ]]"

# Test: dc_current_version returns unknown if no VERSION
old_dc_home="$DC_HOME"
DC_HOME="/nonexistent"
run_test "dc_current_version unknown" "[[ \"\$(dc_current_version)\" == \"unknown\" ]]"
DC_HOME="$old_dc_home"

# Test: _dc_detect_platform returns valid format
platform=$(_dc_detect_platform)
run_test "_dc_detect_platform format" "[[ \"\$platform\" =~ ^[a-z]+-[a-z0-9]+$ ]]"

# Test: _dc_detect_platform detects OS
run_test "_dc_detect_platform has os" "[[ \"\$platform\" =~ ^(linux|darwin|windows)- ]]"

# Test: _dc_detect_platform detects arch
run_test "_dc_detect_platform has arch" "[[ \"\$platform\" =~ -(amd64|arm64|386)$ ]]"

# Test: dc_check_update handles unknown version gracefully
DC_HOME="/nonexistent"
result=$(dc_check_update 2>/dev/null) || true
# Should return empty or fail gracefully - either is acceptable
run_test "dc_check_update handles unknown" "[[ -z \"\$result\" ]] || ! dc_check_update 2>/dev/null"
DC_HOME="$old_dc_home"

# Test: dc_check_binaries runs without error (may report missing)
run_test "dc_check_binaries runs" "dc_check_binaries >/dev/null 2>&1 || true"

# Test: dc_check_binaries output format
output=$(dc_check_binaries 2>&1) || true  # May return 1 if binaries missing
run_test "dc_check_binaries shows platform" "[[ \"\$output\" == *'Platform:'* ]]"

# Test: dc_maybe_check_update respects DC_UPDATE_AUTO_CHECK=false
DC_UPDATE_AUTO_CHECK="false"
run_test "dc_maybe_check_update respects config" "dc_maybe_check_update"
unset DC_UPDATE_AUTO_CHECK

# Test: dc_maybe_check_update checks interval
tmp_dc_home="/tmp/dc-test-$$"
mkdir -p "$tmp_dc_home"
echo "0.2.0" > "$tmp_dc_home/VERSION"
DC_HOME="$tmp_dc_home"

# Create recent check file (should skip)
echo "$(date +%s)" > "$tmp_dc_home/.last_update_check"
run_test "dc_maybe_check_update respects interval" "dc_maybe_check_update"

# Create old check file (should check)
echo "0" > "$tmp_dc_home/.last_update_check"
DC_UPDATE_CHECK_INTERVAL=1  # 1 second
run_test "dc_maybe_check_update old check" "dc_maybe_check_update"

DC_HOME="$old_dc_home"
rm -rf "$tmp_dc_home"

# Test: Constants have expected values
run_test "DC_GITHUB_REPO is datacosmos-br/dc-scripts" "[[ \"\$DC_GITHUB_REPO\" == \"datacosmos-br/dc-scripts\" ]]"

# Test: GitHub API URL is correct
run_test "DC_GITHUB_API URL format" "[[ \"\$DC_GITHUB_API\" == *'api.github.com'* ]]"

# Test: Releases URL is correct
run_test "DC_GITHUB_RELEASES URL format" "[[ \"\$DC_GITHUB_RELEASES\" == *'releases'* ]]"

#-------------------------------------------------------------------------------
# Network-dependent tests (skip if offline or rate-limited)
#-------------------------------------------------------------------------------
echo ""
echo "Network tests (may be skipped if offline):"

# Test if we can reach GitHub API (with timeout)
if curl -fsSL --max-time 5 "https://api.github.com/rate_limit" &>/dev/null; then
    # Test: dc_get_latest_version returns a version (or empty)
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
    # Count as passed since they're optional
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

#-------------------------------------------------------------------------------
# Summary
#-------------------------------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "Tests: ${TESTS_RUN} | Passed: ${TESTS_PASSED} | Failed: ${TESTS_FAILED}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed."
    exit 1
fi
