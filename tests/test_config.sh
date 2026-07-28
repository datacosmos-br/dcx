#!/usr/bin/env bash
#===============================================================================
# test_config.sh - Tests for lib/config.sh
#===============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Setup
test_setup

# Create test config file
cat > "${TMP_DIR}/test.yaml" << 'EOF'
database:
  host: localhost
  port: 5432
  name: testdb
app:
  name: myapp
  debug: true
EOF

# Create overlay config
cat > "${TMP_DIR}/overlay.yaml" << 'EOF'
database:
  host: production.db
  port: 5433
app:
  debug: false
EOF

# Source config module (core.sh is auto-sourced by test_helpers.sh)
source "${LIB_DIR}/config.sh"

#-------------------------------------------------------------------------------
# Test Groups
#-------------------------------------------------------------------------------

test_module_loading() {
    run_test "config.sh loads" "true"
    run_test "_DCX_CONFIG_LOADED set" "[[ -n \"\${_DCX_CONFIG_LOADED:-}\" ]]"
}

test_core_functions() {
    run_test "config_get exists" "type config_get &>/dev/null"
    run_test "config_set exists" "type config_set &>/dev/null"
    run_test "config_has exists" "type config_has &>/dev/null"
    run_test "config_keys exists" "type config_keys &>/dev/null"
}

test_config_get() {
    result=$(config_get "${TMP_DIR}/test.yaml" "database.host")
    run_test "config_get value" "[[ \"$result\" == \"localhost\" ]]"

    result=$(config_get "${TMP_DIR}/test.yaml" "database.port")
    run_test "config_get nested" "[[ \"$result\" == \"5432\" ]]"
}

test_config_default() {
    result=$(config_get "${TMP_DIR}/test.yaml" "missing.key" "default_value")
    run_test "config_get default" "[[ \"$result\" == \"default_value\" ]]"

    result=$(config_get "/nonexistent/file.yaml" "key" "fallback" || true)
    run_test "config_get missing file" "[[ \"$result\" == \"fallback\" ]]"
}

test_config_has() {
    run_test "config_has existing" "config_has \"${TMP_DIR}/test.yaml\" \"database.host\""
    run_test "config_has missing" "! config_has \"${TMP_DIR}/test.yaml\" \"missing.key\""
}

test_config_set() {
    config_set "${TMP_DIR}/test.yaml" "new.key" "new_value"
    result=$(config_get "${TMP_DIR}/test.yaml" "new.key")
    run_test "config_set new key" "[[ \"$result\" == \"new_value\" ]]"

    config_set "${TMP_DIR}/test.yaml" "database.host" "newhost"
    result=$(config_get "${TMP_DIR}/test.yaml" "database.host")
    run_test "config_set update" "[[ \"$result\" == \"newhost\" ]]"
}

test_config_keys() {
    keys=$(config_keys "${TMP_DIR}/test.yaml" "database")
    run_test "config_keys" "[[ \"$keys\" == *\"host\"* ]]"
}

#-------------------------------------------------------------------------------
# Run Tests
#-------------------------------------------------------------------------------

describe "Module Loading" test_module_loading
describe "Core Functions" test_core_functions
describe "Config Get" test_config_get
describe "Config Default Values" test_config_default
describe "Config Has" test_config_has
describe "Config Set" test_config_set
describe "Config Keys" test_config_keys

test_summary
