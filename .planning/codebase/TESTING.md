# Testing Patterns

**Analysis Date:** 2026-01-31

## Test Framework

**Runner:**
- Custom bash testing framework (not external)
- Defined in: `tests/test_helpers.sh`
- Executed via: `bash tests/test_core.sh`, `bash tests/test_logging.sh`, etc.
- Master runner: `bash tests/run_all_tests.sh`

**Assertion Library:**
- Custom implementation in `tests/test_helpers.sh`
- Functions: `run_test()`, `assert_eq()`, `assert_true()`, `assert_file()`, etc.
- No external dependencies (pure bash)

**Run Commands:**
```bash
./tests/run_all_tests.sh         # Run all tests with aggregated summary
bash tests/test_core.sh          # Run single test suite
bash tests/test_helpers.sh       # (Skip - library only, not a test)
```

## Test File Organization

**Location:**
- Test files in: `tests/` directory
- Helper library: `tests/test_helpers.sh`
- Pattern: Co-located in same directory, one test file per library module

**Naming:**
- Pattern: `test_<module>.sh` where module matches `lib/<module>.sh`
- Examples: `test_core.sh` (for `lib/core.sh`), `test_logging.sh` (for `lib/logging.sh`)

**Structure:**
```
tests/
├── test_helpers.sh         # Shared testing framework
├── test_core.sh            # Tests for lib/core.sh
├── test_logging.sh         # Tests for lib/logging.sh
├── test_config.sh          # Tests for lib/config.sh
├── test_parallel.sh        # Tests for lib/parallel.sh
├── test_plugin.sh          # Tests for lib/plugin.sh
├── test_runtime.sh         # Tests for lib/runtime.sh
├── test_update.sh          # Tests for lib/update.sh
└── run_all_tests.sh        # Master test runner
```

## Test Structure

**Suite Organization:**
```bash
#!/usr/bin/env bash
#===============================================================================
# test_core.sh - Tests for lib/core.sh
#===============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

echo "Testing core.sh..."
echo ""

# Source the module under test
source "${LIB_DIR}/core.sh"

# Run individual tests
run_test "core.sh loads" "true"
run_test "DCX_VERSION is set" "[[ -n \"\${DCX_VERSION:-}\" ]]"
run_test "dc_init exists" "type dc_init &>/dev/null"

# Print summary
test_summary
```

**Patterns:**

1. **Module existence:**
   ```bash
   run_test "core.sh loads" "true"
   run_test "_DCX_CORE_LOADED set" "[[ -n \"\${_DCX_CORE_LOADED:-}\" ]]"
   ```

2. **Function/variable checks:**
   ```bash
   run_test "dc_version exists" "type dc_version &>/dev/null"
   run_test "DCX_VERSION is correct" "[[ \"\${DCX_VERSION}\" == \"0.0.1\" ]]"
   ```

3. **Behavior validation:**
   ```bash
   run_test "dc_version output" "[[ \"\$(dc_version)\" == \"dcx v0.0.1\" ]]"
   run_test "log_set_level works" "log_set_level debug && [[ \"\$DCX_LOG_LEVEL\" == \"debug\" ]]"
   ```

4. **Failure testing:**
   ```bash
   run_test "log_set_level rejects invalid" "! log_set_level invalid"
   run_test "parallel_run failure" "! parallel_run 2 'true' 'false' 'true'"
   ```

5. **File/directory operations:**
   ```bash
   run_test "log_init_file exists" "type log_init_file &>/dev/null"
   assert_file "${TMP_DIR}/output.txt" "Output file exists"
   assert_dir "${TMP_DIR}" "Directory exists"
   ```

## Mocking

**Framework:** None; tests use real functions

**Patterns:**
```bash
# Setup - Create mock data for testing
setup_test_plugin() {
    mkdir -p "$TEST_PLUGIN_DIR/test-plugin/lib"
    cat > "$TEST_PLUGIN_DIR/test-plugin/plugin.yaml" << 'EOF'
name: test-plugin
version: 1.0.0
EOF
}

cleanup_test_plugin() {
    [[ -n "$TEST_PLUGIN_DIR" && -d "$TEST_PLUGIN_DIR" ]] && rm -rf "$TEST_PLUGIN_DIR"
}

trap cleanup_test_plugin EXIT
```

**What to Mock:**
- External tools (gum, yq): Check function exists, not full behavior
- File system: Create temporary directories in test setup
- Plugin discovery: Create minimal mock plugin.yaml files

**What NOT to Mock:**
- Core module functions: Test with real functions
- Logging output: Test that functions exist and execute
- Shell builtins: Don't mock (e.g., `type`, `command -v`)

## Fixtures and Factories

**Test Data:**
```bash
# Temporary directory with automatic cleanup
test_setup() {
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT
}

# Mock plugin creation
setup_test_plugin() {
    mkdir -p "$TEST_PLUGIN_DIR/test-plugin/lib"
    cat > "$TEST_PLUGIN_DIR/test-plugin/plugin.yaml" << 'EOF'
name: test-plugin
version: 1.0.0
EOF
}

# Mock file creation for logging tests
write_file() {
    local name="$1"
    echo "$name" >> "${TMP_DIR}/output.txt"
}
```

**Location:**
- Fixtures created within test files: `setup_test_plugin()`, `test_setup()`
- Cleanup via trap: `trap 'rm -rf "$TMP_DIR"' EXIT`
- Temporary directories: `$(mktemp -d)`
- Exported for subshells: `export -f write_file` and `export TMP_DIR`

## Coverage

**Requirements:** No automated coverage checking; all public functions must have tests

**View Coverage:**
```bash
# Count test assertions across all test files
grep -c "run_test\|assert_" tests/test_*.sh

# Check which functions are tested
grep "type.*&>/dev/null" tests/test_logging.sh

# View test output
./tests/run_all_tests.sh
```

**Must Cover:**
- All public functions (dc_*, log_*, parallel_*, etc.)
- All module guards and initialization
- Error conditions (invalid parameters, missing files)
- Idempotency (multiple calls produce same result)

**Exclude from Coverage:**
- Private/internal functions starting with `_`
- External tool wrappers (gum, yq) - test availability, not functionality
- Shell builtins (type, command -v)

## Test Types

**Unit Tests:**
- Scope: Single function or module in isolation
- Approach: Source the module, call functions, verify output/exit code
- Setup: Minimal - just load the module
- Examples: All tests in `test_core.sh`, `test_logging.sh`

**Integration Tests:**
- Scope: Multiple modules working together
- Approach: Source multiple modules, verify cross-module behavior
- Setup: Create mock data or temporary directories
- Examples: `test_plugin.sh` (plugin.sh + config.sh), `test_parallel.sh` (parallel.sh + core.sh)

**E2E Tests:**
- Scope: End-to-end workflows (not currently used)
- Approach: Would execute CLI commands or plugin operations
- Framework: Not applicable (no E2E tests defined)

## Common Patterns

**Async Testing:**
- Pattern: Not applicable (bash testing is synchronous)
- For parallel jobs: `parallel_run` tests verify job execution and exit codes
- Wait for jobs: Test framework handles via `parallel_run` internal waits

**Error Testing:**
```bash
# Test function rejects invalid input
run_test "log_set_level rejects invalid" "! log_set_level invalid"

# Test command fails as expected
run_test "parallel_run failure" "! parallel_run 2 'true' 'false' 'true'"

# Test error message appears
run_test "_dc_should_log filters debug" "! _dc_should_log debug test.sh"
```

**Setup/Teardown:**
```bash
# Setup - called manually in tests
test_setup() {
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT
}

# Cleanup - via trap
trap cleanup_test_plugin EXIT
```

**Test Summary:**
- Master runner collects stats: `tests/run_all_tests.sh`
- Each test file reports: `Tests: 28 | Passed: 28 | Failed: 0`
- Master aggregates: `Total Tests: 150 | Passed: 150 | Failed: 0`
- Exit code 0 on all pass, 1 on any failure

## Test Helpers Library

**Location:** `tests/test_helpers.sh`

**Core Functions:**
```bash
run_test "name" "command"              # Run test, report pass/fail
assert_eq "expected" "actual" "msg"    # Assert equality
assert_ne "not_expected" "actual"      # Assert inequality
assert_contains "haystack" "needle"    # Assert substring
assert_true "command" "msg"            # Assert command succeeds
assert_false "command" "msg"           # Assert command fails
assert_file "file" "msg"               # Assert file exists
assert_dir "dir" "msg"                 # Assert directory exists
test_summary                           # Print summary and exit
```

**Global Counters:**
- `TESTS_RUN` - Total tests executed
- `TESTS_PASSED` - Successful tests
- `TESTS_FAILED` - Failed tests

**Output:**
- Colored output (if terminal): Red (✗) for fail, Green (✓) for pass
- No colors if piped: Fallback to plain text
- Summary format: `Tests: N | Passed: N | Failed: N`

---

*Testing analysis: 2026-01-31*
