#!/usr/bin/env bash
#===============================================================================
# test_core.sh - Tests for lib/core.sh
#===============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

echo "Testing core.sh..."
echo ""

# Source core.sh
source "${LIB_DIR}/core.sh"

# Tests
run_test "core.sh loads" "true"
run_test "DCX_VERSION is set" "[[ -n \"\${DCX_VERSION:-}\" ]]"
run_test "DCX_VERSION is correct" "[[ \"\${DCX_VERSION}\" == \"0.0.1\" ]]"
run_test "dc_init exists" "type dc_init &>/dev/null"
run_test "dc_require exists" "type dc_require &>/dev/null"
run_test "dc_version exists" "type dc_version &>/dev/null"
run_test "dc_source exists" "type dc_source &>/dev/null"
run_test "dc_load exists" "type dc_load &>/dev/null"
run_test "dc_init succeeds" "dc_init"
run_test "DCX_INITIALIZED is set" "[[ \"\${DCX_INITIALIZED:-}\" == \"1\" ]]"
run_test "dc_version output" "[[ \"\$(dc_version)\" == \"dcx v0.0.1\" ]]"
run_test "dc_require idempotent" "dc_require && dc_require"
run_test "_DC_CORE_LOADED set" "[[ -n \"\${_DC_CORE_LOADED:-}\" ]]"

test_summary
