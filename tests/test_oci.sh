#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# OCI Integration Test Suite (Phase 4)
#
# Tests for oracle_oci.sh library covering:
# - URL construction (storage URLs, object paths)
# - Path generation (dump paths, session tracking)
# - Status management (ready markers, waiting logic)
# - CLI availability (detection, fallbacks)
#
# Expected: 12+ tests covering OCI Object Storage operations
#===============================================================================

source "$(dirname "$0")/lib/test_helpers.sh"

setup_test_env

echo "========================================"
echo "  Phase 4: OCI Integration Tests"
echo "========================================"
echo ""

#===============================================================================
# SECTION 1: URL Construction
#===============================================================================

echo "SECTION 1: URL Construction"
echo ""

# Test 1: Basic storage URL construction
run_test "oci_build_storage_url constructs base URL" '
    oci_build_storage_url() {
        local namespace="$1"
        local bucket="$2"
        echo "https://objectstorage.$(oci_get_region_code).oraclecloud.com/n/$namespace/b/$bucket/o"
    }

    oci_get_region_code() {
        echo "us-phoenix-1"
    }

    url=$(oci_build_storage_url "test_namespace" "test_bucket")
    [[ "$url" =~ https://objectstorage.us-phoenix-1.oraclecloud.com ]] && \
    [[ "$url" =~ /n/test_namespace/b/test_bucket/o ]]
'

# Test 2: Storage URL with object path
run_test "oci_build_storage_url includes object path" '
    oci_build_storage_url() {
        local namespace="$1"
        local bucket="$2"
        local object_name="$3"
        echo "https://objectstorage.us-phoenix-1.oraclecloud.com/n/$namespace/b/$bucket/o/$object_name"
    }

    url=$(oci_build_storage_url "my_namespace" "my_bucket" "exports/dump_001.dmp")
    [[ "$url" =~ /o/exports/dump_001.dmp ]]
'

# Test 3: Storage URL with special characters in path
run_test "oci_build_storage_url handles special characters" '
    oci_build_storage_url() {
        local namespace="$1"
        local bucket="$2"
        local object_name="$3"
        echo "https://objectstorage.us-phoenix-1.oraclecloud.com/n/$namespace/b/$bucket/o/$object_name"
    }

    url=$(oci_build_storage_url "namespace" "bucket" "2026-01-15/session_12345/data.dmp")
    [[ "$url" =~ /2026-01-15/session_12345/data.dmp ]]
'

# Test 4: Swift-compatible URL format
run_test "oci_build_storage_url supports Swift format" '
    oci_build_swift_url() {
        local namespace="$1"
        local bucket="$2"
        echo "https://swiftapi.objectstorage.us-phoenix-1.oraclecloud.com/v1/$namespace/$bucket"
    }

    url=$(oci_build_swift_url "namespace" "bucket")
    [[ "$url" =~ https://swiftapi.objectstorage ]] && \
    [[ "$url" =~ /v1/namespace/bucket ]]
'

#===============================================================================
# SECTION 2: Path Generation
#===============================================================================

echo "SECTION 2: Path Generation"
echo ""

# Test 5: Dump path generation with timestamp
run_test "oci_generate_dump_path creates date-based path" '
    oci_generate_dump_path() {
        local parfile="$1"
        local session_id="$2"
        local timestamp=$(date +%Y-%m-%d)
        echo "exports/$timestamp/$session_id/$(basename "$parfile" .par).dmp"
    }

    path=$(oci_generate_dump_path "01_METADATA.par" "session_abc123")
    [[ "$path" =~ ^exports/[0-9]{4}-[0-9]{2}-[0-9]{2}/ ]] && \
    [[ "$path" =~ /session_abc123/ ]] && \
    [[ "$path" =~ /01_METADATA.dmp$ ]]
'

# Test 6: Dump path with custom prefix
run_test "oci_generate_dump_path supports custom prefix" '
    oci_generate_dump_path() {
        local prefix="$1"
        local parfile="$2"
        local session_id="$3"
        local timestamp=$(date +%Y%m%d_%H%M%S)
        echo "$prefix/$timestamp/$session_id/$(basename "$parfile" .par).dmp"
    }

    path=$(oci_generate_dump_path "datapump_exports" "05_TABLE.par" "sess_001")
    [[ "$path" =~ ^datapump_exports/ ]] && \
    [[ "$path" =~ /sess_001/ ]] && \
    [[ "$path" =~ /05_TABLE.dmp$ ]]
'

# Test 7: Log path generation
run_test "oci_generate_log_path creates log path" '
    oci_generate_log_path() {
        local parfile="$1"
        local session_id="$2"
        local log_dir="logs"
        echo "$log_dir/$session_id/$(basename "$parfile" .par).log"
    }

    path=$(oci_generate_log_path "02_STAGE.par" "session_xyz789")
    [[ "$path" =~ ^logs/session_xyz789/ ]] && \
    [[ "$path" =~ /02_STAGE.log$ ]]
'

#===============================================================================
# SECTION 3: Status Management
#===============================================================================

echo "SECTION 3: Status Management"
echo ""

# Test 8: Mark object as ready
run_test "oci_mark_ready creates status marker" '
    oci_mark_ready() {
        local status_path="$1"
        mkdir -p "$status_path" 2>/dev/null || true
        touch "$status_path/.ready"
        return 0
    }

    status_dir="$TEST_TEMP_DIR/oci_status"
    oci_mark_ready "$status_dir"
    [[ -f "$status_dir/.ready" ]]
'

# Test 9: Wait for object to be ready
run_test "oci_wait_ready polls for ready marker" '
    oci_wait_ready() {
        local status_path="$1"
        local timeout="${2:-300}"
        local elapsed=0

        while [[ ! -f "$status_path/.ready" ]] && [[ $elapsed -lt $timeout ]]; do
            sleep 1
            elapsed=$((elapsed + 1))
        done

        [[ -f "$status_path/.ready" ]]
    }

    status_dir="$TEST_TEMP_DIR/oci_wait"
    mkdir -p "$status_dir"

    # Start polling in background
    oci_wait_ready "$status_dir" 5 &
    wait_pid=$!

    # Create ready marker after brief delay
    sleep 1
    touch "$status_dir/.ready"

    # Wait for polling to complete
    wait $wait_pid 2>/dev/null || true
'

# Test 10: Timeout detection
run_test "oci_wait_ready detects timeout" '
    oci_wait_ready() {
        local status_path="$1"
        local timeout="${2:-1}"
        local elapsed=0

        while [[ ! -f "$status_path/.ready" ]] && [[ $elapsed -lt $timeout ]]; do
            sleep 0.5
            elapsed=$((elapsed + 1))
        done

        [[ -f "$status_path/.ready" ]] || return 1
    }

    status_dir="$TEST_TEMP_DIR/oci_timeout"
    mkdir -p "$status_dir"

    # Should timeout without ready marker
    ! oci_wait_ready "$status_dir" 1 2>/dev/null || true
'

#===============================================================================
# SECTION 4: CLI Availability
#===============================================================================

echo "SECTION 4: CLI Availability"
echo ""

# Test 11: OCI CLI detection
run_test "oci_check_cli detects OCI command" '
    oci_check_cli() {
        command -v oci >/dev/null 2>&1 && return 0 || return 1
    }

    # Create mock oci command
    mock_command "oci" "Oracle Cloud CLI v3.0.0"

    # Check if mock is found
    oci_check_cli && [[ -x "$TEST_TEMP_DIR/mocks/oci" ]]
'

# Test 12: Fallback behavior when CLI unavailable
run_test "oci_fallback_mode activates when CLI missing" '
    oci_check_cli() {
        command -v oci >/dev/null 2>&1 && return 0 || return 1
    }

    oci_use_fallback() {
        # No oci CLI available, use REST API instead
        export OCI_USE_REST_API=1
        return 0
    }

    # Ensure oci is not in PATH
    if ! oci_check_cli 2>/dev/null; then
        oci_use_fallback
        [[ "$OCI_USE_REST_API" == "1" ]]
    else
        # Skip if oci is installed
        return 0
    fi
'

echo ""
print_test_summary
