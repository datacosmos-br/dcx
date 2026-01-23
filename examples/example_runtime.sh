#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Example: runtime.sh Generic Utilities
#
# This script demonstrates the use of runtime.sh for generic bash utilities.
# It shows logging, error handling, validators, and interactive confirmations.
#
# Usage:
#   ./example_runtime.sh
#   AUTO_YES=1 ./example_runtime.sh   # Skip confirmations
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/runtime.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

#===============================================================================
# EXAMPLE 1: Initialize Logging
#===============================================================================

echo "=== Example 1: Initialize Logging ==="
runtime_init_logs "/tmp/example_runtime_logs" "example_run"
runtime_enable_err_trap
log "Logging initialized. Log file: ${MAIN_LOG}"

#===============================================================================
# EXAMPLE 2: Basic Logging Functions
#===============================================================================

echo
echo "=== Example 2: Basic Logging Functions ==="
log "This is an INFO message"
warn "This is a WARNING message"
# die "This would exit the script" # Commented out to continue demo

#===============================================================================
# EXAMPLE 3: Command Validation
#===============================================================================

echo
echo "=== Example 3: Command Validation ==="
log "Checking required commands..."
require_cmds bash awk sed grep

# This would fail:
# require_cmds nonexistent_command

log "All required commands found!"

#===============================================================================
# EXAMPLE 4: Variable Validators
#===============================================================================

echo
echo "=== Example 4: Variable Validators ==="

# Test various validators
MY_NAME="TestUser"
MY_PATH="/var/log"
MY_FILE="/etc/passwd"
MY_MODE="read"
MY_ENABLED="1"
MY_COUNT="42"
MY_SID="ORCL"

log "Testing validators..."
rt_assert_nonempty "MY_NAME" "${MY_NAME}"
log "  rt_assert_nonempty: PASS"

rt_assert_abs_path "MY_PATH" "${MY_PATH}"
log "  rt_assert_abs_path: PASS"

rt_assert_dir_exists "MY_PATH" "${MY_PATH}"
log "  rt_assert_dir_exists: PASS"

rt_assert_file_exists "MY_FILE" "${MY_FILE}"
log "  rt_assert_file_exists: PASS"

rt_assert_enum "MY_MODE" "${MY_MODE}" "read" "write" "append"
log "  rt_assert_enum: PASS"

rt_assert_bool01 "MY_ENABLED" "${MY_ENABLED}"
log "  rt_assert_bool01: PASS"

rt_assert_uint "MY_COUNT" "${MY_COUNT}"
log "  rt_assert_uint: PASS"

rt_assert_sid_token "MY_SID" "${MY_SID}"
log "  rt_assert_sid_token: PASS"

log "All validators passed!"

#===============================================================================
# EXAMPLE 5: Output Capture
#===============================================================================

echo
echo "=== Example 5: Output Capture ==="

log "Capturing command output..."
result=""
runtime_capture result echo "Hello from captured command"
log "Captured: ${result}"

kernel_version=""
runtime_capture kernel_version uname -r
log "Kernel version: ${kernel_version}"

#===============================================================================
# EXAMPLE 6: Configuration Loading
#===============================================================================

echo
echo "=== Example 6: Configuration Loading ==="

# Create a temporary config file
CONFIG_FILE="/tmp/example_config.conf"
cat > "${CONFIG_FILE}" <<'EOF'
# This is a comment
DB_HOST=localhost
DB_PORT=5432
DB_NAME=mydb
DB_USER="admin"
# Empty lines are ignored

LOG_LEVEL=INFO
EOF

log "Loading config from ${CONFIG_FILE}..."
config_load "${CONFIG_FILE}"
log "  DB_HOST=${DB_HOST}"
log "  DB_PORT=${DB_PORT}"
log "  DB_NAME=${DB_NAME}"
log "  DB_USER=${DB_USER}"
log "  LOG_LEVEL=${LOG_LEVEL}"

# Cleanup
rm -f "${CONFIG_FILE}"

#===============================================================================
# EXAMPLE 7: Lock File Management
#===============================================================================

echo
echo "=== Example 7: Lock File Management ==="

LOCK_FILE="/tmp/example_runtime.lock"
log "Acquiring lock: ${LOCK_FILE}"
runtime_lock_file "${LOCK_FILE}"
log "Lock acquired! PID: $$"

# Lock will be automatically released on exit via trap

#===============================================================================
# EXAMPLE 8: Display Utilities
#===============================================================================

echo
echo "=== Example 8: Display Utilities ==="

runtime_print_section "Application Configuration"

runtime_print_vars "Database Settings" \
  "Host=${DB_HOST:-localhost}" \
  "Port=${DB_PORT:-5432}" \
  "Database=${DB_NAME:-mydb}" \
  "User=${DB_USER:-admin}"

runtime_print_separator
runtime_print_kv "Status" "Running"
runtime_print_kv "Uptime" "$(uptime -p 2>/dev/null || echo 'N/A')"

#===============================================================================
# EXAMPLE 9: File Preview
#===============================================================================

echo
echo "=== Example 9: File Preview ==="

show_file "/etc/hostname" 5

#===============================================================================
# EXAMPLE 10: Retry with Backoff
#===============================================================================

echo
echo "=== Example 10: Retry with Backoff ==="

# Create a command that fails first 2 times, then succeeds
RETRY_COUNTER_FILE="/tmp/retry_counter"
echo "0" > "${RETRY_COUNTER_FILE}"

fake_flaky_command() {
    local count
    count=$(cat "${RETRY_COUNTER_FILE}")
    count=$((count + 1))
    echo "${count}" > "${RETRY_COUNTER_FILE}"

    if [[ ${count} -lt 3 ]]; then
        log "  Attempt ${count}: Simulating failure..."
        return 1
    fi
    log "  Attempt ${count}: Success!"
    return 0
}

log "Testing retry with exponential backoff..."
if runtime_retry 3 1 fake_flaky_command; then
    log "Command succeeded after retries!"
else
    warn "Command failed after all retries"
fi

rm -f "${RETRY_COUNTER_FILE}"

#===============================================================================
# EXAMPLE 11: Filesystem Utilities
#===============================================================================

echo
echo "=== Example 11: Filesystem Utilities ==="

avail_gb=$(runtime_fs_available_gb "/")
used_pct=$(runtime_fs_used_percent "/")

log "Root filesystem: ${avail_gb}GB available, ${used_pct}% used"

#===============================================================================
# EXAMPLE 12: Interactive Confirmations (report.sh)
#===============================================================================

echo
echo "=== Example 12: Interactive Confirmations (via report.sh) ==="
log "Note: These are skipped with REPORT_AUTO_YES=1"

# Simple confirmation
if report_confirm "Continue with the demo?"; then
    log "You confirmed! Continuing..."
fi

# Token-based confirmation (safer for destructive operations)
if report_confirm "Type YES to acknowledge" "YES"; then
    log "Token confirmed!"
fi

# Retype confirmation (for extra safety)
# report_confirm_retype "Retype the database name to confirm deletion" "PRODDB"

#===============================================================================
# EXAMPLE 13: Host Report
#===============================================================================

echo
echo "=== Example 13: Host Report ==="

REPORT_FILE="/tmp/example_host_report.txt"
log "Writing host report to ${REPORT_FILE}..."
runtime_write_host_report "${REPORT_FILE}"

# Cleanup
rm -f "${REPORT_FILE}"

#===============================================================================
# SUMMARY
#===============================================================================

echo
runtime_print_section "Demo Complete"
log "All examples executed successfully!"
log "Log file: ${MAIN_LOG}"
