# Phase 3: Refatoração de Testes - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Unify the test framework in test_helpers.sh and convert all test_*.sh files to use it consistently. Target: reduce test code duplication by ~38% while maintaining or improving test coverage.

</domain>

<decisions>
## Implementation Decisions

### Test Framework API
- Hybrid pattern: use run_test for complex commands, assert_* for simple checks
- Keep basic assertion set: assert_eq, assert_ne, assert_contains, assert_match
- test_helpers.sh auto-sources lib/core.sh so tests only need to source test_helpers.sh
- Add describe blocks for grouping related tests within a file

### Test File Structure
- Keep 1:1 mapping: test_core.sh tests core.sh, etc.
- Tests executable both standalone AND via run_all_tests.sh
- Describe block pattern for grouping (like Jest/RSpec)

### Output and Reporting
- Show each test result as it runs (✓/✗ per test)
- Include per-file timing information
- Auto-detect colors (colors if terminal, plain otherwise)
- Exit 1 on any failure (CI-compatible)

### Migration Strategy
- Migrate all test files at once (not incremental)
- Add missing tests for untested functions found during refactoring
- No backward compatibility needed - break old patterns
- Validation: make test must pass AND test count matches or increases

### Claude's Discretion
- run_test implementation (eval vs direct execution)
- Setup/teardown pattern based on actual test needs
- Specific describe() block implementation

</decisions>

<specifics>
## Specific Ideas

- Describe blocks should feel familiar to developers used to Jest/RSpec
- Per-file timing helps identify slow test files
- Auto-sourcing core.sh reduces boilerplate in every test file

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-refatoracao-de-testes*
*Context gathered: 2026-02-01*
