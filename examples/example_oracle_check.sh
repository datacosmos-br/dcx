#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Example: Oracle Instance State Checking
#
# This script demonstrates oracle.sh utilities for checking Oracle instances.
# Shows how to validate ORACLE_HOME, list instances, and check instance state.
#
# Prerequisites:
#   - ORACLE_HOME set to valid Oracle installation
#   - ORACLE_SID set to instance to check
#
# Usage:
#   ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome19c \
#   ORACLE_SID=ORCL \
#   ./example_oracle_check.sh
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/oracle.sh"

#===============================================================================
# VALIDATE ENVIRONMENT
#===============================================================================

echo "=== Oracle Environment Check ==="
echo

# Check ORACLE_HOME is set
if [[ -z "${ORACLE_HOME:-}" ]]; then
    die "ORACLE_HOME not set. Example: export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome19c"
fi

# Check ORACLE_SID is set
if [[ -z "${ORACLE_SID:-}" ]]; then
    die "ORACLE_SID not set. Example: export ORACLE_SID=ORCL"
fi

log "ORACLE_HOME: ${ORACLE_HOME}"
log "ORACLE_SID:  ${ORACLE_SID}"

#===============================================================================
# VALIDATE ORACLE_HOME
#===============================================================================

echo
echo "=== Validating ORACLE_HOME ==="
oracle_core_validate_home
log "ORACLE_HOME validation: PASSED"

#===============================================================================
# CHECK ORATAB ALIGNMENT
#===============================================================================

echo
echo "=== Checking /etc/oratab ==="
oratab_home="$(oracle_oratab_home_for_sid "${ORACLE_SID}")"
if [[ -n "${oratab_home}" ]]; then
    log "oratab ORACLE_HOME for ${ORACLE_SID}: ${oratab_home}"
    if [[ "${ORACLE_HOME}" == "${oratab_home}" ]]; then
        log "ORACLE_HOME matches oratab: OK"
    else
        warn "ORACLE_HOME mismatch! Using ${ORACLE_HOME} but oratab says ${oratab_home}"
    fi
else
    log "SID ${ORACLE_SID} not found in /etc/oratab (new instance or missing entry)"
fi

#===============================================================================
# LIST ACTIVE INSTANCES
#===============================================================================

echo
echo "=== Active Oracle Instances (ora_pmon_*) ==="
active_sids="$(oracle_instance_list_sids || true)"
if [[ -n "${active_sids}" ]]; then
    echo "${active_sids}" | while read -r sid; do
        echo "  - ${sid}"
    done
else
    echo "  (no active instances detected via pmon)"
fi

#===============================================================================
# CHECK TARGET INSTANCE STATE
#===============================================================================

echo
echo "=== Target Instance State: ${ORACLE_SID} ==="

# Get PMON process SID (case-insensitive match)
pmon_sid="$(oracle_instance_get_pmon)"
if [[ -n "${pmon_sid}" ]]; then
    log "PMON process found: ora_pmon_${pmon_sid}"
else
    log "PMON process NOT found for ${ORACLE_SID}"
fi

# Get overall instance state
state="$(oracle_instance_get_state)"
log "Instance state: ${state}"

case "${state}" in
    DOWN)
        log "Instance is DOWN - not running"
        log "To start: sqlplus / as sysdba; startup;"
        ;;
    UP)
        log "Instance is UP - running and accessible"
        echo
        echo "=== Instance Details ==="
        oracle_sql_sysdba_query "SELECT instance_name, status, database_status FROM v\$instance;"
        ;;
    ZOMBIE)
        warn "Instance is ZOMBIE - PMON exists but cannot connect"
        warn "Possible causes:"
        warn "  - Wrong ORACLE_HOME"
        warn "  - Wrong ORACLE_SID case"
        warn "  - Instance crashed but PMON orphaned"
        warn "  - SGA/memory issues"
        ;;
esac

#===============================================================================
# PMON CHECK HELPER
#===============================================================================

echo
echo "=== PMON Check ==="
if oracle_instance_is_pmon_running; then
    log "PMON for ${ORACLE_SID}: RUNNING"
else
    log "PMON for ${ORACLE_SID}: NOT RUNNING"
fi

#===============================================================================
# SUMMARY
#===============================================================================

echo
echo "=== Summary ==="
runtime_print_vars "Oracle Instance Check" \
    "ORACLE_HOME=${ORACLE_HOME}" \
    "ORACLE_SID=${ORACLE_SID}" \
    "PMON_SID=${pmon_sid:-<none>}" \
    "State=${state}" \
    "oratab_home=${oratab_home:-<not in oratab>}"

log "Check complete!"
