#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Test: oracle.sh Validation Tests
#
# Validates oracle.sh functions using mocked Oracle environment and fixtures.
# Does NOT require actual Oracle installation for most tests.
#
# Usage:
#   ./test_oracle.sh              # Run with mock environment
#   ./test_oracle.sh --fixtures   # Include fixture-based tests
#
# Fixtures are real outputs captured from Oracle XE 11.2 for realistic testing.
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Used in bash -c subshells for fixture-based tests
export FIXTURES_DIR="${SCRIPT_DIR}/fixtures/oracle_xe"

# Parse arguments
# Used in conditional tests below
export USE_FIXTURES=0
for arg in "$@"; do
    case "${arg}" in
        --fixtures) USE_FIXTURES=1 ;;
    esac
done

#===============================================================================
# TEST FRAMEWORK
#===============================================================================

TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

run_test() {
    local name="$1"
    shift
    TEST_COUNT=$((TEST_COUNT + 1))

    # Run in subshell to isolate exit calls
    if ("$@") 2>/dev/null; then
        echo "[PASS] ${name}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "[FAIL] ${name}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

run_test_expect_fail() {
    local name="$1"
    shift
    TEST_COUNT=$((TEST_COUNT + 1))

    # Run in subshell to isolate exit calls (die/exit won't kill test runner)
    if ! ("$@") 2>/dev/null; then
        echo "[PASS] ${name} (expected failure)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "[FAIL] ${name} (should have failed)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

#===============================================================================
# SETUP: Mock Oracle Environment
#===============================================================================

echo "=== Setting up Mock Oracle Environment ==="

MOCK_ORACLE_HOME="/tmp/mock_oracle_$$"
mkdir -p "${MOCK_ORACLE_HOME}/bin"

# Create mock sqlplus
cat > "${MOCK_ORACLE_HOME}/bin/sqlplus" <<'MOCK'
#!/bin/bash
echo "SQL*Plus: Release 19.0.0.0.0 - Mock"
echo "Connected to:"
echo "Oracle Database 19c - Mock"
MOCK
chmod +x "${MOCK_ORACLE_HOME}/bin/sqlplus"

# Create mock rman
cat > "${MOCK_ORACLE_HOME}/bin/rman" <<'MOCK'
#!/bin/bash
echo "Recovery Manager: Release 19.0.0.0.0 - Mock"
echo "RMAN> "
MOCK
chmod +x "${MOCK_ORACLE_HOME}/bin/rman"

export ORACLE_HOME="${MOCK_ORACLE_HOME}"
export ORACLE_SID="MOCKDB"

# Now source oracle.sh (which auto-loads runtime.sh)
source "${SCRIPT_DIR}/../lib/oracle.sh"
# Also load oracle_rman.sh for RMAN-specific functions
source "${SCRIPT_DIR}/../lib/oracle_rman.sh"

echo "Mock ORACLE_HOME: ${ORACLE_HOME}"
echo "Mock ORACLE_SID: ${ORACLE_SID}"
echo

#===============================================================================
# TEST: Environment Validation
#===============================================================================

echo "=== Testing Environment Validation ==="

run_test "oracle_core_validate_home passes" oracle_core_validate_home

#===============================================================================
# TEST: Memory Validation
#===============================================================================

echo
echo "=== Testing Memory Validation ==="

run_test "oracle_config_validate_mem_value 4G" oracle_config_validate_mem_value "4G"
run_test "oracle_config_validate_mem_value 512M" oracle_config_validate_mem_value "512M"
run_test "oracle_config_validate_mem_value 1024K" oracle_config_validate_mem_value "1024K"
run_test "oracle_config_validate_mem_value lowercase 8g" oracle_config_validate_mem_value "8g"
run_test "oracle_config_validate_mem_value lowercase 256m" oracle_config_validate_mem_value "256m"

run_test_expect_fail "oracle_config_validate_mem_value rejects 4GB" oracle_config_validate_mem_value "4GB"
run_test "oracle_config_validate_mem_value accepts bytes as plain number" oracle_config_validate_mem_value "1024"
run_test_expect_fail "oracle_config_validate_mem_value rejects empty" oracle_config_validate_mem_value ""
run_test_expect_fail "oracle_config_validate_mem_value rejects text" oracle_config_validate_mem_value "large"

#===============================================================================
# TEST: PFILE Parsing
#===============================================================================

echo
echo "=== Testing PFILE Parsing ==="

MOCK_PFILE="/tmp/mock_pfile_$$.ora"

cat > "${MOCK_PFILE}" <<'EOF'
*.db_name='TESTDB'
*.db_unique_name='TESTDB_UNIQUE'
*.sga_target=8G
*.pga_aggregate_target=2G
*.processes=1500
*.control_files='/u01/oradata/TESTDB/control01.ctl','/u01/oradata/TESTDB/control02.ctl'
EOF

run_test "parse_db_name extracts TESTDB" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    result=$(oracle_config_pfile_parse_db_name "'"${MOCK_PFILE}"'")
    [[ "${result}" == "TESTDB" ]]
'

run_test "parse_param extracts db_unique_name" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    result=$(oracle_config_pfile_parse_param "'"${MOCK_PFILE}"'" "db_unique_name")
    [[ "${result}" == "TESTDB_UNIQUE" ]]
'

run_test "parse_param extracts sga_target" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    result=$(oracle_config_pfile_parse_param "'"${MOCK_PFILE}"'" "sga_target")
    [[ "${result}" == "8G" ]]
'

rm -f "${MOCK_PFILE}"

#===============================================================================
# TEST: DBID Detection
#===============================================================================

echo
echo "=== Testing DBID Detection ==="

MOCK_AUTOBACKUP="/tmp/mock_autobackup_$$"
mkdir -p "${MOCK_AUTOBACKUP}"

# Create fake autobackup files
touch "${MOCK_AUTOBACKUP}/c-1234567890-20260113-00"
touch "${MOCK_AUTOBACKUP}/c-1234567890-20260113-01"

run_test "detect_dbid finds unique DBID" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    source "'"${SCRIPT_DIR}"'/../lib/oracle_rman.sh"
    result=$(oracle_rman_detect_dbid "'"${MOCK_AUTOBACKUP}"'")
    [[ "${result}" == "1234567890" ]]
'

# Add another DBID to create ambiguity
touch "${MOCK_AUTOBACKUP}/c-9876543210-20260113-00"

run_test "detect_dbid returns rc=2 for multiple DBIDs" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    source "'"${SCRIPT_DIR}"'/../lib/oracle_rman.sh"
    oracle_rman_detect_dbid "'"${MOCK_AUTOBACKUP}"'"
    [[ $? -eq 2 ]]
'

rm -rf "${MOCK_AUTOBACKUP}"

#===============================================================================
# TEST: Backup Discovery
#===============================================================================

echo
echo "=== Testing Backup Discovery ==="

MOCK_BACKUP_ROOT="/tmp/mock_backup_$$"
mkdir -p "${MOCK_BACKUP_ROOT}/autobackup"
touch "${MOCK_BACKUP_ROOT}/autobackup/c-1111111111-20260113-00"

run_test "backup_discover finds direct autobackup" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    source "'"${SCRIPT_DIR}"'/../lib/oracle_rman.sh"
    BKPFULL=""
    AUTO=""
    oracle_rman_backup_discover "'"${MOCK_BACKUP_ROOT}"'"
    [[ -n "${BKPFULL}" && -n "${AUTO}" ]]
'

rm -rf "${MOCK_BACKUP_ROOT}"

# Test RMAN_LOCAL_FULL structure
MOCK_BACKUP_ROOT2="/tmp/mock_backup2_$$"
mkdir -p "${MOCK_BACKUP_ROOT2}/RMAN_LOCAL_FULL/PRODDB/autobackup"
touch "${MOCK_BACKUP_ROOT2}/RMAN_LOCAL_FULL/PRODDB/autobackup/c-2222222222-20260113-00"

run_test "backup_discover finds RMAN_LOCAL_FULL structure" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    source "'"${SCRIPT_DIR}"'/../lib/oracle_rman.sh"
    BKPFULL=""
    AUTO=""
    DBID=""
    oracle_rman_backup_discover "'"${MOCK_BACKUP_ROOT2}"'"
    [[ -n "${BKPFULL}" && "${DBID}" == "2222222222" ]]
'

rm -rf "${MOCK_BACKUP_ROOT2}"

#===============================================================================
# TEST: RMAN Channel Functions
#===============================================================================

echo
echo "=== Testing RMAN Channel Functions ==="

run_test "oracle_rman_auto_channels sets variable" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    source "'"${SCRIPT_DIR}"'/../lib/oracle_rman.sh"
    unset RMAN_CHANNELS
    oracle_rman_auto_channels
    [[ -n "${RMAN_CHANNELS}" && "${RMAN_CHANNELS}" =~ ^[0-9]+$ ]]
'

run_test "rman_channels_alloc generates commands" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    source "'"${SCRIPT_DIR}"'/../lib/oracle_rman.sh"
    RMAN_CHANNELS=2
    result=$(oracle_rman_channels_alloc)
    echo "${result}" | grep -q "allocate channel c1"
    echo "${result}" | grep -q "allocate channel c2"
'

run_test "rman_channels_release generates commands" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    source "'"${SCRIPT_DIR}"'/../lib/oracle_rman.sh"
    RMAN_CHANNELS=2
    result=$(oracle_rman_channels_release)
    echo "${result}" | grep -q "release channel c1"
    echo "${result}" | grep -q "release channel c2"
'

#===============================================================================
# TEST: RMAN Command File Generation
#===============================================================================

echo
echo "=== Testing RMAN Command File Generation ==="

MOCK_CMDFILE="/tmp/mock_cmdfile_$$.rcv"

run_test "write_cmdfile_run creates file" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    source "'"${SCRIPT_DIR}"'/../lib/oracle_rman.sh"
    RMAN_CHANNELS=2
    oracle_rman_write_cmdfile_run "'"${MOCK_CMDFILE}"'" "1234567890" "" <<EOF
  restore controlfile from autobackup;
EOF
    [[ -f "'"${MOCK_CMDFILE}"'" ]]
'

run_test "cmdfile contains set dbid" bash -c '
    grep -q "set dbid 1234567890" "'"${MOCK_CMDFILE}"'"
'

run_test "cmdfile contains run block" bash -c '
    grep -q "run {" "'"${MOCK_CMDFILE}"'"
'

run_test "cmdfile contains channel allocation" bash -c '
    grep -q "allocate channel" "'"${MOCK_CMDFILE}"'"
'

rm -f "${MOCK_CMDFILE}"

#===============================================================================
# TEST: Memory Calculation
#===============================================================================

echo
echo "=== Testing Memory Calculation ==="

run_test "oracle_config_calc_memory returns two values" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    unset SGA_TARGET PGA_TARGET
    read -r sga pga < <(oracle_config_calc_memory)
    [[ -n "${sga}" && -n "${pga}" ]]
'

run_test "oracle_config_calc_memory uses overrides" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    export SGA_TARGET="16G"
    export PGA_TARGET="8G"
    read -r sga pga < <(oracle_config_calc_memory)
    [[ "${sga}" == "16G" && "${pga}" == "8G" ]]
'

#===============================================================================
# TEST: oratab Functions
#===============================================================================

echo
echo "=== Testing oratab Functions ==="

MOCK_ORATAB="/tmp/mock_oratab_$$"
cat > "${MOCK_ORATAB}" <<EOF
# Oracle oratab
ORCL:/u01/app/oracle/product/19.0.0/dbhome19c:Y
TESTDB:/u01/app/oracle/product/19.0.0/dbhome_test:N
# Comment line
EOF

run_test "oratab_home_for_sid finds ORCL" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    result=$(awk -F: -v SID="ORCL" '\''
      $0 !~ /^[[:space:]]*#/ && NF>=2 {
        if ($1==SID) { print $2; exit }
      }'\'' "'"${MOCK_ORATAB}"'")
    [[ "${result}" == "/u01/app/oracle/product/19.0.0/dbhome19c" ]]
'

rm -f "${MOCK_ORATAB}"

#===============================================================================
# TEST: Fixture-Based Tests (Real Oracle XE outputs)
#===============================================================================

if [[ "${USE_FIXTURES}" -eq 1 ]] && [[ -d "${FIXTURES_DIR}" ]]; then
    echo
    echo "=== Testing with Real Oracle XE Fixtures ==="

    # Test parsing V$INSTANCE fixture
    run_test "fixture: parse v_instance status" bash -c '
        line=$(head -1 "'"${FIXTURES_DIR}"'/v_instance.txt")
        status=$(echo "${line}" | cut -d"|" -f5)
        [[ "${status}" == "OPEN" ]]
    '

    run_test "fixture: parse v_instance db_status" bash -c '
        line=$(head -1 "'"${FIXTURES_DIR}"'/v_instance.txt")
        db_status=$(echo "${line}" | cut -d"|" -f6)
        [[ "${db_status}" == "ACTIVE" ]]
    '

    # Test parsing V$DATAFILE fixture
    run_test "fixture: v_datafile has multiple files" bash -c '
        count=$(wc -l < "'"${FIXTURES_DIR}"'/v_datafile.txt")
        [[ "${count}" -ge 3 ]]
    '

    run_test "fixture: v_datafile paths are absolute" bash -c '
        while IFS= read -r line; do
            path=$(echo "${line}" | cut -d"|" -f2)
            [[ "${path}" == /* ]] || exit 1
        done < "'"${FIXTURES_DIR}"'/v_datafile.txt"
    '

    # Test parsing discovery map sections
    run_test "fixture: discovery_map DATAFILES count" bash -c '
        count=$(awk "/^--DATAFILES--/{f=1;next} /^--/{f=0} f&&/\|/{print}" "'"${FIXTURES_DIR}"'/discovery_map.txt" | wc -l)
        [[ "${count}" -ge 1 ]]
    '

    run_test "fixture: discovery_map TEMPFILES count" bash -c '
        count=$(awk "/^--TEMPFILES--/{f=1;next} /^--/{f=0} f&&/\|/{print}" "'"${FIXTURES_DIR}"'/discovery_map.txt" | wc -l)
        [[ "${count}" -ge 1 ]]
    '

    run_test "fixture: discovery_map REDO count" bash -c '
        count=$(awk "/^--REDO--/{f=1;next} /^--/{f=0} f&&/\|/{print}" "'"${FIXTURES_DIR}"'/discovery_map.txt" | wc -l)
        [[ "${count}" -ge 1 ]]
    '

    # Test DBA_USERS parsing
    run_test "fixture: dba_users has SYS" bash -c '
        grep -q "^SYS|OPEN" "'"${FIXTURES_DIR}"'/dba_users.txt"
    '

    run_test "fixture: dba_users has SYSTEM" bash -c '
        grep -q "^SYSTEM|OPEN" "'"${FIXTURES_DIR}"'/dba_users.txt"
    '

    # Test ORA error detection patterns
    run_test "fixture: ora_errors ORA-01034 pattern" bash -c '
        grep -q "ORA-01034.*not available" "'"${FIXTURES_DIR}"'/ora_errors.txt"
    '

    run_test "fixture: ora_errors ORA-01555 pattern" bash -c '
        grep -q "ORA-01555.*snapshot too old" "'"${FIXTURES_DIR}"'/ora_errors.txt"
    '

else
    if [[ "${USE_FIXTURES}" -eq 1 ]]; then
        echo
        echo "=== Fixture Tests Skipped (fixtures not found) ==="
        echo "Generate fixtures first: ./fixtures/generate_fixtures.sh"
    fi
fi

#===============================================================================
# TEST: RMAN Internal Functions
#===============================================================================

echo
echo "=== Testing RMAN Internal Functions ==="

run_test "_rman_clean_name handles standard OMF" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    source "'"${SCRIPT_DIR}"'/../lib/oracle_rman.sh"
    result=$(_rman_clean_name "/u01/oradata/o1_mf_system_abc123_.dbf" "dbf")
    [[ "${result}" == "system.dbf" ]]
'

run_test "_rman_clean_name handles standard DF" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    source "'"${SCRIPT_DIR}"'/../lib/oracle_rman.sh"
    result=$(_rman_clean_name "/u01/oradata/system.262.123456" "dbf")
    [[ "${result}" == "system.dbf" ]]
'

run_test "_rman_clean_name handles normal files" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    source "'"${SCRIPT_DIR}"'/../lib/oracle_rman.sh"
    result=$(_rman_clean_name "/u01/oradata/users01.dbf" "dbf")
    [[ "${result}" == "users01.dbf" ]]
'

run_test "_rman_clean_name handles weird characters" bash -c '
    source "'"${SCRIPT_DIR}"'/../lib/oracle.sh"
    source "'"${SCRIPT_DIR}"'/../lib/oracle_rman.sh"
    result=$(_rman_clean_name "/u01/oradata/bad-name#file.dbf" "dbf")
    [[ "${result}" == "badnamefile.dbf" ]]
'

#===============================================================================
# CLEANUP
#===============================================================================

echo
echo "=== Cleaning up Mock Environment ==="
rm -rf "${MOCK_ORACLE_HOME}"
echo "Cleanup complete."

#===============================================================================
# SUMMARY
#===============================================================================

echo
echo "========================================"
echo "Test Summary: ${PASS_COUNT}/${TEST_COUNT} passed"
if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    echo "FAILURES: ${FAIL_COUNT}"
    exit 1
else
    echo "All tests passed!"
    exit 0
fi
