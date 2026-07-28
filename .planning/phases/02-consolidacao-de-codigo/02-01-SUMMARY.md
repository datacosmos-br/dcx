---
phase: 02-consolidacao-de-codigo
plan: 01
subsystem: library
tags: [bash, shell, core, runtime, module-system]

# Dependency graph
requires:
  - phase: 01-bug-fixes-criticos
    provides: Stable codebase with fixed parameter validation
provides:
  - core.sh with integrated runtime utilities (core_ prefix)
  - Unified module system without separate runtime.sh
  - core_spin() with _dc_find_binary for gum discovery
affects: [02-02, testing, plugin-system]

# Tech tracking
tech-stack:
  added: []
  patterns: [core_ prefix for runtime utilities]

key-files:
  created: []
  modified: [lib/core.sh]

key-decisions:
  - "All runtime functions renamed to core_ prefix (core_need_cmd, core_spin, etc.)"
  - "core_spin() uses _dc_find_binary for gum discovery instead of command -v"
  - "Module registry updated: removed runtime, config/parallel now depend on logging"

patterns-established:
  - "core_ prefix: All runtime utilities use core_ prefix for namespace clarity"
  - "Module consolidation: Related functionality merged into single module"

# Metrics
duration: 3min
completed: 2026-02-01
---

# Phase 2 Plan 1: Merge runtime.sh into core.sh Summary

**Runtime utilities merged into core.sh with core_ prefix - 11 functions (core_need_cmd, core_spin, core_retry, etc.) now available directly from core.sh**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-01T04:10:35Z
- **Completed:** 2026-02-01T04:13:00Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- All runtime functions (need_cmd, spin, retry, etc.) added to core.sh with core_ prefix
- core_spin() uses _dc_find_binary for gum discovery
- Module registry cleaned up - removed runtime module, updated dependencies

## Task Commits

Each task was committed atomically:

1. **Task 1: Merge runtime.sh content + Task 2: Validate integration** - `a0b35ae` (feat)

**Note:** Tasks 1 and 2 committed together as integration validation was part of merge verification

## Files Created/Modified
- `lib/core.sh` - Added RUNTIME UTILITIES section with 11 core_ prefixed functions

## Decisions Made
- All functions renamed to core_ prefix per CONTEXT.md decision
- core_spin() uses _dc_find_binary() instead of raw command -v for gum discovery
- config and parallel modules now depend on logging instead of runtime

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- core.sh is ready as unified entry point
- Plan 02-02 can proceed to update callers and delete runtime.sh
- All verification tests pass

---
*Phase: 02-consolidacao-de-codigo*
*Completed: 2026-02-01*
