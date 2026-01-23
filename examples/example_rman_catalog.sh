#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Example: RMAN Backup Cataloging
#
# This script demonstrates oracle.sh utilities for RMAN operations.
# Shows backup discovery, DBID detection, and RMAN command file generation.
#
# NOTE: This is a DRY-RUN example - it does NOT execute RMAN commands.
#       It generates command files for inspection.
#
# Prerequisites:
#   - ORACLE_HOME set
#   - BACKUP_ROOT pointing to RMAN backup directory
#
# Usage:
#   ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome19c \
#   BACKUP_ROOT=/backup-prod/rman \
#   ./example_rman_catalog.sh
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/oracle.sh"

#===============================================================================
# CONFIGURATION
#===============================================================================

BACKUP_ROOT="${BACKUP_ROOT:-/backup-prod/rman}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/example_rman}"
RMAN_CHANNELS="${RMAN_CHANNELS:-4}"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

log "=== RMAN Cataloging Example (DRY RUN) ==="
log "BACKUP_ROOT: ${BACKUP_ROOT}"
log "OUTPUT_DIR:  ${OUTPUT_DIR}"
log "RMAN_CHANNELS: ${RMAN_CHANNELS}"

#===============================================================================
# BACKUP DISCOVERY
#===============================================================================

echo
echo "=== Step 1: Backup Discovery ==="

# Initialize variables that oracle_rman_backup_discover will set
BKPFULL=""
BKPARCH=""
AUTO=""
DBID="${DBID:-}"

if ! oracle_rman_backup_discover "${BACKUP_ROOT}"; then
    rc=$?
    case ${rc} in
        1) die "Backup not found in ${BACKUP_ROOT}" ;;
        2) die "Multiple DBIDs found - set DBID explicitly" ;;
        *) die "Backup discovery failed (rc=${rc})" ;;
    esac
fi

log "Discovered backup paths:"
log "  BKPFULL: ${BKPFULL}"
log "  BKPARCH: ${BKPARCH:-<none>}"
log "  AUTO:    ${AUTO}"

#===============================================================================
# DBID DETECTION
#===============================================================================

echo
echo "=== Step 2: DBID Detection ==="

if [[ -z "${DBID}" ]]; then
    detected_dbid="$(oracle_rman_detect_dbid "${AUTO}")"
    rc=$?
    case ${rc} in
        0) DBID="${detected_dbid}"; log "Auto-detected DBID: ${DBID}" ;;
        1) die "No DBID found in autobackup files" ;;
        2) die "Multiple DBIDs found - set DBID explicitly" ;;
    esac
else
    log "Using specified DBID: ${DBID}"
fi

#===============================================================================
# GENERATE RMAN CHANNEL ALLOCATION
#===============================================================================

echo
echo "=== Step 3: RMAN Channel Configuration ==="
log "Generating channel allocation for ${RMAN_CHANNELS} channels..."

oracle_rman_auto_channels  # Ensure RMAN_CHANNELS is set

alloc_cmds="$(oracle_rman_channels_alloc)"
release_cmds="$(oracle_rman_channels_release)"

echo "Channel allocation:"
echo "${alloc_cmds}" | sed 's/^/  /'
echo
echo "Channel release:"
echo "${release_cmds}" | sed 's/^/  /'

#===============================================================================
# GENERATE RMAN COMMAND FILES
#===============================================================================

echo
echo "=== Step 4: Generate RMAN Command Files ==="

# Catalog command
CATALOG_RCV="${OUTPUT_DIR}/catalog.rcv"
oracle_rman_write_cmdfile_run "${CATALOG_RCV}" "${DBID}" "list backup summary;" <<EOF
  catalog start with '${BKPFULL}/' noprompt;
EOF

log "Generated: ${CATALOG_RCV}"
echo "--- Content ---"
cat "${CATALOG_RCV}" | sed 's/^/  /'
echo "---------------"

# Preview command (without newname since we don't have a discovery map)
PREVIEW_RCV="${OUTPUT_DIR}/preview.rcv"
oracle_rman_write_cmdfile_run "${PREVIEW_RCV}" "${DBID}" "" <<EOF
  restore database preview summary;
EOF

log "Generated: ${PREVIEW_RCV}"
echo "--- Content ---"
cat "${PREVIEW_RCV}" | sed 's/^/  /'
echo "---------------"

# Validate command
VALIDATE_RCV="${OUTPUT_DIR}/validate.rcv"
oracle_rman_write_cmdfile_run "${VALIDATE_RCV}" "${DBID}" "" <<EOF
  restore database validate;
EOF

log "Generated: ${VALIDATE_RCV}"
echo "--- Content ---"
cat "${VALIDATE_RCV}" | sed 's/^/  /'
echo "---------------"

#===============================================================================
# SIMPLE COMMAND FILE (No RUN block)
#===============================================================================

echo
echo "=== Step 5: Simple RMAN Command (no RUN block) ==="

REPORT_RCV="${OUTPUT_DIR}/report.rcv"
oracle_rman_write_cmdfile_simple "${REPORT_RCV}" <<'EOF'
# RMAN status and reporting commands
show all;
list incarnation;
report schema;
report need backup;
list backup summary;
list archivelog all;
EOF

log "Generated: ${REPORT_RCV}"
echo "--- Content ---"
cat "${REPORT_RCV}" | sed 's/^/  /'
echo "---------------"

#===============================================================================
# HOW TO EXECUTE (NOT DONE HERE)
#===============================================================================

echo
echo "=== How to Execute (NOT DONE IN THIS EXAMPLE) ==="
echo
echo "To execute these commands, you would need:"
echo "  1. Instance started (startup nomount or mount)"
echo "  2. Proper ORACLE_SID and ORACLE_HOME"
echo
echo "Example execution:"
echo "  rman target / cmdfile='${CATALOG_RCV}' log='/tmp/catalog.log'"
echo
echo "Or using oracle.sh function:"
echo "  oracle_rman_exec_verbose '${CATALOG_RCV}' '/tmp/catalog.log'"

#===============================================================================
# SUMMARY
#===============================================================================

echo
echo "=== Generated Files ==="
ls -la "${OUTPUT_DIR}"/*.rcv

runtime_print_vars "RMAN Configuration Summary" \
    "BACKUP_ROOT=${BACKUP_ROOT}" \
    "BKPFULL=${BKPFULL}" \
    "BKPARCH=${BKPARCH:-<none>}" \
    "AUTO=${AUTO}" \
    "DBID=${DBID}" \
    "RMAN_CHANNELS=${RMAN_CHANNELS}" \
    "OUTPUT_DIR=${OUTPUT_DIR}"

log "Example complete! Review generated files in ${OUTPUT_DIR}"
