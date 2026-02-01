#!/usr/bin/env bash
#===============================================================================
# test_cred.sh - Tests for lib/cred.sh
#===============================================================================
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

# Setup test environment
test_setup

# Create isolated test directory
TEST_CRED_DIR="${TMP_DIR}/cred_test"
mkdir -p "$TEST_CRED_DIR"

# Override credentials file location for tests
export DCX_HOME="$TEST_CRED_DIR"
export CRED_FILE="$TEST_CRED_DIR/etc/credentials.enc"

# Source credential module
source "${LIB_DIR}/cred.sh"

# Test password for automated tests
TEST_PASSWORD="testpass123"
export DCX_KEYRING_PASSWORD="$TEST_PASSWORD"

#===============================================================================
# Helper Functions
#===============================================================================

# Create a test credentials file without interactive prompts
create_test_cred_file() {
    local password="${1:-$TEST_PASSWORD}"

    mkdir -p "$(dirname "$CRED_FILE")"

    # Generate salt
    local salt
    salt=$(openssl rand -hex 16)

    # Generate recovery key and hash
    local recovery_key recovery_hash
    recovery_key=$(openssl rand -base64 32)
    recovery_hash=$(echo -n "$recovery_key" | openssl dgst -sha256 -binary | openssl base64)

    # Create header
    local created
    created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$CRED_FILE" <<EOF
VERSION:1.0
CREATED:$created
SALT:$salt
RECOVERY_HASH:$recovery_hash
RECOVERY_SHOWN:1
---
EOF

    chmod 600 "$CRED_FILE"
}

# Clean test credentials file
clean_test_cred() {
    rm -f "$CRED_FILE"
    # Reset state
    _CRED_UNLOCKED=0
    _CRED_MASTER_KEY=""
    _CRED_SALT=""
}

#===============================================================================
# Test Groups
#===============================================================================

test_module_loading() {
    run_test "cred.sh loads" "true"
    run_test "_DCX_CRED_LOADED set" "[[ -n \"\${_DCX_CRED_LOADED:-}\" ]]"
}

test_core_functions() {
    run_test "cred_open exists" "type cred_open &>/dev/null"
    run_test "cred_set exists" "type cred_set &>/dev/null"
    run_test "cred_get exists" "type cred_get &>/dev/null"
    run_test "cred_list exists" "type cred_list &>/dev/null"
    run_test "cred_delete exists" "type cred_delete &>/dev/null"
}

test_auto_initialization() {
    clean_test_cred

    # Mock user input for initialization
    # Use a subshell with pre-populated answers
    (
        # Set password via env var to skip prompts
        export DCX_KEYRING_PASSWORD="$TEST_PASSWORD"

        # This should auto-create the file
        # We need to bypass the interactive parts
        # For now, test that cred_set requires the file to exist or creates it

        # Check that file doesn't exist yet
        if [[ -f "$CRED_FILE" ]]; then
            echo "FAIL: File should not exist yet" >&2
            return 1
        fi

        return 0
    )

    run_test "no credentials file initially" "[[ ! -f \"$CRED_FILE\" ]]"

    # For automated tests, we'll create the file manually
    # since interactive init requires user confirmation
    create_test_cred_file

    run_test "credentials file created" "[[ -f \"$CRED_FILE\" ]]"
    run_test "correct permissions" "[[ \$(stat -c %a \"$CRED_FILE\" 2>/dev/null || stat -f %A \"$CRED_FILE\") == \"600\" ]]"
}

test_open() {
    create_test_cred_file

    # Test opening with env var password
    export DCX_KEYRING_PASSWORD="$TEST_PASSWORD"
    run_test "cred_open succeeds" "cred_open"
    run_test "unlocked state set" "[[ \$_CRED_UNLOCKED -eq 1 ]]"

    # Test idempotency (opening again)
    run_test "cred_open idempotent" "cred_open"
}

test_set_and_get() {
    create_test_cred_file
    cred_open &>/dev/null

    # Test storing a credential
    run_test "cred_set stores value" "cred_set 'oracle/prod/password' 'secret123'"

    # Test retrieving it
    local retrieved
    retrieved=$(cred_get 'oracle/prod/password' 2>/dev/null)
    run_test "cred_get retrieves value" "[[ \"$retrieved\" == \"secret123\" ]]"

    # Test storing another credential
    cred_set 'mysql/dev/password' 'devpass' &>/dev/null
    retrieved=$(cred_get 'mysql/dev/password' 2>/dev/null)
    run_test "cred_get multiple values" "[[ \"$retrieved\" == \"devpass\" ]]"

    # Test updating existing credential
    cred_set 'oracle/prod/password' 'newsecret' &>/dev/null
    retrieved=$(cred_get 'oracle/prod/password' 2>/dev/null)
    run_test "cred_set updates existing" "[[ \"$retrieved\" == \"newsecret\" ]]"
}

test_key_format_validation() {
    create_test_cred_file
    cred_open &>/dev/null

    # Valid format
    run_test "valid key format accepted" "cred_set 'service/env/name' 'value'"

    # Invalid formats
    run_test "invalid format rejected (no slashes)" "! cred_set 'invalid' 'value' 2>/dev/null"
    run_test "invalid format rejected (one slash)" "! cred_set 'service/name' 'value' 2>/dev/null"
    run_test "invalid format rejected (too many slashes)" "! cred_set 'a/b/c/d' 'value' 2>/dev/null"
    run_test "invalid format rejected (spaces)" "! cred_set 'service/my env/name' 'value' 2>/dev/null"
}

test_list() {
    create_test_cred_file
    cred_open &>/dev/null

    # Add multiple credentials
    cred_set 'oracle/prod/password' 'secret1' &>/dev/null
    cred_set 'mysql/dev/password' 'secret2' &>/dev/null
    cred_set 'postgres/test/user' 'testuser' &>/dev/null

    # Test listing
    local list
    list=$(cred_list 2>/dev/null)

    run_test "cred_list shows all keys" "[[ \"$list\" == *\"oracle/prod/password\"* ]]"
    run_test "cred_list includes second key" "[[ \"$list\" == *\"mysql/dev/password\"* ]]"
    run_test "cred_list includes third key" "[[ \"$list\" == *\"postgres/test/user\"* ]]"

    # Count lines (should be 3)
    local count
    count=$(echo "$list" | wc -l | tr -d ' ')
    run_test "cred_list returns 3 keys" "[[ $count -eq 3 ]]"
}

test_delete() {
    create_test_cred_file
    cred_open &>/dev/null

    # Add credentials
    cred_set 'oracle/prod/password' 'secret1' &>/dev/null
    cred_set 'mysql/dev/password' 'secret2' &>/dev/null

    # Delete one
    run_test "cred_delete succeeds" "cred_delete 'oracle/prod/password'"

    # Verify it's gone
    run_test "deleted key not found" "! cred_get 'oracle/prod/password' 2>/dev/null"

    # Verify other key still exists
    local retrieved
    retrieved=$(cred_get 'mysql/dev/password' 2>/dev/null)
    run_test "other keys unaffected" "[[ \"$retrieved\" == \"secret2\" ]]"

    # Test deleting non-existent key
    run_test "delete non-existent fails" "! cred_delete 'nonexistent/key/name' 2>/dev/null"
}

test_password_handling() {
    create_test_cred_file

    # Test with env var (already tested above)
    export DCX_KEYRING_PASSWORD="$TEST_PASSWORD"
    run_test "env var password works" "cred_open"

    # Reset state
    _CRED_UNLOCKED=0

    # Test unlocking before operations
    unset DCX_KEYRING_PASSWORD
    _CRED_UNLOCKED=0

    # cred_get should fail when locked (no password available)
    cred_set 'test/test/test' 'value' &>/dev/null || true
    _CRED_UNLOCKED=0

    # Without DCX_KEYRING_PASSWORD, operations should fail
    # (We can't test interactive prompts in automated tests)
    run_test "operations fail when locked" "! cred_get 'test/test/test' 2>/dev/null"

    # Restore env var for cleanup
    export DCX_KEYRING_PASSWORD="$TEST_PASSWORD"
}

test_encryption_roundtrip() {
    create_test_cred_file
    cred_open &>/dev/null

    # Test various special characters and lengths
    local test_values=(
        "simple"
        "with spaces and special: !@#\$%^&*()"
        "multiline
with
newlines"
        "very long password: $(openssl rand -base64 100)"
        ""  # empty string
    )

    local i=0
    for value in "${test_values[@]}"; do
        cred_set "test/test/value$i" "$value" &>/dev/null
        local retrieved
        retrieved=$(cred_get "test/test/value$i" 2>/dev/null)
        run_test "roundtrip test $i" "[[ \"$retrieved\" == \"$value\" ]]"
        i=$((i + 1))
    done
}

test_error_handling() {
    create_test_cred_file
    cred_open &>/dev/null

    # Test missing arguments
    run_test "cred_set requires key" "! cred_set 2>/dev/null"
    run_test "cred_set requires value" "! cred_set 'key' 2>/dev/null"
    run_test "cred_get requires key" "! cred_get 2>/dev/null"

    # Test getting non-existent key
    run_test "cred_get nonexistent fails" "! cred_get 'nonexistent/key/name' 2>/dev/null"

    # Test operating on missing file
    clean_test_cred
    run_test "cred_list fails without file" "! cred_list 2>/dev/null"
    run_test "cred_delete fails without file" "! cred_delete 'key/key/key' 2>/dev/null"
}

test_migration() {
    create_test_cred_file
    cred_open &>/dev/null

    # Set up plain-text credentials in environment
    export DB_ADMIN_PASSWORD="admin_secret"
    export SOURCE_DB_PASSWORD="source_secret"

    # Test that migration detects environment variables
    # We can't fully test interactive prompts, but we can verify the function exists
    run_test "cred_migrate exists" "type cred_migrate &>/dev/null"

    # Test detection by checking if function outputs mention of found credentials
    local migration_output
    migration_output=$(echo "n\nn" | cred_migrate 2>&1)

    run_test "migration detects DB_ADMIN_PASSWORD" "[[ \"$migration_output\" == *\"DB_ADMIN_PASSWORD\"* ]]"
    run_test "migration detects SOURCE_DB_PASSWORD" "[[ \"$migration_output\" == *\"SOURCE_DB_PASSWORD\"* ]]"

    # Test migration with 'yes' response (automated)
    clean_test_cred
    create_test_cred_file
    cred_open &>/dev/null

    # Migrate one credential with 'yes' response
    migration_output=$(echo "y" | cred_migrate 2>&1)

    run_test "migration shows migrated count" "[[ \"$migration_output\" == *\"Migrated:\"* ]]"
    run_test "migration suggests unset commands" "[[ \"$migration_output\" == *\"unset\"* ]]"

    # Cleanup env vars
    unset DB_ADMIN_PASSWORD SOURCE_DB_PASSWORD
}

test_export() {
    create_test_cred_file
    cred_open &>/dev/null

    # Set up test credentials
    cred_set 'oracle/prod/password' 'prod_secret' &>/dev/null
    cred_set 'oracle/prod/username' 'prod_user' &>/dev/null
    cred_set 'mysql/dev/password' 'dev_secret' &>/dev/null

    # Test export function exists
    run_test "cred_export exists" "type cred_export &>/dev/null"

    # Test export with prefix filter
    local export_output
    export_output=$(cred_export oracle/prod 2>/dev/null)

    run_test "export outputs valid format" "[[ \"$export_output\" == *\"export \"* ]]"
    run_test "export transforms key correctly" "[[ \"$export_output\" == *\"ORACLE_PROD_PASSWORD\"* ]]"
    run_test "export includes username" "[[ \"$export_output\" == *\"ORACLE_PROD_USERNAME\"* ]]"
    run_test "export excludes other services" "[[ \"$export_output\" != *\"MYSQL\"* ]]"

    # Test key transformation
    run_test "export uppercase transformation" "[[ \"$export_output\" =~ ORACLE_PROD_[A-Z]+ ]]"
    run_test "export slash to underscore" "[[ \"$export_output\" =~ export\ [A-Z_]+=.* ]]"

    # Test export is eval-safe
    eval "$export_output"
    run_test "exported var is set" "[[ -n \"\${ORACLE_PROD_PASSWORD:-}\" ]]"
    run_test "exported value correct" "[[ \"\$ORACLE_PROD_PASSWORD\" == \"prod_secret\" ]]"

    # Cleanup exported vars
    unset ORACLE_PROD_PASSWORD ORACLE_PROD_USERNAME

    # Test export without prefix (all credentials)
    export_output=$(cred_export 2>/dev/null)
    run_test "export all includes oracle" "[[ \"$export_output\" == *\"ORACLE_PROD_PASSWORD\"* ]]"
    run_test "export all includes mysql" "[[ \"$export_output\" == *\"MYSQL_DEV_PASSWORD\"* ]]"
}

#===============================================================================
# Run Tests
#===============================================================================

describe "Module Loading" test_module_loading
describe "Core Functions" test_core_functions
describe "Auto-Initialization" test_auto_initialization
describe "Open and Unlock" test_open
describe "Set and Get" test_set_and_get
describe "Key Format Validation" test_key_format_validation
describe "List Credentials" test_list
describe "Delete Credentials" test_delete
describe "Password Handling" test_password_handling
describe "Encryption Roundtrip" test_encryption_roundtrip
describe "Error Handling" test_error_handling
describe "Migration" test_migration
describe "Export" test_export

# Cleanup
clean_test_cred

test_summary
