# Phase 1: Bug Fixes Críticos - Execution Plan

**Phase Goal:** Corrigir bugs bloqueadores de produção
**Status:** PENDING
**Created:** 2026-02-01

## Requirements Mapped

| Beads ID | Title | Priority |
|----------|-------|----------|
| dcx-6dl | Fix oracle_rman.sh:324 unbound variable | P0 |
| dcx-5vo | RMAN catalog validation fix | P1 |
| dcx-cvz | Fix --resume-from=restore skip validate | P2 |

---

## Task 1: Fix Unbound Variable (dcx-6dl)

**Problem:** Production error "unbound variable $1" at oracle_rman.sh:324 when calling `report_kv`

**Root Cause:** `report.sh` functions (23 total) use naked `$1` access without validation, violating bash `set -u` mode

### Fix Pattern

Standard bash parameter validation:
```bash
local param="${1?ERROR: Missing required parameter: param_name}"
```

### Files to Modify

**dcx-oracle/lib/report.sh** - Core display functions (23 functions):
- Line 442: `report_kv()` - fix $1, $2
- Line 453: `report_vars()` - fix $1
- Line 476: `report_table()` - fix $1
- Line 563: `report_meta()` - fix $1, $2
- Line 579: `report_phase()` - fix $1
- Line 594: `report_section()` - fix $1
- Line 605: `report_step()` - fix $1
- Line 611: `report_step_done()` - fix $1
- Line 621: `report_item()` - fix $1, $2, $3
- Line 651: `report_metric()` - fix $1, $2
- Line 662: `report_confirm()` - fix $1, $2

**dcx-oracle/lib/logging.sh** - Core logging functions:
- `log_error()` - fix $1
- `log_warning()` - fix $1
- `log_info()` - fix $1

### Example Fix

```bash
# BEFORE (WRONG):
report_kv() {
    local key="$1"
    local value="$2"
    local mask="${3:-}"
    # ...
}

# AFTER (CORRECT):
report_kv() {
    local key="${1?ERROR: report_kv requires key}"
    local value="${2?ERROR: report_kv requires value}"
    local mask="${3:-}"
    # ...
}
```

### Verification

```bash
# Test parameter validation works
source lib/report.sh
report_kv  # Should error with clear message, not "unbound variable"

# Syntax check
bash -n lib/report.sh || echo "Syntax error!"
```

---

## Task 2: Fix RMAN Catalog Validation (dcx-5vo)

**Problem:** Script fails at line 613 validating RMAN catalog results

**Root Cause (2 issues):**
1. `grep -c` returns exit code 1 when no matches (fails with `set -e`)
2. Wrong search pattern - looks for "cataloged backup piece" but RMAN outputs "File Name:"

### Evidence

RMAN actual output:
```
List of Cataloged Files
=======================
File Name: /backup-prod/rman/RMAN_ARCH_LOCAL/PRD2/archivelogs/archarch_D-PRD_...
... (1480 files)
```

### Files to Modify

**dcx-oracle/commands/restore.sh** - Line ~613

### Fix

```bash
# BEFORE (WRONG):
cat_pieces=$(grep -c "cataloged backup piece" "${LOGDIR}/02b_catalog.log" 2>/dev/null | tr -d '[:space:]')
cat_copies=$(grep -c "cataloged datafile copy" "${LOGDIR}/02b_catalog.log" 2>/dev/null | tr -d '[:space:]')

# AFTER (CORRECT):
# Count "File Name:" entries - grep -c returns exit 1 when no matches, so use || true
cat_files=$(grep -c "^File Name:" "${LOGDIR}/02b_catalog.log" 2>/dev/null || true)
cat_files="${cat_files:-0}"
cat_total="${cat_files}"
```

### Verification

```bash
# Syntax check
bash -n restore.sh && echo "Syntax OK"

# Test grep pattern
grep -c "^File Name:" /path/to/02b_catalog.log || true
# Expected: number of cataloged files
```

---

## Task 3: Fix --resume-from=restore Skip Validate (dcx-cvz)

**Problem:** `DRY_RUN=0 --resume-from=restore` executes VALIDATE when it should skip

**Root Cause:** `phase_validate_and_restore()` always executes preview/validate, ignoring resume point

### Files to Modify

**dcx-oracle/commands/restore.sh** - Lines ~627-670

### Fix

Add skip check at start of `phase_validate_and_restore()`:

```bash
phase_validate_and_restore() {
    report_phase "Validate & Restore"

    # Skip preview/validate if --resume-from=restore or later
    local skip_validation=0
    [[ "${skip_to:-}" == "restore" || "${skip_to:-}" == "recover" ]] && skip_validation=1

    if [[ "${skip_validation}" == "0" ]]; then
        # Step: Preview
        report_step "Running restore preview"
        oracle_rman_exec_with_state "PREVIEW" ...

        # Step: Validate
        report_step "Running restore validate"
        oracle_rman_exec_with_state "VALIDATE" ...
    else
        log_info "[SKIP] Preview/Validate: Skipped due to --resume-from=${RESUME_FROM}"
    fi

    # Space check and restore continue normally
}
```

### Verification

```bash
# Test skip behavior
DRY_RUN=0 ORACLE_SID=RES ./restore.sh --resume-from=restore
# Expected: Skip preview → Skip validate → Execute RESTORE
```

---

## Execution Order

1. **Task 1 (dcx-6dl)** - First, as other scripts depend on report.sh/logging.sh
2. **Task 2 (dcx-5vo)** - Can run in parallel with Task 1
3. **Task 3 (dcx-cvz)** - After Task 1 (restore.sh uses report functions)

---

## Success Criteria

- [ ] All 23 report.sh functions have parameter validation
- [ ] All 3 core logging.sh functions have parameter validation
- [ ] grep catalog validation uses correct pattern with `|| true`
- [ ] --resume-from=restore skips preview/validate correctly
- [ ] All syntax checks pass: `bash -n <file>`
- [ ] DRY_RUN test passes for restore.sh
- [ ] No regressions in existing tests

---

## Risk Assessment

| Task | Risk | Mitigation |
|------|------|------------|
| Task 1 | Low | Pattern is standard bash, no behavior change |
| Task 2 | Very Low | grep pattern matches actual RMAN output |
| Task 3 | Low | Only affects resume behavior, not normal flow |

---

## Post-Implementation

After Phase 1 completes:
1. Run `bd close dcx-6dl dcx-5vo dcx-cvz` to close issues
2. Update STATE.md to move to Phase 2
3. Commit changes: `git commit -m "fix: resolve P0/P1/P2 bugs in restore.sh"`
