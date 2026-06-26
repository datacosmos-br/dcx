#!/bin/bash
#
# monitor_restore.sh - Monitor RMAN restore progress
#
# Usage: monitor_restore.sh SID [INTERVAL_SECONDS]
#
# Arguments:
#   SID              - Oracle SID to connect to
#   INTERVAL_SECONDS - Optional. If provided, loops with this interval.
#                      If not provided, runs once and exits.
#
# Examples:
#   ./monitor_restore.sh RES          # Run once
#   ./monitor_restore.sh RES 30       # Loop every 30 seconds
#

set -e

# Validate arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 SID [INTERVAL_SECONDS]"
    echo ""
    echo "Arguments:"
    echo "  SID              - Oracle SID to connect to"
    echo "  INTERVAL_SECONDS - Optional. Loop interval in seconds."
    echo ""
    echo "Examples:"
    echo "  $0 RES           # Run once"
    echo "  $0 RES 30        # Loop every 30 seconds"
    exit 1
fi

SID="$1"
INTERVAL="${2:-0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="${SCRIPT_DIR}/monitor_restore.sql"

# Validate SQL file exists
if [[ ! -f "${SQL_FILE}" ]]; then
    echo "ERROR: SQL file not found: ${SQL_FILE}"
    exit 1
fi

# Set Oracle environment
export ORACLE_SID="${SID}"

# Find ORACLE_HOME if not set
if [[ -z "${ORACLE_HOME}" ]]; then
    if [[ -f /etc/oratab ]]; then
        ORACLE_HOME=$(grep "^${SID}:" /etc/oratab | cut -d: -f2)
        export ORACLE_HOME
    fi
fi

if [[ -z "${ORACLE_HOME}" ]]; then
    echo "ERROR: ORACLE_HOME not set and not found in /etc/oratab for SID=${SID}"
    exit 1
fi

export PATH="${ORACLE_HOME}/bin:${PATH}"

# Function to run the monitor
run_monitor() {
    sqlplus -S / as sysdba @"${SQL_FILE}"
}

# Main execution
if [[ "${INTERVAL}" -eq 0 ]]; then
    # Run once
    run_monitor
else
    # Loop mode
    echo "Monitoring RMAN restore for SID=${SID} every ${INTERVAL}s (Ctrl+C to stop)"
    echo ""

    trap 'echo ""; echo "Monitoring stopped."; exit 0' INT TERM

    while true; do
        run_monitor
        echo ""
        echo "--- Next refresh in ${INTERVAL}s (Ctrl+C to stop) ---"
        sleep "${INTERVAL}"
    done
fi
