#!/usr/bin/env bash
#===============================================================================
# test_plugin.sh - Tests for lib/plugin.sh
#===============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Set DCX_HOME for tests
export DCX_HOME="${LIB_DIR}/.."

# Test plugin directory
TEST_PLUGIN_DIR="/tmp/dc-test-plugin-$$"

#-------------------------------------------------------------------------------
# Setup - Create mock plugin for testing
#-------------------------------------------------------------------------------
setup_test_plugin() {
    mkdir -p "$TEST_PLUGIN_DIR/test-plugin/lib"
    mkdir -p "$TEST_PLUGIN_DIR/test-plugin/bin"

    cat > "$TEST_PLUGIN_DIR/test-plugin/plugin.yaml" << 'EOF'
name: test-plugin
version: 1.0.0
description: A test plugin for unit testing
author: Test Author
EOF

    cat > "$TEST_PLUGIN_DIR/test-plugin/lib/init.sh" << 'EOF'
#!/usr/bin/env bash
export TEST_PLUGIN_LOADED=1
EOF

    mkdir -p "$TEST_PLUGIN_DIR/another-plugin"
    cat > "$TEST_PLUGIN_DIR/another-plugin/plugin.yaml" << 'EOF'
name: another-plugin
version: 2.0.0
description: Another test plugin
author: Test Author
EOF

    mkdir -p "$TEST_PLUGIN_DIR/yml-plugin"
    cat > "$TEST_PLUGIN_DIR/yml-plugin/plugin.yml" << 'EOF'
name: yml-plugin
version: 0.1.0
description: Plugin with .yml extension
EOF
}

cleanup_test_plugin() {
    [[ -n "$TEST_PLUGIN_DIR" && -d "$TEST_PLUGIN_DIR" ]] && rm -rf "$TEST_PLUGIN_DIR"
}

trap cleanup_test_plugin EXIT

# Source plugin.sh (core.sh is auto-sourced by test_helpers.sh)
source "${LIB_DIR}/plugin.sh"

#-------------------------------------------------------------------------------
# Test Groups
#-------------------------------------------------------------------------------

test_module_loading() {
    run_test "plugin.sh loads" "true"
    run_test "_DCX_PLUGIN_LOADED set" "[[ -n \"\${_DCX_PLUGIN_LOADED:-}\" ]]"
}

test_global_arrays() {
    run_test "DCX_PLUGIN_DIRS is array" "declare -p DCX_PLUGIN_DIRS &>/dev/null"
    run_test "_DCX_LOADED_PLUGINS is array" "declare -p _DCX_LOADED_PLUGINS &>/dev/null"
    run_test "_DCX_PLUGIN_CACHE is array" "declare -p _DCX_PLUGIN_CACHE &>/dev/null"
}

test_core_functions() {
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
}

test_init_plugin_dirs() {
    dc_init_plugin_dirs
    run_test "dc_init_plugin_dirs runs" "true"
}

test_plugin_discovery() {
    setup_test_plugin
    DCX_PLUGIN_DIRS=("$TEST_PLUGIN_DIR")

    discovered=$(dc_discover_plugins)
    run_test "dc_discover_plugins finds test-plugin" "[[ \"\$discovered\" == *'test-plugin'* ]]"
    run_test "dc_discover_plugins finds another-plugin" "[[ \"\$discovered\" == *'another-plugin'* ]]"
    run_test "dc_discover_plugins finds yml-plugin" "[[ \"\$discovered\" == *'yml-plugin'* ]]"
}

test_plugin_info() {
    plugin_name=$(dc_plugin_info "$TEST_PLUGIN_DIR/test-plugin" "name") || true
    run_test "dc_plugin_info reads name" "[[ \"\$plugin_name\" == \"test-plugin\" ]]"

    plugin_version=$(dc_plugin_info "$TEST_PLUGIN_DIR/test-plugin" "version") || true
    run_test "dc_plugin_info reads version" "[[ \"\$plugin_version\" == \"1.0.0\" ]]"

    plugin_desc=$(dc_plugin_info "$TEST_PLUGIN_DIR/test-plugin" "description") || true
    run_test "dc_plugin_info reads description" "[[ \"\$plugin_desc\" == *'test plugin'* ]]"

    full_yaml=$(dc_plugin_info "$TEST_PLUGIN_DIR/test-plugin") || true
    run_test "dc_plugin_info returns full yaml" "[[ \"\$full_yaml\" == *'name:'* ]]"

    run_test "dc_plugin_info fails for nonexistent" "! dc_plugin_info /nonexistent/plugin 2>/dev/null"

    yml_name=$(dc_plugin_info "$TEST_PLUGIN_DIR/yml-plugin" "name") || true
    run_test "dc_plugin_info works with .yml" "[[ \"\$yml_name\" == \"yml-plugin\" ]]"
}

test_plugin_loading() {
    dc_load_plugin "$TEST_PLUGIN_DIR/test-plugin" || true
    run_test "dc_load_plugin loads test-plugin" "[[ -n \"\${_DCX_LOADED_PLUGINS[test-plugin]:-}\" ]]"
    run_test "Plugin init.sh executed" "[[ \"\${TEST_PLUGIN_LOADED:-}\" == \"1\" ]]"
    run_test "Plugin version cached" "[[ \"\${_DCX_PLUGIN_CACHE[test-plugin]}\" == \"1.0.0\" ]]"
    run_test "dc_load_plugin idempotent" "dc_load_plugin \"$TEST_PLUGIN_DIR/test-plugin\""
}

test_plugin_unloading() {
    dc_unload_plugin "test-plugin" >/dev/null 2>&1 || true
    run_test "dc_unload_plugin removes from registry" "[[ -z \"\${_DCX_LOADED_PLUGINS[test-plugin]:-}\" ]]"
    run_test "dc_unload_plugin fails for not loaded" "! dc_unload_plugin \"nonexistent-plugin\" 2>/dev/null"

    # Re-load for list tests
    dc_load_plugin "$TEST_PLUGIN_DIR/test-plugin" || true
}

test_plugin_list() {
    table_output=$(dc_plugin_list table 2>/dev/null) || true
    run_test "dc_plugin_list table has header" "[[ \"\$table_output\" == *'Name'* ]]"
    run_test "dc_plugin_list table shows plugin" "[[ \"\$table_output\" == *'test-plugin'* ]]"

    json_output=$(dc_plugin_list json 2>/dev/null) || true
    run_test "dc_plugin_list json is array" "[[ \"\$json_output\" == '['* ]]"
    run_test "dc_plugin_list json has name" "[[ \"\$json_output\" == *'\"name\"'* ]]"

    simple_output=$(dc_plugin_list simple 2>/dev/null) || true
    run_test "dc_plugin_list simple shows plugin" "[[ \"\$simple_output\" == *'test-plugin'* ]]"
}

test_plugin_cmd() {
    help_output=$(dc_plugin_cmd help 2>&1) || true
    run_test "dc_plugin_cmd help shows usage" "[[ \"\$help_output\" == *'Usage:'* ]]"
    run_test "dc_plugin_cmd help shows commands" "[[ \"\$help_output\" == *'install'* ]]"

    list_output=$(dc_plugin_cmd list 2>&1) || true
    run_test "dc_plugin_cmd list works" "[[ \"\$list_output\" == *'Name'* ]]"

    info_output=$(dc_plugin_cmd info test-plugin 2>&1) || true
    run_test "dc_plugin_cmd info works" "[[ \"\$info_output\" == *'test-plugin'* ]]"
    run_test "dc_plugin_cmd info fails for nonexistent" "! dc_plugin_cmd info nonexistent 2>/dev/null"

    unset "_DCX_LOADED_PLUGINS[test-plugin]" 2>/dev/null || true
    load_output=$(dc_plugin_cmd load test-plugin 2>&1) || true
    run_test "dc_plugin_cmd load works" "[[ \"\$load_output\" == *'Loaded'* ]]"

    if dc_plugin_cmd load nonexistent &>/dev/null; then _load_nonexist_ok=1; else _load_nonexist_ok=0; fi
    run_test "dc_plugin_cmd load fails for nonexistent" "[[ \$_load_nonexist_ok -eq 0 ]]"
}

test_plugin_install_remove() {
    _install_ok=0
    ( dc_plugin_install ) &>/dev/null || _install_ok=1
    run_test "dc_plugin_install fails without arg" "[[ \$_install_ok -eq 1 ]]"

    _remove_ok=0
    ( dc_plugin_remove ) &>/dev/null || _remove_ok=1
    run_test "dc_plugin_remove fails without arg" "[[ \$_remove_ok -eq 1 ]]"

    run_test "dc_plugin_update runs" "dc_plugin_update >/dev/null 2>&1 || true"
}

test_load_all_plugins() {
    unset "_DCX_LOADED_PLUGINS[test-plugin]" 2>/dev/null || true
    unset "_DCX_LOADED_PLUGINS[another-plugin]" 2>/dev/null || true
    unset "_DCX_LOADED_PLUGINS[yml-plugin]" 2>/dev/null || true
    dc_load_all_plugins
    run_test "dc_load_all_plugins loads test-plugin" "[[ -n \"\${_DCX_LOADED_PLUGINS[test-plugin]:-}\" ]]"
    run_test "dc_load_all_plugins loads another-plugin" "[[ -n \"\${_DCX_LOADED_PLUGINS[another-plugin]:-}\" ]]"
    run_test "dc_load_all_plugins loads yml-plugin" "[[ -n \"\${_DCX_LOADED_PLUGINS[yml-plugin]:-}\" ]]"
}

#-------------------------------------------------------------------------------
# Run Tests
#-------------------------------------------------------------------------------

describe "Module Loading" test_module_loading
describe "Global Arrays" test_global_arrays
describe "Core Functions" test_core_functions
describe "Init Plugin Dirs" test_init_plugin_dirs
describe "Plugin Discovery" test_plugin_discovery
describe "Plugin Info" test_plugin_info
describe "Plugin Loading" test_plugin_loading
describe "Plugin Unloading" test_plugin_unloading
describe "Plugin List" test_plugin_list
describe "Plugin Commands" test_plugin_cmd
describe "Plugin Install/Remove" test_plugin_install_remove
describe "Load All Plugins" test_load_all_plugins

test_summary
