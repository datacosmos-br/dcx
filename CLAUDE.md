# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Oracle automation scripts for RMAN restore/clone and Data Pump migrations. Written in Bash with a modular library system supporting dependency resolution, structured logging, and unified reporting.

## Key Commands

```bash
# Run all tests
cd tests && ./run_all_tests.sh

# Quick syntax validation only
cd tests && ./run_all_tests.sh --quick

# Run individual test suites
./tests/test_core.sh
./tests/test_runtime.sh
./tests/test_oracle.sh

# Syntax check a library
bash -n lib/oracle_sql.sh

# Test library loading
bash -c 'source lib/oracle.sh && type -t oracle_sql_sysdba_exec'
```

## Architecture

### Module System (lib/core.sh)

Three-layer loading with automatic dependency resolution:

```
Layer 0: logging.sh (no dependencies)
    └─> Layer 1: runtime.sh
            └─> Layer 2: core.sh (module loader)
                    └─> Layer 3: Optional modules (config, queue, report, oracle_*)
```

Load modules using:
```bash
source lib/core.sh
core_require runtime config queue report  # Generic modules
core_load oracle                          # Oracle unified loader (all oracle_* modules)
core_load oracle_rman                     # Or load specific Oracle modules
```

### Oracle Module Hierarchy

| Module | Purpose | Prefix |
|--------|---------|--------|
| oracle_core.sh | ORACLE_HOME validation, binary discovery | `oracle_core_*` |
| oracle_sql.sh | SQL execution via sqlplus | `oracle_sql_*` |
| oracle_config.sh | PFILE, memory sizing, paths | `oracle_config_*` |
| oracle_cluster.sh | RAC detection, srvctl | `oracle_cluster_*` |
| oracle_instance.sh | Instance lifecycle (start/stop) | `oracle_instance_*` |
| oracle_rman.sh | RMAN operations | `oracle_rman_*` |
| oracle_datapump.sh | Data Pump operations | `dp_*` |
| oracle_oci.sh | OCI Object Storage | `oci_*` |
| oracle.sh | Unified loader for all oracle_* | - |

### Main Scripts

- **restore.sh**: RMAN restore/clone from disk backup to FS or ASM. Supports:
  - Point-in-time recovery (`--until-time`, `--until-scn`)
  - Resume modes (`--continue`, `--resume-from`)
  - State tracking for DRY_RUN workflow (see below)
- **migrate_v2.sh**: Data Pump migrations via network link or OCI dumpfiles.

### State Tracking (restore.sh)

**DRY_RUN levels com state tracking:**
- `DRY_RUN=2`: Stop after config (read-only)
- `DRY_RUN=1`: Stop after validate (saves state to `${LOGDIR}/execution_state.sh`)
- `DRY_RUN=0`: Full restore (skips validated steps if state exists)

**Estado persistido:** `${LOGDIR}/execution_state.sh`
- Formato: bash source-able (key="value" per line)
- Variáveis salvas por step: COMPLETED, LOG, EXIT_CODE, DURATION, TIMESTAMP

**Example workflow:**
```bash
# 1. Validate first (saves state)
DRY_RUN=1 ./restore.sh
# Check validation logs
cat /tmp/restore_logs/*/03_preview.log
cat /tmp/restore_logs/*/04_validate.log

# 2. Execute restore (skips preview/validate from state)
DRY_RUN=0 ./restore.sh
# [INFO] [SKIP] Restore Preview: Already completed
# [INFO] [SKIP] Restore Validate: Already completed
# [RMAN] Executing: RESTORE DATABASE
```

**Documentation:** See [docs/STATE_TRACKING.md](docs/STATE_TRACKING.md) for complete details.

### Report System (lib/report.sh)

Unified workflow orchestration with dual output (console + markdown):

```bash
report_init "Operation Name" "/var/log/dir"
report_phase "Discovery"
report_step "Validating"
report_step_done 0
report_item ok "Config" "Loaded"
report_confirm "Proceed?" "YES"
report_finalize
```

## Configuration Variables

```bash
# Logging
LOG_LEVEL=2              # 0=quiet, 1=normal, 2=verbose, 3=debug
LOG_SHOW_CONTEXT=0       # Show [module:func:line] in logs

# SQL Execution
CONNECTION=user/pass@tns # Connection string
SQL_DEFAULT_TIMEOUT=0    # Default timeout (0=none)

# Report
REPORT_AUTO_YES=1        # Skip all confirmations
```

## Code Conventions

- Function naming: `module_verb_noun()` (e.g., `oracle_sql_execute_batch`)
- Guard variables: `__MODULE_LOADED` for double-source protection
- Private variables: `_MODULE_VAR` prefix
- All modules auto-load dependencies via core.sh registry
