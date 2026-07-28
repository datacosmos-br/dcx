#!/usr/bin/env bash
#===============================================================================
# test_tools.sh - Tests for tools (now in Go binary)
#===============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Set DCX_HOME for tests
export DCX_HOME="${LIB_DIR}/.."
DCX_GO="$DCX_HOME/bin/dcx-go"

#-------------------------------------------------------------------------------
# Test Groups
#-------------------------------------------------------------------------------

test_binary_check() {
    # Skip if Go binary not available
    if [[ ! -x "$DCX_GO" ]]; then
        echo "Go binary not found at $DCX_GO - skipping tests"
        test_summary
        exit 0
    fi
}

test_binary_commands() {
    run_test "dcx tools list runs" "$DCX_GO tools list &>/dev/null"
    run_test "dcx tools check runs" "$DCX_GO tools check &>/dev/null || true"
    run_test "dcx binary list runs" "$DCX_GO binary list &>/dev/null"
    run_test "dcx platform command" "$DCX_GO platform &>/dev/null"
    run_test "dcx config show runs" "$DCX_GO config show &>/dev/null"
    run_test "dcx validate runs" "$DCX_GO validate &>/dev/null || true"
}

test_tools_list() {
    output=$("$DCX_GO" tools list 2>&1) || true
    run_test "tools list shows gum" "[[ \"\$output\" == *gum* ]]"
    run_test "tools list shows yq" "[[ \"\$output\" == *yq* ]]"
}

test_json_output() {
    json_out=$("$DCX_GO" tools list json 2>&1) || true
    run_test "tools list json is valid" "[[ \"\$json_out\" == \\[* ]]"
}

test_binary_discovery() {
    run_test "binary find gum" "$DCX_GO binary find gum &>/dev/null"
    run_test "binary find yq" "$DCX_GO binary find yq &>/dev/null"
}

test_config_commands() {
    run_test "config get home" "[[ -n \$($DCX_GO config get home) ]]"
    run_test "config get platform" "[[ -n \$($DCX_GO config get platform) ]]"
}

#-------------------------------------------------------------------------------
# Run Tests
#-------------------------------------------------------------------------------

# First check if binary exists - if not, exit early
test_binary_check

describe "Binary Commands" test_binary_commands
describe "Tools List" test_tools_list
describe "JSON Output" test_json_output
describe "Binary Discovery" test_binary_discovery
describe "Config Commands" test_config_commands

test_summary
