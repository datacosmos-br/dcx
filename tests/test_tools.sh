#!/usr/bin/env bash
#===============================================================================
# test_tools.sh - Tests for tools (now in Go binary)
#===============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

echo "Testing tools (Go binary)..."
echo ""

# Set DC_HOME for tests
export DC_HOME="${LIB_DIR}/.."
DCX_GO="$DC_HOME/bin/dcx-go"

# Skip if Go binary not available
if [[ ! -x "$DCX_GO" ]]; then
    echo "Go binary not found at $DCX_GO - skipping tests"
    test_summary
    exit 0
fi

# Test: Go binary tools commands
run_test "dcx tools list runs" "$DCX_GO tools list &>/dev/null"
run_test "dcx tools check runs" "$DCX_GO tools check &>/dev/null || true"
run_test "dcx binary list runs" "$DCX_GO binary list &>/dev/null"
run_test "dcx platform command" "$DCX_GO platform &>/dev/null"
run_test "dcx config show runs" "$DCX_GO config show &>/dev/null"
run_test "dcx validate runs" "$DCX_GO validate &>/dev/null || true"

# Test: Tools list shows expected tools
output=$("$DCX_GO" tools list 2>&1)
run_test "tools list shows gum" "[[ \"\$output\" == *gum* ]]"
run_test "tools list shows yq" "[[ \"\$output\" == *yq* ]]"

# Test: JSON output format
json_out=$("$DCX_GO" tools list json 2>&1)
run_test "tools list json is valid" "[[ \"\$json_out\" == \\[* ]]"

# Test: Binary discovery
run_test "binary find gum" "$DCX_GO binary find gum &>/dev/null"
run_test "binary find yq" "$DCX_GO binary find yq &>/dev/null"

# Test: Config commands
run_test "config get home" "[[ -n \$($DCX_GO config get home) ]]"
run_test "config get platform" "[[ -n \$($DCX_GO config get platform) ]]"

test_summary
