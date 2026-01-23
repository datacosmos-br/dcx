# Datacosmos Script Libraries

This document provides comprehensive documentation for the modular bash script libraries:

- **runtime.sh** - Generic bash utilities (no Oracle dependency)
- **oracle.sh** - Oracle-specific utilities (depends on runtime.sh)
- **restore.sh** - RMAN restore orchestration (uses both libraries)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      restore.sh                              │
│              RMAN Restore Orchestration                      │
│         (specific to RMAN restore from backup)               │
└──────────────────────────┬──────────────────────────────────┘
                           │ uses
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                       oracle.sh                              │
│              Oracle-specific Utilities                       │
│  - SQLPlus/RMAN execution    - Instance state management    │
│  - Backup discovery          - PFILE manipulation           │
│  - Memory calculations       - Space checking               │
└──────────────────────────┬──────────────────────────────────┘
                           │ auto-loads
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      runtime.sh                              │
│               Generic Bash Utilities                         │
│  - Logging (log, warn, die)  - Error handling               │
│  - Validators                - Interactive confirmations    │
│  - Config loading            - Lock files                   │
│  - Display utilities         - Host reporting               │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Using runtime.sh Only

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/runtime.sh"

# Now you have access to all runtime utilities
log "Starting script..."
rt_assert_nonempty "CONFIG" "${CONFIG:-}"
require_cmds curl jq

# Interactive confirmation
pause "Continue?" "YES"

log "Done!"
```

### Using oracle.sh (Auto-loads runtime.sh)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/oracle.sh"

# All runtime.sh functions are available
log "Starting Oracle operation..."

# Plus Oracle-specific functions
oracle_validate_oracle_home
state=$(oracle_instance_state)
log "Instance ${ORACLE_SID} is: ${state}"
```

---

## runtime.sh Reference

### Logging & Output

| Function | Usage | Description |
|----------|-------|-------------|
| `ts` | `echo "$(ts) message"` | Returns ISO timestamp |
| `log` | `log "message"` | Timestamped message to stdout |
| `warn` | `warn "warning"` | Timestamped warning to stderr |
| `die` | `die "error"` | Print error and exit with code 1 |

### Error Handling

| Function | Usage | Description |
|----------|-------|-------------|
| `runtime_enable_err_trap` | `runtime_enable_err_trap` | Enable automatic error trapping |
| `on_err` | (internal) | Error trap handler |

### Command Validation

| Function | Usage | Description |
|----------|-------|-------------|
| `need_cmd` | `need_cmd sqlplus` | Check if command exists |
| `require_cmds` | `require_cmds awk sed grep` | Check multiple commands |

### Log Initialization

| Function | Usage | Description |
|----------|-------|-------------|
| `runtime_init_logs` | `runtime_init_logs "/var/log/myapp" "prefix"` | Initialize logging with tee |

**Sets:** `LOGDIR`, `MAIN_LOG` variables

### File Display

| Function | Usage | Description |
|----------|-------|-------------|
| `show_file` | `show_file "/path/file" 50` | Display first N lines with header |

### Interactive Confirmations

| Function | Usage | Description |
|----------|-------|-------------|
| `pause` | `pause "Continue?" "YES"` | Wait for confirmation token |
| `confirm_token` | `confirm_token "Delete?" "DELETE"` | Critical confirmation |
| `confirm_retype_value` | `confirm_retype_value "DB name:" "PROD"` | Retype value confirmation |

**Note:** All skip with `AUTO_YES=1`

### Output Capture

| Function | Usage | Description |
|----------|-------|-------------|
| `runtime_capture` | `runtime_capture out cmd args` | Capture stdout+stderr to variable |

### Generic Validators

| Function | Usage | Description |
|----------|-------|-------------|
| `rt_assert_nonempty` | `rt_assert_nonempty "VAR" "$VAR"` | Variable is not empty |
| `rt_assert_abs_path` | `rt_assert_abs_path "PATH" "$PATH"` | Path is absolute |
| `rt_assert_dir_exists` | `rt_assert_dir_exists "DIR" "$DIR"` | Directory exists |
| `rt_assert_file_exists` | `rt_assert_file_exists "FILE" "$FILE"` | File exists |
| `rt_assert_enum` | `rt_assert_enum "MODE" "$M" a b c` | Value is one of options |
| `rt_assert_bool01` | `rt_assert_bool01 "FLAG" "$F"` | Value is 0 or 1 |
| `rt_assert_uint` | `rt_assert_uint "NUM" "$N"` | Value is unsigned integer |
| `rt_assert_sid_token` | `rt_assert_sid_token "SID" "$S"` | Valid SID-like token |
| `rt_assert_regex` | `rt_assert_regex "V" "$V" 'pat'` | Value matches regex |

### Configuration Loading

| Function | Usage | Description |
|----------|-------|-------------|
| `runtime_load_config` | `runtime_load_config "/etc/app.conf"` | Load key=value config file |

**Config format:**
```bash
# Comments ignored
KEY=value
KEY2="quoted value"
```

### Lock File Management

| Function | Usage | Description |
|----------|-------|-------------|
| `runtime_lock_file` | `runtime_lock_file "/tmp/app.lock"` | Acquire exclusive lock |
| `runtime_unlock_file` | `runtime_unlock_file "/tmp/app.lock"` | Release lock (usually automatic) |

### Display Utilities

| Function | Usage | Description |
|----------|-------|-------------|
| `runtime_print_kv` | `runtime_print_kv "Key" "Value"` | Print aligned key-value |
| `runtime_print_vars` | `runtime_print_vars "Title" "K=V" ...` | Print variable section |
| `runtime_print_section` | `runtime_print_section "Title"` | Print section header |
| `runtime_print_separator` | `runtime_print_separator` | Print separator line |

### Host Reporting

| Function | Usage | Description |
|----------|-------|-------------|
| `runtime_write_host_report` | `runtime_write_host_report "/out.txt" [callback]` | Write system info |

### Utility Functions

| Function | Usage | Description |
|----------|-------|-------------|
| `runtime_retry` | `runtime_retry 3 5 cmd args` | Retry with exponential backoff |
| `runtime_timeout` | `runtime_timeout 30 cmd args` | Run with timeout |
| `runtime_fs_available_gb` | `runtime_fs_available_gb "/data"` | Get available GB |
| `runtime_fs_used_percent` | `runtime_fs_used_percent "/data"` | Get usage percentage |

---

## oracle.sh Reference

### Environment Validation

| Function | Usage | Description |
|----------|-------|-------------|
| `oracle_validate_oracle_home` | `oracle_validate_oracle_home` | Validate ORACLE_HOME |
| `validate_mem_value` | `validate_mem_value "12G"` | Validate memory format |

### oratab Handling

| Function | Usage | Description |
|----------|-------|-------------|
| `oracle_oratab_home_for_sid` | `oracle_oratab_home_for_sid "ORCL"` | Get ORACLE_HOME from oratab |
| `oracle_core_check_oratab_mismatch` | `oracle_core_check_oratab_mismatch "${ORACLE_SID}" \|\| true` | Warn if mismatch |

### SQL Execution (oracle_sql.sh)

| Function | Usage | Description |
|----------|-------|-------------|
| `oracle_sql_sysdba_exec` | `oracle_sql_sysdba_exec "SQL statement"` | Execute as SYSDBA |
| `oracle_sql_sysdba_exec_sid` | `oracle_sql_sysdba_exec_sid "SID" "SQL"` | Execute with specific SID |
| `oracle_sql_sysdba_query` | `oracle_sql_sysdba_query "SELECT..."` | Query returning just result |
| `oracle_sql_execute_file` | `oracle_sql_execute_file "script.sql"` | Execute SQL script file |
| `oracle_sql_test_connection` | `oracle_sql_test_connection "conn"` | Test database connectivity |

### Instance State Management (oracle_instance.sh)

| Function | Usage | Description |
|----------|-------|-------------|
| `oracle_instance_list_sids` | `oracle_instance_list_sids` | List running instances |
| `oracle_instance_get_pmon` | `oracle_instance_get_pmon` | Get PMON SID matching ORACLE_SID |
| `oracle_instance_is_pmon_running` | `oracle_instance_is_pmon_running` | Check if target PMON running |
| `oracle_instance_ping` | `oracle_instance_ping "SID"` | Test SYSDBA connection |
| `oracle_instance_get_state` | `oracle_instance_get_state` | Get state: DOWN/UP/ZOMBIE |
| `oracle_instance_shutdown_abort` | `oracle_instance_shutdown_abort` | Perform shutdown abort |
| `oracle_instance_startup_nomount` | `oracle_instance_startup_nomount "/path"` | Startup NOMOUNT |

### PFILE Parsing

| Function | Usage | Description |
|----------|-------|-------------|
| `oracle_parse_db_name_from_pfile` | `oracle_parse_db_name_from_pfile "/path"` | Extract db_name |
| `oracle_parse_param_from_pfile` | `oracle_parse_param_from_pfile "/path" "param"` | Extract any parameter |

### RMAN Operations

| Function | Usage | Description |
|----------|-------|-------------|
| `oracle_rman_exec_cmdfile` | `oracle_rman_exec_cmdfile "cmd.rcv" "out.log"` | Execute RMAN cmdfile |
| `oracle_rman_channels_alloc` | `oracle_rman_channels_alloc` | Generate channel alloc commands |
| `oracle_rman_channels_release` | `oracle_rman_channels_release` | Generate channel release commands |
| `oracle_rman_write_cmdfile_run` | `oracle_rman_write_cmdfile_run "file" "dbid" "post" <<EOF` | Write RUN block cmdfile |
| `oracle_rman_write_cmdfile_simple` | `oracle_rman_write_cmdfile_simple "file" <<EOF` | Write simple cmdfile |
| `auto_rman_channels` | `auto_rman_channels` | Auto-calculate channel count |

### Backup Discovery

| Function | Usage | Description |
|----------|-------|-------------|
| `oracle_detect_dbid_unique_in_autobackup` | `oracle_detect_dbid_unique_in_autobackup "/auto"` | Detect DBID from autobackup |
| `oracle_backup_discover` | `oracle_backup_discover "/backup"` | Discover backup paths |

**Returns:** Sets `BKPFULL`, `BKPARCH`, `AUTO`, optionally `DBID`

### Discovery Map Generation

| Function | Usage | Description |
|----------|-------|-------------|
| `oracle_generate_discovery_map` | `oracle_generate_discovery_map "/output"` | Generate datafile/tempfile/redo map |
| `oracle_build_rman_newname_lines_from_disc` | `oracle_build_rman_newname_lines_from_disc` | Build SET NEWNAME commands |

### Memory & Resource Calculation

| Function | Usage | Description |
|----------|-------|-------------|
| `calc_sga_pga` | `read -r sga pga < <(calc_sga_pga)` | Calculate optimal SGA/PGA |

**Returns:** "SGAG PGAG" format (e.g., "12G 4G")
**Respects:** `SGA_TARGET`, `PGA_TARGET` env vars for override

### Filesystem Operations

| Function | Usage | Description |
|----------|-------|-------------|
| `oracle_fs_available_gb` | `oracle_fs_available_gb "/u01"` | Get available GB |
| `oracle_estimate_db_size_gb_from_controlfile` | `oracle_estimate_db_size_gb_from_controlfile` | Estimate DB size |
| `oracle_space_check` | `oracle_space_check "/dest" 20` | Check space with margin |

### PFILE Sanitization

| Function | Usage | Description |
|----------|-------|-------------|
| `oracle_sanitize_pfile` | `oracle_sanitize_pfile "src" "dst" opts` | Sanitize PFILE for clone |

**Options (associative array):**
- `ORIG_DB_NAME` - Original db_name (required)
- `TARGET_DB_UNIQUE_NAME` - Target db_unique_name
- `DEST_TYPE` - FS or ASM
- `DEST_BASE` - Base directory
- `ADMIN_DIR` - Admin directory
- `CONTROL_DIR` - Control file directory
- `DATA_DG` / `FRA_DG` - ASM diskgroups
- `SGA` / `PGA` - Memory targets
- `DROP_HIDDEN` - Drop hidden parameters (0/1)

### Oracle Host Report

| Function | Usage | Description |
|----------|-------|-------------|
| `oracle_host_report_callback` | `runtime_write_host_report "/out" "oracle_host_report_callback"` | Add Oracle info to report |

---

## Best Practices

### 1. Always Source Libraries at Top

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/oracle.sh"  # Auto-loads runtime.sh

# Your code here
```

### 2. Enable Error Trapping Early

```bash
runtime_init_logs "/tmp/myapp_logs" "myapp"
runtime_enable_err_trap
```

### 3. Validate Input Early

```bash
# Validate all inputs before doing work
rt_assert_nonempty "CONFIG_FILE" "${CONFIG_FILE:-}"
rt_assert_abs_path "DATA_DIR" "${DATA_DIR}"
rt_assert_enum "MODE" "${MODE}" "backup" "restore"
```

### 4. Use Structured Logging

```bash
log "==[PHASE] Starting backup..."
# ... do backup ...
log "==[PHASE] Backup complete"
```

### 5. Use Confirmations for Dangerous Operations

```bash
confirm_token "This will DELETE all data. Continue?" "DELETE-ALL"
```

### 6. Use Capture for Commands That Might Fail

```bash
if runtime_capture output some_command; then
    log "Success: ${output}"
else
    warn "Failed: ${output}"
fi
```

### 7. Use Lock Files for Singleton Scripts

```bash
runtime_lock_file "/tmp/myapp.lock"
# Script is now exclusively running
# Lock auto-released on exit
```

---

## Common Patterns

### Pattern: Validate Environment

```bash
# Check commands exist
require_cmds sqlplus rman awk

# Validate Oracle environment
oracle_validate_oracle_home
oracle_core_check_oratab_mismatch "${ORACLE_SID}" || true

# Validate paths
rt_assert_abs_path "BACKUP_ROOT" "${BACKUP_ROOT}"
rt_assert_dir_exists "BACKUP_ROOT" "${BACKUP_ROOT}"
```

### Pattern: Instance State Check Before Operation

```bash
state=$(oracle_instance_get_state)
case "${state}" in
    DOWN)
        log "Instance is down, starting..."
        oracle_instance_startup_nomount "${PFILE}"
        ;;
    UP)
        if [[ "${ALLOW_CLEANUP}" == "1" ]]; then
            oracle_instance_shutdown_abort
        else
            die "Instance is running. Set ALLOW_CLEANUP=1 to stop it."
        fi
        ;;
    ZOMBIE)
        die "Instance is in ZOMBIE state. Resolve manually first."
        ;;
esac
```

### Pattern: Safe RMAN Execution

```bash
# Generate command file
oracle_rman_write_cmdfile_run "${RCV_FILE}" "${DBID}" "" <<EOF
  restore controlfile from autobackup;
EOF

# Show and confirm
show_file "${RCV_FILE}" 50
pause "Execute RMAN restore controlfile?" "YES"

# Execute
oracle_rman_exec_cmdfile "${RCV_FILE}" "${LOG_FILE}"
```

### Pattern: Memory Sizing with Override

```bash
# Will use SGA_TARGET/PGA_TARGET if set, otherwise calculate
read -r sga pga < <(calc_sga_pga)
validate_mem_value "${sga}"
validate_mem_value "${pga}"
log "Using SGA=${sga}, PGA=${pga}"
```

---

## Troubleshooting

### "Command not found: log"

The script didn't source runtime.sh properly. Check:
```bash
source "$(dirname "$0")/runtime.sh"
```

### Oracle Functions Not Available

Make sure oracle.sh is sourced (it auto-loads runtime.sh):
```bash
source "$(dirname "$0")/oracle.sh"
```

### Lock File Prevents Script from Running

Check if another instance is actually running:
```bash
cat /tmp/myapp.lock  # Shows PID
ps -p $(cat /tmp/myapp.lock)  # Check if running
rm /tmp/myapp.lock  # Remove if stale
```

### Instance State Returns ZOMBIE

This means PMON exists but can't connect. Common causes:
- Wrong ORACLE_HOME
- Wrong ORACLE_SID (case matters)
- Instance crashed but PMON orphaned

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0.0 | 2026-01-13 | Modular reorganization |
| 1.2.0 | 2026-01-12 | Added memory calculation |
| 1.0.0 | 2026-01-10 | Initial version |

---

## License

Apache License 2.0 - See LICENSE file for details.

**Copyright (c) 2026 Datacosmos**
