# Oracle XE Test Fixtures

This directory contains real outputs captured from Oracle XE 11.2 for use in unit tests.

## Purpose

These fixtures provide realistic test data without requiring an active Oracle connection,
enabling:
- Offline testing
- CI/CD pipeline testing
- Consistent and reproducible test results
- Faster test execution

## Fixtures

| File | Source | Description |
|------|--------|-------------|
| `v_instance.txt` | `V$INSTANCE` | Instance status information |
| `v_database.txt` | `V$DATABASE` | Database configuration |
| `v_datafile.txt` | `V$DATAFILE` | Datafile paths and status |
| `v_tempfile.txt` | `V$TEMPFILE` | Temporary file information |
| `v_logfile.txt` | `V$LOGFILE` | Redo log file locations |
| `discovery_map.txt` | Combined query | DATAFILES + TEMPFILES + REDO map |
| `dba_users.txt` | `DBA_USERS` | User accounts and status |
| `dba_tablespaces.txt` | `DBA_TABLESPACES` | Tablespace configuration |
| `ora_errors.txt` | Simulated | Common ORA-* error messages |
| `datapump_success.txt` | Simulated | Data Pump successful output |
| `datapump_with_errors.txt` | Simulated | Data Pump output with errors |

## Regenerating Fixtures

To regenerate fixtures from a live Oracle XE instance:

```bash
cd migration_automation/scripts/tests/fixtures
./generate_fixtures.sh
```

Requirements:
- Oracle XE running and accessible
- SYSDBA access configured (user in dba group)
- `ORACLE_HOME` and `ORACLE_SID` environment variables set

## Format Standards

### Delimited Output
Most fixtures use pipe (`|`) as delimiter for easy parsing:
```
value1|value2|value3
```

### Discovery Map Format
Uses section headers with `--SECTION--` markers:
```
--DATAFILES--
1|/path/to/file1.dbf
2|/path/to/file2.dbf
--TEMPFILES--
1|/path/to/temp1.dbf
```

## Usage in Tests

```bash
# Load fixture for testing
FIXTURE_DIR="${SCRIPT_DIR}/fixtures/oracle_xe"
if [[ -f "${FIXTURE_DIR}/discovery_map.txt" ]]; then
    # Use fixture instead of live query
    cat "${FIXTURE_DIR}/discovery_map.txt"
fi
```

## Maintenance

- Regenerate fixtures when Oracle XE configuration changes
- Keep fixtures in version control for reproducibility
- Update this README when adding new fixtures
