# Migration Automation Libraries

This directory contains modular bash libraries for Oracle Data Pump migration operations.

## Dependency Graph

```
Layer 0: logging.sh (sem dependências)
    │
    └──> Layer 1: runtime.sh (depende apenas de logging.sh)
            │
            └──> Layer 2: core.sh (loader/manager, depende de logging.sh + runtime.sh)
                    │
                    └──> Layer 3: Módulos opcionais (carregados via core_require/core_load)
                            │
                            ├──> config.sh (depende de runtime.sh)
                            ├──> queue.sh (depende de runtime.sh)
                            ├──> report.sh (depende de runtime.sh)
                            │
                            └──> ORACLE MODULE HIERARCHY
                                    │
                                    ├──> oracle_core.sh (base Oracle validations)
                                    │       └──> deps: runtime.sh
                                    │
                                    ├──> oracle_sql.sh (SQL execution via sqlplus)
                                    │       └──> deps: runtime.sh, oracle_core.sh
                                    │
                                    ├──> oracle_config.sh (PFILE, paths, memory sizing)
                                    │       └──> deps: runtime.sh, oracle_core.sh, oracle_sql.sh
                                    │
                                    ├──> oracle_cluster.sh (RAC detection, srvctl)
                                    │       └──> deps: runtime.sh, oracle_core.sh, oracle_sql.sh
                                    │
                                    ├──> oracle_env.sh (environment setup)
                                    │       └──> deps: oracle_core.sh, config.sh
                                    │
                                    ├──> oracle_instance.sh (instance lifecycle)
                                    │       └──> deps: oracle_core.sh, oracle_sql.sh, oracle_cluster.sh
                                    │
                                    ├──> oracle.sh (unified loader for all Oracle modules)
                                    │       └──> loads all oracle_*.sh modules
                                    │
                                    ├──> oracle_datapump.sh (Data Pump operations)
                                    │       └──> deps: oracle_core.sh, oracle_sql.sh
                                    │
                                    ├──> oracle_rman.sh (RMAN operations)
                                    │       └──> deps: oracle_core.sh, oracle_sql.sh
                                    │
                                    └──> oracle_oci.sh (OCI Object Storage)
                                            └──> deps: runtime.sh, queue.sh
```

## Arquitetura de Camadas

1. **Layer 0 - logging.sh**: Base sem dependências
2. **Layer 1 - runtime.sh**: Utilidades genéricas (depende apenas de logging.sh)
3. **Layer 2 - core.sh**: Loader/manager genérico (depende de logging.sh + runtime.sh)
4. **Layer 3 - Módulos opcionais**: Carregados sob demanda via `core_require` ou `core_load`

## Module Overview

### Core Modules

| Module | Purpose | Function Prefix | Dependencies | Lines |
|--------|---------|-----------------|--------------|-------|
| `logging.sh` | Structured logging with context | `log_*`, `ts` | none | ~550 |
| `runtime.sh` | Generic utilities | `runtime_*`, `rt_*`, `on_err`, `need_cmd`, etc. | logging.sh | ~330 |
| `core.sh` | Module loader/manager | `core_*` | logging.sh, runtime.sh | ~420 |
| `config.sh` | Hierarchical config + validation | `config_*`, `runtime_load_config` | runtime.sh | ~480 |
| `config_defaults.sh` | Centralized defaults + schemas | - | config.sh | ~155 |
| `queue.sh` | Parallel job queue | `queue_*` | runtime.sh | ~260 |
| `report.sh` | Unified workflow & reporting | `report_*` | logging.sh, runtime.sh | ~650 |

### Oracle Modules (v4.2+)

| Module | Purpose | Function Prefix | Dependencies | Lines |
|--------|---------|-----------------|--------------|-------|
| `oracle_core.sh` | Base validations, binary discovery | `oracle_core_*` | runtime.sh | ~70 |
| `oracle_sql.sh` | SQL execution via sqlplus | `oracle_sql_*` | oracle_core.sh | ~300 |
| `oracle_config.sh` | PFILE operations, memory sizing, paths | `oracle_config_*` | oracle_core.sh, oracle_sql.sh | ~350 |
| `oracle_cluster.sh` | RAC detection, srvctl integration | `oracle_cluster_*` | oracle_core.sh, oracle_sql.sh | ~120 |
| `oracle_env.sh` | Environment setup, config loading | `oracle_env_*` | oracle_core.sh, config.sh | ~90 |
| `oracle_instance.sh` | Instance lifecycle (start/stop/state) | `oracle_instance_*` | oracle_core.sh, oracle_sql.sh, oracle_cluster.sh | ~280 |
| `oracle.sh` | Unified loader for all Oracle modules | `oracle_*` | all oracle_*.sh | ~50 |
| `oracle_datapump.sh` | Data Pump operations | `dp_*` | oracle_core.sh, oracle_sql.sh | ~450 |
| `oracle_rman.sh` | RMAN operations | `oracle_rman_*` | oracle_core.sh, oracle_sql.sh | ~500 |
| `oracle_oci.sh` | OCI Object Storage | `oci_*` | runtime.sh, queue.sh | ~205 |

## Log Levels and Events

All libraries use structured logging from `logging.sh`:

### Log Levels
- `DEBUG` - Detailed diagnostic (LOG_LEVEL >= 3)
- `INFO` - General operational messages
- `SUCCESS` - Successful completion markers
- `WARN` - Warning conditions
- `ERROR` - Error conditions

### Context Capture (v4.1+)
When `LOG_SHOW_CONTEXT=1`, logs include caller info:
```
[2026-01-15 11:30:45] [INFO] [oracle:start_db:123] Starting database
```

### Structured Logging (JSON)
When `LOG_STRUCTURED=1`, outputs JSON:
```json
{"timestamp":"2026-01-15T11:30:45Z","level":"INFO","module":"oracle","function":"start_db","line":123,"message":"Starting database"}
```

### Module-Level Control
Set per-module log levels:
```bash
log_set_module_level "oracle" "DEBUG"
log_set_module_level "config" "WARN"
```

### Log Event Types
- `[CMD]` - Shell commands being executed (impdp, expdp, sqlplus)
- `[SQL]` - SQL statements being executed
- `[BLOCK]` - Blocking operations (timeouts, waits, confirmations)
- `[PROGRESS]` - Progress tracking (X/Y with percentage)
- `[LOCK]` - Lock file acquisition/release

### Example Output
```
[2026-01-13 14:30:45] [INFO] Executando batch de 3 scripts SQL
[2026-01-13 14:30:45] [PROGRESS] [1/3] (33%) grants.sql
[2026-01-13 14:30:45] [SQL] Executing script: grants.sql (/path/to/grants.sql)
[2026-01-13 14:30:46] [CMD] sqlplus -S ***@*** @grants.sql
[2026-01-13 14:30:48] [SQL] → OK
[2026-01-13 14:30:48] [CMD] ✓ sqlplus completed (3s)
[2026-01-13 14:30:48] [SUCCESS] SQL concluido: grants.sql (3s)
```

## Module Details

### logging.sh (Base Module)
No dependencies. Provides all logging functions.

```bash
# Basic logging
log "message"                    # [INFO] message
warn "message"                   # [WARN] message (yellow, stderr)
die "message"                    # [FATAL] message (red, exit 1)
log_debug "message"              # [DEBUG] message (if LOG_LEVEL >= 3)
log_success "message"            # [SUCCESS] message (green)
log_error "message"              # [ERROR] message (red, stderr)

# Command logging
log_cmd "sqlplus" "args..."      # [CMD] sqlplus args...
log_cmd_start "impdp" "desc"     # [CMD] ▶ impdp - desc
log_cmd_end "impdp" 0 "45s"      # [CMD] ✓ impdp completed (45s)

# SQL logging
log_sql "SELECT" "query..."      # [SQL] SELECT: query...
log_sql_file "name" "/path"      # [SQL] Executing script: name (/path)
log_sql_result 0 "result"        # [SQL] → Result: result

# Blocking operations
log_block_start "WAIT" "desc"    # [BLOCK] ⏳ WAIT: desc
log_block_end "WAIT" "desc"      # [BLOCK] ✓ WAIT: desc
log_confirm "question" "YES"     # [CONFIRM] question [type: YES]
log_lock "ACQUIRE" "/path"       # [LOCK] Acquiring lock: /path

# Progress tracking
log_progress 5 10 "desc"         # [PROGRESS] [5/10] (50%) desc
log_step 3 "Validating..."       # >> Step 3: Validating...
log_phase "A" "Discovery"        # ══ PHASE A: Discovery ══

# Output formatting
runtime_print_kv "Key" "Value"   # Aligned key: value
runtime_print_vars "Title" ...   # Box with title and values
log_summary_table "Title" ...    # Summary table with borders
```

### core.sh (Central Loader)
Depends on: `logging.sh`, auto-loads `runtime.sh` and can load other modules via `core_require`

```bash
# Load core-managed modules on demand
core_require config report queue

# Unified initialization with config profiles
core_setup_all --logdir "/var/log/app" --logbase "app" \
               --session-dir "/var/log/app" --queue-max 8 \
               --config-profile dev --validate-config \
               --enable-err-trap

# Module management
core_list_modules              # List registered modules
core_module_info "config"      # Show module details
core_get_loaded_modules        # List currently loaded modules
```

### config.sh (Hierarchical Config + Validation)
Depends on: `runtime.sh`

```bash
# Load config hierarchically: defaults → global → local → env
config_load_hierarchical "app" "/etc/app.conf" "./config/app.conf"

# Load with profile detection
config_load_with_profile "app" "./config"

# Schema validation
config_register_schema "PORT" "uint" "1" "8080" ""
config_register_schema "MODE" "enum" "1" "prod" "dev prod test"
config_validate_schema

# Utilities
config_log_loaded              # List loaded config files
config_print_schema            # Show registered schemas
```

### runtime.sh (Shared Utilities)
Depends on: `logging.sh`

```bash
# Command validation
need_cmd "impdp"                 # Die if command not found
require_cmds "impdp" "expdp"     # Die if any command not found
has_cmd "sqlplus"                # Return 0 if command exists

# Validators
rt_assert_nonempty "VAR" "$VAR"  # Die if empty
rt_assert_abs_path "PATH" "$P"   # Die if not absolute path
rt_assert_dir_exists "DIR" "$D"  # Die if dir not exists
rt_assert_file_exists "F" "$F"   # Die if file not exists
rt_assert_bool01 "FLAG" "$F"     # Die if not 0 or 1
rt_assert_uint "NUM" "$N"        # Die if not unsigned int

# Lock files
runtime_lock_file "/path.lock"   # Acquire lock (die on fail)
runtime_unlock_file "/path.lock" # Release lock

# Retry and timeout
runtime_retry 3 5 cmd args...    # Retry 3 times, 5s delay
runtime_timeout 300 cmd args...  # Run with 5min timeout

# Filesystem
runtime_fs_available_gb "/path"  # Available GB on mount
runtime_ensure_dir "/path"       # mkdir -p with error handling

# NOTE: Interactive confirmations (pause, confirm_token, etc.)
# have been moved to report.sh as part of the unified workflow system.
# Use: report_confirm, report_select, report_preview_exec
```

### report.sh (Unified Workflow & Reporting)
Depends on: `logging.sh`, `runtime.sh`

Unified workflow orchestration system that integrates step tracking, interactive confirmations,
and dual output (console real-time + file report). Replaces scattered pause/confirm patterns.

```bash
# Initialization (once per script)
report_init "RMAN Restore" "/var/log/myapp" "session_id"
report_meta "ORACLE_SID" "${ORACLE_SID}"   # Add metadata

# Workflow Structure
report_phase "Validation & Discovery"       # Major phase with separator
report_section "Checking prerequisites"     # Minor section
report_step "Validating parameters"         # Tracked step with timing
report_step_done 0                          # Mark step complete (0=success)
report_step_done 1 "ORA-12154"              # Mark step failed with detail

# Items and Metrics
report_item ok "01_metadata.par" "1234 rows"      # ok, fail, skip, warn
report_item fail "02_stage.par" "ORA-00054"
report_metric "total_rows" 1234 add               # add, max, min, set

# Interactive Confirmations (respects REPORT_AUTO_YES)
if report_confirm "Execute restore?" "YES"; then
    # user confirmed
fi
report_confirm_retype "Confirm db_name" "PRODDB"  # Require retyping value

# Selection Menu
choice=$(report_select "Choose mode:" "FULL" "PARTIAL" "VALIDATE")

# Preview + Confirm + Execute (replaces oracle_rman_step_confirm)
report_preview_exec "${CMD_FILE}" rman cmdfile="${CMD_FILE}" log="${LOG}"

# Display Utilities
report_kv "ORACLE_HOME" "${ORACLE_HOME}"   # Key-value aligned
report_kv "PASSWORD" "${PASS}" mask        # Masked value
report_vars "Config" "KEY1=val1" "KEY2=val2"  # Variable block
report_table "Results" "Col1|Col2" "val1|val2"  # Formatted table

# Summary and Finalization
report_summary "Migration Complete"         # Console summary
report_finalize markdown                   # Generate console + file report

# Configuration Variables
REPORT_AUTO_YES=1      # Skip all confirmations
REPORT_AUTO_NO=1       # Fail all confirmations
REPORT_OUTPUT_FORMAT="md"  # md, json, text

# Generic Output Analysis
count=$(report_count_pattern "/path/to/file" "pattern")     # Count occurrences
sum=$(report_extract_numbers "/path/to/file" "\\d+" "sum")  # sum|max|min|avg|first|last
report_has_pattern "/path/to/file" "ORA-" && echo "Has errors"
value=$(report_extract_value "/path/to/file" "KEY:" ":")    # Extract value after key
mapfile -t cols < <(report_parse_delimited "/path/to/file" "|" 2)  # Parse column

# SQL Output Analysis (discovery map format: --SECTION-- then key|value)
sections=$(report_sql_count_sections "/path/to/file")
entries=$(report_sql_section_count "/path/to/file" "DATAFILES")
report_sql_validate_discovery "/path/to/file" && echo "Valid"
report_sql_summary "/path/to/file"              # Print summary stats

# Data Pump Log Analysis (domain-specific)
rows=$(report_dp_count_rows "/path/to/log")
secs=$(report_dp_extract_duration "/path/to/log")
report_dp_has_errors "/path/to/log" && echo "Has errors"
status=$(report_dp_get_status "/path/to/log")  # SUCCESS, WITH_ERRORS, UNKNOWN
tables=$(report_dp_count_tables "/path/to/log")
mbps=$(report_dp_get_throughput "/path/to/log")
```

### oracle_core.sh (Base Oracle Module)
Depends on: `runtime.sh`

Foundation module for all Oracle operations. Provides ORACLE_HOME validation and binary discovery.

```bash
# Validate Oracle environment
oracle_core_validate_oracle_home              # Check ORACLE_HOME, binaries

# Oratab validation
oracle_core_check_oratab_mismatch "SID" || true  # Warn if SID not in /etc/oratab
```

### oracle_sql.sh (SQL Execution)
Depends on: `oracle_core.sh`, `runtime.sh`

Unified SQL execution via sqlplus with retry, timeout, and structured logging.

```bash
# Execute SQL scripts
oracle_sql_execute_file "script.sql" [--log FILE] [--timeout SECS] [--retry N]
oracle_sql_execute_batch "s1.sql" "s2.sql" ...     # Execute batch

# Connection testing
oracle_sql_test_connection ["conn"] [timeout] [retry]  # Test connectivity

# Queries
result=$(oracle_sql_query "SELECT ...")                              # Query returning value
result=$(oracle_sql_query_timeout "SELECT ..." "conn" 30 "desc")     # Query with timeout
num=$(oracle_sql_query_numeric "SELECT COUNT(*) ..." "conn" 30)      # Query expecting number
oracle_sql_run "TRUNCATE TABLE x"                                    # Execute DDL/DML

# SYSDBA execution (local, no password)
oracle_sql_sysdba_exec "shutdown abort;"                   # Execute as SYSDBA
oracle_sql_sysdba_exec_verbose "sql" "description"         # Execute with full logging
oracle_sql_sysdba_exec_sid "SID" "sql"                     # Execute on specific SID
oracle_sql_sysdba_file "/path/to/script.sql" "description" # Execute file as SYSDBA
oracle_sql_sysdba_query "SELECT status FROM v\$instance;"  # Query as SYSDBA

# SYSDBA SID-specific operations (for instance management)
oracle_sql_sysdba_query_sid "SID" "SELECT status ..."      # Query with specific SID
oracle_sql_sysdba_ping_sid "SID"                           # Ping instance (returns 0/10/11)
oracle_sql_sysdba_exec_sid_capture out "SID" "sql"         # Execute with output capture
oracle_sql_sysdba_exec_sid_timeout out "SID" "sql" 300     # Execute with timeout

# Spool operations (output to file)
oracle_sql_spool "/path/to/output.txt" "SELECT ..."        # Spool to file
oracle_sql_spool_sid "SID" "/path/out.txt" "SELECT ..."    # Spool with specific SID
oracle_sql_spool_formatted "/path/out.txt" "sql" 0 500     # Formatted spool (pages, lines)

# Structured output operations
mapfile -t rows < <(oracle_sql_query_to_array "SELECT ...")  # Query to array
oracle_sql_query_delimited "SELECT a,b FROM t" "|"           # Delimited output (a|b)

# Output parsing utilities
mapfile -t files < <(oracle_sql_parse_section "file" "DATAFILES")  # Parse section
count=$(oracle_sql_count_section "file" "DATAFILES")               # Count entries
value=$(oracle_sql_parse_kv "file" "key")                          # Parse key|value
oracle_sql_validate_output "file" "pattern" 5                      # Validate min matches

# Utilities
oracle_sql_set_connection "user" "pass" "tns"       # Set CONNECTION var
```

### oracle_config.sh (Configuration Operations)
Depends on: `oracle_core.sh`, `oracle_sql.sh`

PFILE operations, memory sizing, path resolution, and filesystem checks.

```bash
# PFILE operations
db=$(oracle_config_pfile_parse_db_name "/tmp/init.ora")
val=$(oracle_config_pfile_parse_param "/tmp/init.ora" "sga_target")
oracle_config_pfile_write_bootstrap "out.ora" "8G" "4G" "DBUNQ" "/base" "/admin" "/ctl"
oracle_config_pfile_sanitize "src.ora" "dst.ora" "DB" "DBUNQ" "8G" "4G" "FS" "/base" "/admin" "/ctl" "+DATA" "+RECO"

# Memory sizing (auto-calculate or use overrides)
read -r sga pga < <(oracle_config_memory_calc_sga_pga [sga_override] [pga_override] [sga_pct] [pga_pct])

# Space checks
avail=$(oracle_config_fs_available_gb "/path")
oracle_config_space_check "/dest" [margin_pct] [db_size_gb] [extra_gb]

# Path resolution (sets ADMIN_DIR, DATA_DIR, FRA_DIR, CONTROL_DIR)
oracle_config_paths_resolve "FS" "/oracle" "DBUNQ" "+DATA" "+RECO"
```

### oracle_cluster.sh (RAC/Clusterware)
Depends on: `oracle_core.sh`, `oracle_sql.sh`

RAC detection and srvctl integration for clustered environments.

```bash
# Clusterware detection
oracle_cluster_detect_clusterware && echo "srvctl found"

# RAC database detection
oracle_cluster_is_rac && echo "RAC database"

# Get srvctl path
srvctl_path=$(oracle_cluster_get_srvctl_path)
```

### oracle_env.sh (Environment Setup)
Depends on: `oracle_core.sh`, `config.sh`

Oracle environment setup and configuration loading.

```bash
# Load Oracle configuration
oracle_env_load_config "restore" "/path/to/config"

# Validate environment variables
oracle_env_validate  # Checks ORACLE_HOME, ORACLE_SID, ORACLE_BASE, ORACLE_UNQNAME

# Set ORACLE_SID with validation
oracle_env_set_sid "PRODDB" "PRODDB_UNQNAME"

# Print current environment
oracle_env_get_info
```

### oracle_instance.sh (Instance Lifecycle)
Depends on: `oracle_core.sh`, `oracle_sql.sh`, `oracle_cluster.sh`

Instance state detection and lifecycle management. Uses srvctl when Clusterware is available.

```bash
# List running instances
oracle_instance_list_active_sids | while read sid; do echo "Found: $sid"; done

# Instance state detection
state=$(oracle_instance_get_state)  # DOWN, UP, or ZOMBIE
oracle_instance_is_target_pmon_running && echo "PMON running"
oracle_instance_sysdba_ping [sid]   # 0=UP, 10=NOT_STARTED, 11=ERROR

# Instance lifecycle (uses srvctl if available)
oracle_instance_startup_nomount "/tmp/init.ora" [db_unique_name] [instance_name]
oracle_instance_shutdown_abort [db_unique_name] [instance_name]
oracle_instance_stop [sid]

# Guard functions
oracle_instance_ensure_down "$ALLOW_CLEANUP" "$AUTO_YES"

# RAC information
inst_num=$(oracle_instance_get_number)
thread=$(oracle_instance_get_thread_number)
undo_ts=$(oracle_instance_get_undo_tablespace)
```

### oracle_datapump.sh (Data Pump Operations)
Depends on: `oracle_core.sh`, `oracle_sql.sh`, `config.sh`, `report.sh`

```bash
# Command discovery
dp_discover_commands             # Find impdp/expdp, set PATH

# SCN management
scn=$(dp_get_scn "conn" "link" "fallback")
scn=$(dp_get_scn_from_link "conn" "link")

# Parfile management
dp_list_parfiles "/dir"          # List .par files sorted
dp_parfile_has_content "f.par"   # Check for CONTENT=
dp_parfile_has_query "f.par"     # Check for QUERY=
dp_create_temp_parfile_without_query "f.par"
dp_cleanup_temp_parfiles "/dir"

# Execution
dp_execute_import_networklink "conn" "par" "link" "scn" "dir" "log"
dp_execute_export_oci "conn" "par" "url" "cred" "scn" "log"
dp_execute_import_oci "conn" "par" "url" "cred" "log"

# Monitoring
dp_monitor_job "pid" "conn" "job" "log" 60 10 "kill"
dp_attach_get_status "conn" "job" "out"
dp_attach_kill_job "conn" "job" "out"
```

### oracle_rman.sh (RMAN Operations)
Depends on: `oracle_core.sh`, `oracle_sql.sh`

```bash
# RMAN execution
oracle_rman_exec_cmdfile "/tmp/restore.rcv" "/tmp/restore.log"
oracle_rman_exec_verbose "/tmp/restore.rcv" "/tmp/restore.log" "Restore SPFILE"

# Channel management
oracle_rman_channels_alloc       # Generate ALLOCATE CHANNEL commands
oracle_rman_channels_release     # Generate RELEASE CHANNEL commands
oracle_rman_auto_channels        # Auto-set RMAN_CHANNELS based on CPUs

# Command file generation
oracle_rman_write_cmdfile_run "/tmp/cmd.rcv" "DBID" "post_commands" <<< "rman_body"

# Interactive workflow
oracle_rman_step_confirm "/tmp/cmd.rcv" "/tmp/cmd.log" "Execute restore?"

# Backup discovery
oracle_rman_backup_discover "/backup/rman"  # Sets BKPFULL, AUTO, BKPARCH, DBID
dbid=$(oracle_rman_detect_dbid_unique_in_autobackup "/backup/autobackup")

# Discovery map generation
oracle_rman_generate_discovery_map "/tmp/discovery.txt"
oracle_rman_print_discovery_summary
oracle_rman_print_transformation_plan

# Datafile/tempfile/redo rename commands
oracle_rman_build_newname_lines_from_disc      # SET NEWNAME for datafiles/tempfiles
oracle_rman_build_redo_rename_commands_from_disc  # ALTER DATABASE RENAME FILE for redo
```

## Configuration Variables

### Logging
```bash
LOG_LEVEL=2                  # 0=quiet, 1=normal, 2=verbose, 3=debug
LOG_SHOW_TIMESTAMP=1         # Include timestamp in output
LOG_SHOW_CMD=1               # Show [CMD] messages
LOG_SHOW_SQL=1               # Show [SQL] messages
LOG_SHOW_BLOCK=1             # Show [BLOCK] messages
LOG_SHOW_CONTEXT=0           # Show [module:func:line] context
LOG_STRUCTURED=0             # Output JSON format
NO_COLOR=                    # Set to disable ANSI colors
```

### Configuration (v4.1+)
```bash
CONFIG_PROFILE=prod          # Profile: dev, prod, test
# Profiles loaded from config/profiles/{profile}.conf
```

### SQL Execution
```bash
SQLPLUS_CMD=sqlplus          # Path to sqlplus
SQL_CONTINUE_ON_ERROR=0      # 0=stop on error, 1=continue
SQL_DEFAULT_TIMEOUT=0        # Default timeout (0=none)
CONNECTION=user/pass@tns     # Connection string
```

### Data Pump
```bash
IMPDP_CMD=impdp              # Path to impdp
EXPDP_CMD=expdp              # Path to expdp
DP_PARALLEL_DEGREE=5         # Default parallelism
DP_TABLE_EXISTS_ACTION=REPLACE
DP_LOGTIME=ALL
DP_METRICS=Y
ORACLE_CLIENT_HOME=          # Oracle client installation
```

## Naming Conventions

### Function Names
- `prefix_verb_noun()` - e.g., `dp_get_scn()`, `oracle_sql_execute_batch()`
- Module prefixes: `log_`, `rt_`, `runtime_`, `oracle_sql_`, `dp_`, `oracle_oci_`, `oracle_core_`, `oracle_instance_`, `oracle_config_`, `oracle_cluster_`, `oracle_rman_`, `oracle_env_`

### Guard Variables
- `__MODULE_LOADED` - e.g., `__LOGGING_LOADED`, `__DATAPUMP_LOADED`

### Private Variables
- `_MODULE_VAR` - e.g., `_LIB_DIR`, `_SQLEXEC_LIB_DIR`

## Usage Examples

### Modern Approach (v4.2+): Using oracle.sh Unified Loader

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source unified Oracle loader (auto-loads all Oracle modules)
LIB_DIR="$(cd "$(dirname "$0")/lib" && pwd)"
source "${LIB_DIR}/oracle.sh"

# Validate Oracle environment
oracle_core_validate_oracle_home
oracle_env_validate

# Check if RAC environment
if oracle_cluster_is_rac; then
    log "Running in RAC environment"
    inst_num=$(oracle_instance_get_number)
    thread=$(oracle_instance_get_thread_number)
fi

# Instance operations (uses srvctl automatically if available)
state=$(oracle_instance_get_state)
if [[ "$state" != "DOWN" ]]; then
    oracle_instance_shutdown_abort
fi

oracle_instance_startup_nomount "/tmp/init.ora"

# PFILE operations
read -r sga pga < <(oracle_config_memory_calc_sga_pga)
oracle_config_pfile_write_bootstrap "/tmp/bootstrap.ora" "$sga" "$pga" \
    "DBUNQ" "/oracle" "/oracle/admin/DBUNQ/adump" "/oracle/oradata/DBUNQ"
```

### Data Pump Migration Example

```bash
#!/usr/bin/env bash
set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/lib" && pwd)"
source "${LIB_DIR}/oracle_datapump.sh"  # Auto-loads dependencies

# Configuration
LOG_LEVEL=3
CONNECTION="admin/***@mydb"

# Use library functions
dp_discover_commands
oracle_sql_test_connection

scn=$(dp_get_scn "$CONNECTION" "DBLINK_SOURCE" "12345678")

log_phase "1" "Import Phase"
dp_execute_import_networklink \
    "$CONNECTION" \
    "parfiles/01_metadata.par" \
    "DBLINK_SOURCE" \
    "$scn" \
    "DATA_PUMP_DIR" \
    "logs/01_metadata.log"

log_summary_table "RESULT" "Status|SUCCESS" "Duration|5m 30s"
```

### RMAN Restore Example

```bash
#!/usr/bin/env bash
set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/lib" && pwd)"
source "${LIB_DIR}/oracle_rman.sh"  # Auto-loads dependencies

# Set environment
export ORACLE_SID="RESTORE"
export ORACLE_UNQNAME="RESTORE"

# Discover backups and get DBID
oracle_rman_backup_discover "/backup/rman" || die "Backup not found"
oracle_rman_auto_channels

# Ensure instance is down before restore
oracle_instance_ensure_down "$ALLOW_CLEANUP" "$AUTO_YES"

# Start instance in NOMOUNT
oracle_instance_startup_nomount "/tmp/init.ora"

# Generate discovery map and build rename commands
oracle_rman_generate_discovery_map "/tmp/discovery.txt"
oracle_rman_print_discovery_summary
oracle_rman_print_transformation_plan
```

### Using core.sh Module System

```bash
#!/usr/bin/env bash
set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/lib" && pwd)"
source "${LIB_DIR}/core.sh"

# Load specific modules as needed
core_require config queue report
core_load oracle  # Loads all Oracle modules

# Full initialization
core_setup_all --logdir "/var/log/app" --logbase "restore" \
               --session-dir "/var/log/app" --enable-err-trap

# List loaded modules
core_get_loaded_modules
```

## Testing

```bash
# Syntax validation
for f in scripts/lib/*.sh; do
    bash -n "$f" && echo "✅ $f" || echo "❌ $f"
done

# Load test via oracle.sh (recommended)
cd scripts && bash -c '
  source lib/oracle.sh
  type -t oracle_core_validate_oracle_home
  type -t oracle_sql_exec
  type -t oracle_config_memory_calc_sga_pga
  type -t oracle_cluster_is_rac
  type -t oracle_instance_get_state
  echo "✅ All Oracle modules loaded via oracle.sh"
'

# Load test via core.sh
cd scripts && bash -c '
  source lib/core.sh
  core_require runtime config queue report
  core_load oracle
  core_get_loaded_modules
  echo "✅ All libs loaded via core.sh"
'

# Load individual Oracle modules
cd scripts && bash -c '
  source lib/oracle_core.sh
  source lib/oracle_sql.sh
  source lib/oracle_config.sh
  source lib/oracle_cluster.sh
  source lib/oracle_instance.sh
  echo "✅ Individual Oracle modules loaded"
'

# Test RAC/Clusterware detection
cd scripts && bash -c '
  SKIP_ORACLE_CMDS=1  # Skip actual Oracle commands in test
  source lib/oracle.sh
  oracle_cluster_detect_clusterware && echo "srvctl found" || echo "srvctl not found"
  echo "RAC detection test completed"
'
```

## Report.sh Integration

The `report.sh` module provides comprehensive operation tracking with zero overhead when disabled. All Oracle library modules are integrated with automatic step tracking, metrics accumulation, and timeline analysis.

### Module Integration Status

| Module | Status | Metrics | Items | Metadata |
|--------|--------|---------|-------|----------|
| oracle_datapump.sh | ✅ Integrated | dp_rows_imported, dp_tables_processed, dp_avg_throughput_mbps | Parfile imports | dp_parfile, dp_scn, dp_parallel_degree |
| oracle_sql.sh | ✅ Integrated | sql_scripts_executed, sql_successful, sql_failed | Script executions | sql_script, sql_timeout_enabled |
| oracle_rman.sh | ✅ Integrated | rman_transformations_total, rman_datafiles, rman_channels_used | File transformations | rman_dbid, rman_backup_root |
| oracle_env.sh | ✅ Integrated | env_initialized, env_validations_passed, env_validations_failed | Config/validation steps | env_config_file, env_logs_dir |
| oracle_config.sh | ✅ Integrated | config_db_size_gb, config_paths_resolved, config_dirs_created | Directory creations | config_required_gb, config_available_gb |
| oracle_cluster.sh | ✅ Integrated | cluster_detected, cluster_rac, cluster_node_count | Detection results | cluster_type, cluster_db_type |
| oracle_instance.sh | ✅ Integrated | instance_startups, instance_shutdowns, instance_duration | Instance operations | instance_state, instance_thread |

### Tracking Capabilities

```bash
# Enable operation tracking
report_init "Migration Session" "/var/log/migration"

# All operations automatically track start/end with metrics
source lib/oracle.sh

# Data Pump operations: dp_rows_imported, dp_tables_processed, etc.
dp_execute_import_networklink "$connection" "parfile.par" "log.txt"

# SQL operations: sql_scripts_executed, sql_successful, etc.
oracle_sql_execute_batch "scripts/*.sql"

# RMAN operations: rman_transformations_total, rman_datafiles, etc.
oracle_rman_init_transformation

# Configuration operations: config_paths_resolved, config_dirs_created, etc.
oracle_config_resolve_paths "$source" "$target"

# Generate comprehensive report with metrics and timeline
report_finalize

# Query metrics for analysis
local total_rows=$(report_metric_aggregate "dp_*" "sum")
local critical=$(report_query_critical_path 10)
local timeline=$(report_query_timeline)
```

### Integration Pattern

All modules follow a consistent 3-line tracking pattern:

```bash
# START: Track operation beginning
report_track_step "Operation: ${description}"

# ... perform work ...

# END: Track operation completion with metrics
report_track_step_done ${exit_code} "detail"
report_track_item "ok|fail" "item_name" "item_detail"
report_track_metric "module_metric_name" "value" "add|set|max"
```

### Key Features

- **Zero Overhead Without Tracking**: All `report_track_*` calls NO-OP when report not initialized
- **Graceful Degradation**: Functions work identically with or without `report_init()`
- **Pattern-Based Aggregation**: All metrics use `module_*` naming for easy filtering
- **Comprehensive Metrics**: ~30 metrics tracked across 6 core Oracle modules
- **Timeline Analysis**: Chronological view of all operations with timestamps
- **Critical Path**: Automatic identification of slowest operations
- **Module-Specific Reports**: Markdown output with dedicated sections per module

### Usage Example

```bash
#!/bin/bash
set -e

source lib/report.sh
source lib/oracle.sh

# Initialize tracking (optional - operations work without this too)
report_init "Oracle Migration" "/var/log/migration_$(date +%s)"

# Operations are tracked automatically
report_track_phase "Discovery Phase"
oracle_env_init --config config.conf --require-sid

report_track_phase "Backup Phase"
oracle_rman_backup_discover "$discovery_file"

report_track_phase "Import Phase"
dp_execute_batch_parallel "parfiles" 4

# Generate report with all metrics and timeline
report_finalize

# Analyze performance
echo "Critical Path (slowest 5 operations):"
report_query_critical_path 5

echo "Total rows imported:"
report_metric_aggregate "dp_*" "sum"
```

### Query Functions

```bash
# Aggregate metrics by pattern
report_metric_aggregate "dp_*" "sum"        # Sum all dp_* metrics
report_metric_aggregate "sql_*" "count"     # Count sql_* operations
report_metric_aggregate "*_duration" "max"  # Max duration across all modules

# Generate timeline
report_query_timeline                       # Chronological view of all operations

# Find critical path
report_query_critical_path 10               # Show 10 slowest operations

# Metric summary
report_query_metric_summary                 # Display all tracked metrics
```

### See Also

- **REPORT_INTEGRATION_GUIDE.md** - Detailed integration guide for adding report tracking to new modules
- **lib/report.sh** - Full implementation with 7 internal sections
- **tests/test_report_integration.sh** - 12 integration tests validating all tracking functionality

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 4.3.0 | 2026-01-15 | **Comprehensive Report.sh Integration**: Integrated all 6 core Oracle modules (datapump, sql, rman, env, config, cluster) with report.sh operation tracking. Added 4 query functions (metric_aggregate, query_timeline, query_critical_path, query_metric_summary). Enhanced markdown output with module-specific metric sections. Added 12 integration tests validating graceful degradation. Created REPORT_INTEGRATION_GUIDE.md with patterns for future modules. Zero overhead when disabled, full audit trail and performance metrics when enabled. |
| 4.2.0 | 2026-01-15 | **Oracle Module Reorganization**: Split into specialized modules (oracle_core.sh, oracle_sql.sh, oracle_config.sh, oracle_cluster.sh, oracle_env.sh, oracle_instance.sh). Added RAC/Clusterware support with srvctl integration. Renamed oracle_sqlexec.sh → oracle_sql.sh, oracle_runtime.sh → oracle_instance.sh. Added unified oracle.sh loader. Better separation of responsibilities. |
| 4.1.0 | 2026-01-15 | Logging context capture, structured JSON output, module-level log control, hierarchical config, schema validation, profile system |
| 4.0.0 | 2026-01-15 | Complete reorganization: generic module system, dependency resolution, no circular dependencies |
| 2.0.0 | 2026-01-13 | Structured logging, oracle_sqlexec.sh module, consolidated core.sh |
| 1.0.0 | 2026-01-12 | Initial modular library architecture |

## Migration Guide: v4.1 → v4.2

### Function Renames

| Old Function | New Function | Module |
|--------------|--------------|--------|
| `oracle_sqlplus_exec` | `oracle_sql_sysdba_exec` | oracle_sql.sh |
| `oracle_sqlplus_query` | `oracle_sql_sysdba_query` | oracle_sql.sh |
| `oracle_sqlplus_exec_with_sid` | `oracle_sql_sysdba_exec_sid` | oracle_sql.sh |
| `oracle_sqlplus_file` | `oracle_sql_sysdba_file` | oracle_sql.sh |
| `oracle_write_bootstrap_pfile` | `oracle_config_pfile_write_bootstrap` | oracle_config.sh |
| `oracle_sanitize_pfile` | `oracle_config_pfile_sanitize` | oracle_config.sh |
| `oracle_get_instance_state` | `oracle_instance_get_state` | oracle_instance.sh |
| `oracle_startup_nomount` | `oracle_instance_startup_nomount` | oracle_instance.sh |
| `oracle_shutdown_abort` | `oracle_instance_shutdown_abort` | oracle_instance.sh |

### Removed Modules

| Old Module | Status |
|------------|--------|
| `oracle_sqlexec.sh` | Removed - use `oracle_sql.sh` |
| `oracle_runtime.sh` | Deprecated - use `oracle_instance.sh` for instance management |

### New Features

- **RAC Support**: `oracle_cluster_is_rac`, `oracle_cluster_detect_clusterware`
- **srvctl Integration**: `oracle_instance_startup_nomount` and `oracle_instance_shutdown_abort` automatically use srvctl when Clusterware is detected
- **Instance Information**: `oracle_instance_get_number`, `oracle_instance_get_thread_number`, `oracle_instance_get_undo_tablespace`
- **Unified Loader**: `source lib/oracle.sh` loads all Oracle modules
