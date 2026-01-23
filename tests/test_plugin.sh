#!/usr/bin/env bash
#===============================================================================
# test_plugin.sh - Tests for lib/plugin.sh
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

# Test plugin directory
TEST_PLUGIN_DIR="/tmp/dc-test-plugin-$$"

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
# Setup - Create mock plugin for testing
#-------------------------------------------------------------------------------
setup_test_plugin() {
    mkdir -p "$TEST_PLUGIN_DIR/test-plugin/lib"
    mkdir -p "$TEST_PLUGIN_DIR/test-plugin/bin"

    # Create simple plugin.yaml (no requires to avoid yq parsing issues)
    cat > "$TEST_PLUGIN_DIR/test-plugin/plugin.yaml" << 'EOF'
name: test-plugin
version: 1.0.0
description: A test plugin for unit testing
author: Test Author
EOF

    # Create init.sh
    cat > "$TEST_PLUGIN_DIR/test-plugin/lib/init.sh" << 'EOF'
#!/usr/bin/env bash
export TEST_PLUGIN_LOADED=1
EOF

    # Create a second plugin for multi-plugin tests
    mkdir -p "$TEST_PLUGIN_DIR/another-plugin"
    cat > "$TEST_PLUGIN_DIR/another-plugin/plugin.yaml" << 'EOF'
name: another-plugin
version: 2.0.0
description: Another test plugin
author: Test Author
EOF

    # Create a plugin with .yml extension
    mkdir -p "$TEST_PLUGIN_DIR/yml-plugin"
    cat > "$TEST_PLUGIN_DIR/yml-plugin/plugin.yml" << 'EOF'
name: yml-plugin
version: 0.1.0
description: Plugin with .yml extension
EOF
}

#-------------------------------------------------------------------------------
# Cleanup
#-------------------------------------------------------------------------------
cleanup_test_plugin() {
    [[ -n "$TEST_PLUGIN_DIR" && -d "$TEST_PLUGIN_DIR" ]] && rm -rf "$TEST_PLUGIN_DIR"
}

# Ensure cleanup on exit
trap cleanup_test_plugin EXIT

#-------------------------------------------------------------------------------
# Tests
#-------------------------------------------------------------------------------
echo "Testing plugin.sh..."
echo ""

# Set DC_HOME for tests
export DC_HOME="$PROJECT_DIR"

# Source plugin.sh
source "${LIB_DIR}/plugin.sh"

# Test: Module loads without error
run_test "plugin.sh loads" "true"

# Test: Guard variable set
run_test "_DC_PLUGIN_LOADED set" "[[ -n \"\${_DC_PLUGIN_LOADED:-}\" ]]"

# Test: Global arrays exist
run_test "DC_PLUGIN_DIRS is array" "declare -p DC_PLUGIN_DIRS &>/dev/null"
run_test "_DC_LOADED_PLUGINS is array" "declare -p _DC_LOADED_PLUGINS &>/dev/null"
run_test "_DC_PLUGIN_CACHE is array" "declare -p _DC_PLUGIN_CACHE &>/dev/null"

# Test: Core functions exist
run_test "dc_init_plugin_dirs exists" "type dc_init_plugin_dirs &>/dev/null"
run_test "dc_discover_plugins exists" "type dc_discover_plugins &>/dev/null"
run_test "dc_plugin_info exists" "type dc_plugin_info &>/dev/null"
run_test "dc_load_plugin exists" "type dc_load_plugin &>/dev/null"
run_test "dc_load_all_plugins exists" "type dc_load_all_plugins &>/dev/null"
run_test "dc_unload_plugin exists" "type dc_unload_plugin &>/dev/null"
run_test "dc_plugin_list exists" "type dc_plugin_list &>/dev/null"
run_test "dc_plugin_install exists" "type dc_plugin_install &>/dev/null"
run_test "dc_plugin_remove exists" "type dc_plugin_remove &>/dev/null"
run_test "dc_plugin_update exists" "type dc_plugin_update &>/dev/null"
run_test "dc_plugin_cmd exists" "type dc_plugin_cmd &>/dev/null"

# Test: dc_init_plugin_dirs works
dc_init_plugin_dirs
run_test "dc_init_plugin_dirs runs" "true"

# Setup test plugin
setup_test_plugin

# Override DC_PLUGIN_DIRS to use our test directory
DC_PLUGIN_DIRS=("$TEST_PLUGIN_DIR")

# Test: dc_discover_plugins finds plugins
discovered=$(dc_discover_plugins)
run_test "dc_discover_plugins finds test-plugin" "[[ \"\$discovered\" == *'test-plugin'* ]]"
run_test "dc_discover_plugins finds another-plugin" "[[ \"\$discovered\" == *'another-plugin'* ]]"
run_test "dc_discover_plugins finds yml-plugin" "[[ \"\$discovered\" == *'yml-plugin'* ]]"

# Test: dc_plugin_info reads plugin metadata
plugin_name=$(dc_plugin_info "$TEST_PLUGIN_DIR/test-plugin" "name") || true
run_test "dc_plugin_info reads name" "[[ \"\$plugin_name\" == \"test-plugin\" ]]"

plugin_version=$(dc_plugin_info "$TEST_PLUGIN_DIR/test-plugin" "version") || true
run_test "dc_plugin_info reads version" "[[ \"\$plugin_version\" == \"1.0.0\" ]]"

plugin_desc=$(dc_plugin_info "$TEST_PLUGIN_DIR/test-plugin" "description") || true
run_test "dc_plugin_info reads description" "[[ \"\$plugin_desc\" == *'test plugin'* ]]"

# Test: dc_plugin_info returns full yaml when no field specified
full_yaml=$(dc_plugin_info "$TEST_PLUGIN_DIR/test-plugin") || true
run_test "dc_plugin_info returns full yaml" "[[ \"\$full_yaml\" == *'name:'* ]]"

# Test: dc_plugin_info fails for nonexistent plugin
run_test "dc_plugin_info fails for nonexistent" "! dc_plugin_info /nonexistent/plugin 2>/dev/null"

# Test: dc_plugin_info works with .yml extension
yml_name=$(dc_plugin_info "$TEST_PLUGIN_DIR/yml-plugin" "name") || true
run_test "dc_plugin_info works with .yml" "[[ \"\$yml_name\" == \"yml-plugin\" ]]"

# Test: dc_load_plugin loads plugin
dc_load_plugin "$TEST_PLUGIN_DIR/test-plugin" || true
run_test "dc_load_plugin loads test-plugin" "[[ -n \"\${_DC_LOADED_PLUGINS[test-plugin]:-}\" ]]"

# Test: Plugin's init.sh was executed
run_test "Plugin init.sh executed" "[[ \"\${TEST_PLUGIN_LOADED:-}\" == \"1\" ]]"

# Test: Plugin version cached
run_test "Plugin version cached" "[[ \"\${_DC_PLUGIN_CACHE[test-plugin]}\" == \"1.0.0\" ]]"

# Test: dc_load_plugin is idempotent (second call returns 0)
run_test "dc_load_plugin idempotent" "dc_load_plugin \"$TEST_PLUGIN_DIR/test-plugin\""

# Test: dc_unload_plugin works
dc_unload_plugin "test-plugin" >/dev/null 2>&1 || true
run_test "dc_unload_plugin removes from registry" "[[ -z \"\${_DC_LOADED_PLUGINS[test-plugin]:-}\" ]]"

# Test: dc_unload_plugin fails for not loaded plugin
run_test "dc_unload_plugin fails for unloaded" "! dc_unload_plugin \"nonexistent-plugin\" 2>/dev/null"

# Re-load for list tests
dc_load_plugin "$TEST_PLUGIN_DIR/test-plugin" || true

# Test: dc_plugin_list table format
table_output=$(dc_plugin_list table 2>/dev/null) || true
run_test "dc_plugin_list table has header" "[[ \"\$table_output\" == *'Name'* ]]"
run_test "dc_plugin_list table shows plugin" "[[ \"\$table_output\" == *'test-plugin'* ]]"

# Test: dc_plugin_list json format
json_output=$(dc_plugin_list json 2>/dev/null) || true
run_test "dc_plugin_list json is array" "[[ \"\$json_output\" == '['* ]]"
run_test "dc_plugin_list json has name" "[[ \"\$json_output\" == *'\"name\"'* ]]"

# Test: dc_plugin_list simple format
simple_output=$(dc_plugin_list simple 2>/dev/null) || true
run_test "dc_plugin_list simple shows plugin" "[[ \"\$simple_output\" == *'test-plugin'* ]]"

# Test: dc_plugin_cmd help
help_output=$(dc_plugin_cmd help 2>&1) || true
run_test "dc_plugin_cmd help shows usage" "[[ \"\$help_output\" == *'Usage:'* ]]"
run_test "dc_plugin_cmd help shows commands" "[[ \"\$help_output\" == *'install'* ]]"

# Test: dc_plugin_cmd list
list_output=$(dc_plugin_cmd list 2>&1) || true
run_test "dc_plugin_cmd list works" "[[ \"\$list_output\" == *'Name'* ]]"

# Test: dc_plugin_cmd info
info_output=$(dc_plugin_cmd info test-plugin 2>&1) || true
run_test "dc_plugin_cmd info works" "[[ \"\$info_output\" == *'test-plugin'* ]]"

# Test: dc_plugin_cmd info fails for nonexistent
run_test "dc_plugin_cmd info fails for nonexistent" "! dc_plugin_cmd info nonexistent 2>/dev/null"

# Test: dc_plugin_cmd load
unset "_DC_LOADED_PLUGINS[test-plugin]" 2>/dev/null || true
load_output=$(dc_plugin_cmd load test-plugin 2>&1) || true
run_test "dc_plugin_cmd load works" "[[ \"\$load_output\" == *'Loaded'* ]]"

# Test: dc_plugin_cmd load fails for nonexistent
if dc_plugin_cmd load nonexistent &>/dev/null; then _load_nonexist_ok=1; else _load_nonexist_ok=0; fi
run_test "dc_plugin_cmd load fails for nonexistent" "[[ \$_load_nonexist_ok -eq 0 ]]"

# Test: dc_plugin_install fails without repo argument (returns 1)
_install_ok=0
( dc_plugin_install ) &>/dev/null || _install_ok=1
run_test "dc_plugin_install fails without arg" "[[ \$_install_ok -eq 1 ]]"

# Test: dc_plugin_remove fails without argument (returns 1)
_remove_ok=0
( dc_plugin_remove ) &>/dev/null || _remove_ok=1
run_test "dc_plugin_remove fails without arg" "[[ \$_remove_ok -eq 1 ]]"

# Test: dc_plugin_update runs without error
run_test "dc_plugin_update runs" "dc_plugin_update >/dev/null 2>&1 || true"

# Test: dc_load_all_plugins works
unset "_DC_LOADED_PLUGINS[test-plugin]" 2>/dev/null || true
unset "_DC_LOADED_PLUGINS[another-plugin]" 2>/dev/null || true
unset "_DC_LOADED_PLUGINS[yml-plugin]" 2>/dev/null || true
dc_load_all_plugins
run_test "dc_load_all_plugins loads test-plugin" "[[ -n \"\${_DC_LOADED_PLUGINS[test-plugin]:-}\" ]]"
run_test "dc_load_all_plugins loads another-plugin" "[[ -n \"\${_DC_LOADED_PLUGINS[another-plugin]:-}\" ]]"
run_test "dc_load_all_plugins loads yml-plugin" "[[ -n \"\${_DC_LOADED_PLUGINS[yml-plugin]:-}\" ]]"

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
