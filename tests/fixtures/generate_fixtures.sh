#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Generate Oracle XE Test Fixtures
#
# Captures real outputs from Oracle XE for use in unit tests.
# Requires SYSDBA access (user in dba group, ORACLE_HOME/ORACLE_SID set).
#
# Usage:
#   ./generate_fixtures.sh [--force]
#
# Options:
#   --force    Overwrite existing fixtures without prompting
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/oracle_xe"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#===============================================================================
# Environment Setup
#===============================================================================

setup_oracle_env() {
    # Set Oracle environment if not already set
    if [[ -z "${ORACLE_HOME:-}" ]] || [[ ! -d "${ORACLE_HOME:-}" ]]; then
        export ORACLE_HOME=/usr/lib/oracle/product/11.2.0/xe
    fi
    if [[ -z "${ORACLE_SID:-}" ]]; then
        export ORACLE_SID=XE
    fi
    export PATH="${ORACLE_HOME}/bin:${PATH}"
    export LD_LIBRARY_PATH="${ORACLE_HOME}/lib:${LD_LIBRARY_PATH:-}"
    export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
}

#===============================================================================
# Validation
#===============================================================================

validate_oracle_access() {
    log_info "Validating Oracle access..."

    if [[ ! -x "${ORACLE_HOME}/bin/sqlplus" ]]; then
        log_error "sqlplus not found at ${ORACLE_HOME}/bin/sqlplus"
        return 1
    fi

    # Test SYSDBA connection
    local result
    result=$("${ORACLE_HOME}/bin/sqlplus" -S / as sysdba <<'SQL' 2>&1
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT 'CONNECTED' FROM DUAL;
EXIT;
SQL
)

    if echo "${result}" | grep -q "CONNECTED"; then
        log_info "SYSDBA connection successful"
        return 0
    else
        log_error "Cannot connect as SYSDBA: ${result}"
        return 1
    fi
}

#===============================================================================
# Fixture Generation Functions
#===============================================================================

generate_v_instance() {
    log_info "Generating v_instance.txt..."
    "${ORACLE_HOME}/bin/sqlplus" -S / as sysdba <<'SQL' > "${FIXTURES_DIR}/v_instance.txt"
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 500 TRIMSPOOL ON TAB OFF
SELECT INSTANCE_NUMBER||'|'||INSTANCE_NAME||'|'||HOST_NAME||'|'||VERSION||'|'||STATUS||'|'||DATABASE_STATUS
FROM V$INSTANCE;
EXIT;
SQL
}

generate_v_database() {
    log_info "Generating v_database.txt..."
    "${ORACLE_HOME}/bin/sqlplus" -S / as sysdba <<'SQL' > "${FIXTURES_DIR}/v_database.txt"
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 500 TRIMSPOOL ON TAB OFF
SELECT DBID||'|'||NAME||'|'||CREATED||'|'||LOG_MODE||'|'||OPEN_MODE||'|'||DATABASE_ROLE
FROM V$DATABASE;
EXIT;
SQL
}

generate_v_datafile() {
    log_info "Generating v_datafile.txt..."
    "${ORACLE_HOME}/bin/sqlplus" -S / as sysdba <<'SQL' > "${FIXTURES_DIR}/v_datafile.txt"
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 500 TRIMSPOOL ON TAB OFF
SELECT FILE#||'|'||NAME||'|'||STATUS||'|'||BYTES
FROM V$DATAFILE
ORDER BY FILE#;
EXIT;
SQL
}

generate_v_tempfile() {
    log_info "Generating v_tempfile.txt..."
    "${ORACLE_HOME}/bin/sqlplus" -S / as sysdba <<'SQL' > "${FIXTURES_DIR}/v_tempfile.txt"
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 500 TRIMSPOOL ON TAB OFF
SELECT FILE#||'|'||NAME||'|'||STATUS||'|'||BYTES
FROM V$TEMPFILE
ORDER BY FILE#;
EXIT;
SQL
}

generate_v_logfile() {
    log_info "Generating v_logfile.txt..."
    "${ORACLE_HOME}/bin/sqlplus" -S / as sysdba <<'SQL' > "${FIXTURES_DIR}/v_logfile.txt"
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 500 TRIMSPOOL ON TAB OFF
SELECT L.GROUP#||'|'||F.MEMBER||'|'||L.STATUS||'|'||L.BYTES
FROM V$LOGFILE F
JOIN V$LOG L ON L.GROUP# = F.GROUP#
ORDER BY L.GROUP#, F.MEMBER;
EXIT;
SQL
}

generate_discovery_map() {
    log_info "Generating discovery_map.txt..."
    {
        echo "--DATAFILES--"
        "${ORACLE_HOME}/bin/sqlplus" -S / as sysdba <<'SQL'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 500 TRIMSPOOL ON TAB OFF
SELECT FILE#||'|'||NAME FROM V$DATAFILE ORDER BY FILE#;
EXIT;
SQL
        echo "--TEMPFILES--"
        "${ORACLE_HOME}/bin/sqlplus" -S / as sysdba <<'SQL'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 500 TRIMSPOOL ON TAB OFF
SELECT FILE#||'|'||NAME FROM V$TEMPFILE ORDER BY FILE#;
EXIT;
SQL
        echo "--REDO--"
        "${ORACLE_HOME}/bin/sqlplus" -S / as sysdba <<'SQL'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 500 TRIMSPOOL ON TAB OFF
SELECT L.GROUP#||'|'||F.MEMBER FROM V$LOGFILE F JOIN V$LOG L ON L.GROUP#=F.GROUP# ORDER BY L.GROUP#,F.MEMBER;
EXIT;
SQL
    } > "${FIXTURES_DIR}/discovery_map.txt"
}

generate_dba_users() {
    log_info "Generating dba_users.txt..."
    "${ORACLE_HOME}/bin/sqlplus" -S / as sysdba <<'SQL' > "${FIXTURES_DIR}/dba_users.txt"
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 500 TRIMSPOOL ON TAB OFF
SELECT USERNAME||'|'||ACCOUNT_STATUS||'|'||DEFAULT_TABLESPACE||'|'||PROFILE
FROM DBA_USERS
ORDER BY USERNAME;
EXIT;
SQL
}

generate_dba_tablespaces() {
    log_info "Generating dba_tablespaces.txt..."
    "${ORACLE_HOME}/bin/sqlplus" -S / as sysdba <<'SQL' > "${FIXTURES_DIR}/dba_tablespaces.txt"
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 500 TRIMSPOOL ON TAB OFF
SELECT TABLESPACE_NAME||'|'||STATUS||'|'||CONTENTS||'|'||LOGGING
FROM DBA_TABLESPACES
ORDER BY TABLESPACE_NAME;
EXIT;
SQL
}

generate_ora_errors() {
    log_info "Generating ora_errors.txt (simulated)..."
    cat > "${FIXTURES_DIR}/ora_errors.txt" <<'EOF'
ORA-01034: ORACLE not available
ORA-27101: shared memory realm does not exist
ORA-01555: snapshot too old: rollback segment number 1 with name "_SYSSMU1_1234$" too small
ORA-00054: resource busy and acquire with NOWAIT specified or timeout expired
ORA-12154: TNS:could not resolve the connect identifier specified
ORA-01017: invalid username/password; logon denied
ORA-01917: user or role 'MISSING_USER' does not exist
ORA-01921: role name 'MISSING_ROLE' conflicts with another user or role name
ORA-02019: connection description for remote database not found
ORA-39171: Job is experiencing a resumable wait.
ORA-31693: Table data object "SCHEMA"."TABLE" failed to load/unload
EOF
}

generate_datapump_success() {
    log_info "Generating datapump_success.txt (simulated)..."
    cat > "${FIXTURES_DIR}/datapump_success.txt" <<'EOF'
Export: Release 11.2.0.2.0 - Production on Thu Jan 15 14:30:00 2026

Copyright (c) 1982, 2011, Oracle and/or its affiliates.  All rights reserved.

Connected to: Oracle Database 11g Express Edition Release 11.2.0.2.0 - 64bit Production
Starting "SYS"."SYS_EXPORT_SCHEMA_01":  /******** AS SYSDBA directory=DATA_PUMP_DIR dumpfile=export.dmp schemas=STAGE
Estimate in progress using BLOCKS method...
Processing object type SCHEMA_EXPORT/TABLE/TABLE_DATA
Total estimation using BLOCKS method: 512 MB
Processing object type SCHEMA_EXPORT/USER
Processing object type SCHEMA_EXPORT/SYSTEM_GRANT
Processing object type SCHEMA_EXPORT/ROLE_GRANT
Processing object type SCHEMA_EXPORT/DEFAULT_ROLE
Processing object type SCHEMA_EXPORT/PRE_SCHEMA/PROCACT_SCHEMA
Processing object type SCHEMA_EXPORT/TABLE/TABLE
Processing object type SCHEMA_EXPORT/TABLE/INDEX/INDEX
Processing object type SCHEMA_EXPORT/TABLE/CONSTRAINT/CONSTRAINT
Processing object type SCHEMA_EXPORT/TABLE/INDEX/STATISTICS/INDEX_STATISTICS
Processing object type SCHEMA_EXPORT/TABLE/STATISTICS/TABLE_STATISTICS
. . exported "STAGE"."DIM_LOJA"                      1.234 MB   15420 rows
. . exported "STAGE"."DIM_PRODUTO"                   8.567 MB   98543 rows
. . exported "STAGE"."FACT_VENDAS"                 234.567 MB 1543210 rows
Master table "SYS"."SYS_EXPORT_SCHEMA_01" successfully loaded/unloaded
******************************************************************************
Dump file set for SYS.SYS_EXPORT_SCHEMA_01 is:
  /u01/app/oracle/admin/XE/dpdump/export.dmp
Job "SYS"."SYS_EXPORT_SCHEMA_01" successfully completed at Thu Jan 15 14:45:32 2026 elapsed 0 00:15:32
EOF
}

generate_datapump_with_errors() {
    log_info "Generating datapump_with_errors.txt (simulated)..."
    cat > "${FIXTURES_DIR}/datapump_with_errors.txt" <<'EOF'
Import: Release 11.2.0.2.0 - Production on Thu Jan 15 15:00:00 2026

Copyright (c) 1982, 2011, Oracle and/or its affiliates.  All rights reserved.

Connected to: Oracle Database 11g Express Edition Release 11.2.0.2.0 - 64bit Production
Master table "SYS"."SYS_IMPORT_FULL_01" successfully loaded/unloaded
Starting "SYS"."SYS_IMPORT_FULL_01":  /******** AS SYSDBA directory=DATA_PUMP_DIR dumpfile=export.dmp full=y
Processing object type SCHEMA_EXPORT/USER
ORA-31684: Object type USER:"HR" already exists
Processing object type SCHEMA_EXPORT/SYSTEM_GRANT
Processing object type SCHEMA_EXPORT/ROLE_GRANT
ORA-01917: user or role 'MISSING_ROLE' does not exist
Processing object type SCHEMA_EXPORT/DEFAULT_ROLE
Processing object type SCHEMA_EXPORT/TABLE/TABLE
Processing object type SCHEMA_EXPORT/TABLE/TABLE_DATA
. . imported "STAGE"."DIM_LOJA"                      1.234 MB   15420 rows
. . imported "STAGE"."DIM_PRODUTO"                   8.567 MB   98543 rows
ORA-02291: integrity constraint violated - parent key not found
. . imported "STAGE"."FACT_VENDAS"                 234.567 MB 1543210 rows
Processing object type SCHEMA_EXPORT/TABLE/CONSTRAINT/CONSTRAINT
ORA-02264: name already used by an existing constraint
Processing object type SCHEMA_EXPORT/TABLE/INDEX/INDEX
Job "SYS"."SYS_IMPORT_FULL_01" completed with 4 error(s) at Thu Jan 15 15:23:45 2026 elapsed 0 00:23:45
EOF
}

#===============================================================================
# Main Execution
#===============================================================================

main() {
    local force=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force) force=1; shift ;;
            -h|--help)
                echo "Usage: $0 [--force]"
                echo "  --force    Overwrite existing fixtures without prompting"
                exit 0
                ;;
            *) shift ;;
        esac
    done

    echo "========================================"
    echo "Oracle XE Fixture Generator"
    echo "========================================"
    echo

    # Check if fixtures exist
    if [[ -f "${FIXTURES_DIR}/v_instance.txt" ]] && [[ "${force}" -eq 0 ]]; then
        log_warn "Fixtures already exist. Use --force to regenerate."
        read -p "Continue and overwrite? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborted."
            exit 0
        fi
    fi

    # Setup environment
    setup_oracle_env
    log_info "ORACLE_HOME: ${ORACLE_HOME}"
    log_info "ORACLE_SID: ${ORACLE_SID}"
    echo

    # Validate access
    if ! validate_oracle_access; then
        log_error "Cannot proceed without Oracle access"
        exit 1
    fi
    echo

    # Generate fixtures
    log_info "Generating fixtures in ${FIXTURES_DIR}..."
    echo

    generate_v_instance
    generate_v_database
    generate_v_datafile
    generate_v_tempfile
    generate_v_logfile
    generate_discovery_map
    generate_dba_users
    generate_dba_tablespaces
    generate_ora_errors
    generate_datapump_success
    generate_datapump_with_errors

    echo
    log_info "Fixture generation complete."
    echo

    # Summary
    echo "Generated fixtures:"
    ls -la "${FIXTURES_DIR}"/*.txt 2>/dev/null | awk '{print "  " $NF}' || true
    echo

    # Validate generated fixtures
    local fixture_count
    fixture_count=$(find "${FIXTURES_DIR}" -name "*.txt" -type f | wc -l)
    log_info "Total fixtures generated: ${fixture_count}"

    if [[ "${fixture_count}" -ge 10 ]]; then
        log_info "All fixtures generated successfully."
    else
        log_warn "Some fixtures may be missing."
    fi
}

main "$@"
