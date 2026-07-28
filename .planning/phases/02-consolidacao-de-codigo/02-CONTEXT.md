# Phase 2: Consolidação de Código - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Eliminate code duplication in lib/*.sh — merge core.sh/runtime.sh into a single module, extract oracle_sql.sh helpers to reduce boilerplate, and add unified binary discovery. Oracle-specific code stays in dcx-oracle plugin.

</domain>

<decisions>
## Implementation Decisions

### core.sh/runtime.sh Merge Strategy
- Merge runtime.sh content INTO core.sh (delete runtime.sh after)
- Update all callers immediately (no shim, no deprecated wrappers)
- Change function prefix from runtime_ to core_
- Rename ALL calls to use core_ prefix across all scripts
- Keep module guard pattern (_DCX_CORE_LOADED)
- core.sh exports explicit list of public API functions
- core.sh loads its own dependencies (logging.sh, shared.sh, constants.sh)
- No init function needed — just sourcing the file is enough

### oracle_sql.sh Helper Extraction
- Extract BOTH execution wrappers and result parsing helpers
- Keep oracle_sql_* prefix for all functions
- Oracle code stays in dcx-oracle plugin (not core dcx)
- Target: any meaningful reduction (not specific 50% target)

### Binary Discovery Consolidation
- Claude decides function name based on usage patterns
- Support ALL binaries: dcx binaries AND Oracle binaries (sqlplus, rman, expdp, impdp, etc.)
- Search order: ORACLE_HOME/bin first for Oracle tools, then DCX_HOME/bin, then PATH
- If not found: print warning, return empty string (caller handles missing binary)

### Breaking Change Policy
- Breaking changes allowed freely (internal refactoring)
- No deprecation warnings needed
- Refactor first, then fix callers (two-phase within same PR)
- Update tests WITH code changes to keep them passing
- Validation: both bash -n syntax check AND make test must pass

### Code Quality & Documentation
- One commit per logical change (not one big commit)
- Update README/docs to stay in sync with code changes
- Follow existing code style + shellcheck compliance

### Claude's Discretion
- Binary discovery function naming
- Exact helper extraction patterns
- Search path implementation details

</decisions>

<specifics>
## Specific Ideas

- Oracle plugin code must stay in dcx-oracle, not move to core dcx
- core.sh should be the single entry point for all library functionality
- Module guards prevent double-sourcing issues

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-consolidacao-de-codigo*
*Context gathered: 2026-02-01*
