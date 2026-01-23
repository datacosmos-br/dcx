# Test Suite Documentation

## Overview

Comprehensive test suite for the modular library system. Tests validate:
- Module loading and dependency resolution
- Backward compatibility
- Integration between modules
- Error handling
- Performance and edge cases

## Test Structure

### Phase 1: Syntax Validation
Validates all library and script files have correct bash syntax.

### Phase 2: Library Loading Tests
Tests basic loading functionality and double-sourcing protection.

### Phase 3: Core Module System Tests (`test_core.sh`)
Comprehensive tests for the new module system:
- Basic loading
- Module registration
- Dependency resolution
- Lazy loading
- Oracle module integration
- Backward compatibility
- Error handling
- Integration scenarios

### Phase 3.5: Module Dependency Tests (`test_module_dependencies.sh`)
Validates dependency declarations and prevents circular dependencies:
- Independent module loading
- Dependency chain validation
- Circular dependency detection

### Phase 4: Runtime Tests (`test_runtime.sh`)
Unit tests for runtime.sh utilities.

### Phase 5: Logging Tests (`test_logging.sh`)
Unit tests for logging.sh functions.

### Phase 6: Oracle Tests (`test_oracle.sh`)
Unit tests for oracle.sh functions.

### Phase 7: SQL Execution Tests (`test_sqlexec.sh`)
Unit tests for oracle_sql.sh functions.

### Phase 7.5: Integration Tests (`test_integration.sh`)
Real-world usage scenario tests:
- Script loading patterns (restore.sh, migrate_v2.sh)
- Module interaction
- Function coexistence
- Error handling

### Phase 8: Examples Syntax Validation
Validates example scripts have correct syntax.

## Running Tests

### Run All Tests
```bash
cd migration_automation/scripts/tests
./run_all_tests.sh
```

### Quick Mode (Syntax Only)
```bash
./run_all_tests.sh --quick
```

### Run Individual Test Suites
```bash
./test_core.sh
./test_module_dependencies.sh
./test_integration.sh
./test_runtime.sh
./test_logging.sh
./test_oracle.sh
./test_sqlexec.sh
```

## Test Coverage

### Core Module System
- ✅ Module registration
- ✅ Dependency resolution
- ✅ Lazy loading
- ✅ Idempotent loading
- ✅ Error handling
- ✅ Backward compatibility
- ✅ Circular dependency detection
- ✅ Module discovery

### Integration
- ✅ restore.sh loading pattern
- ✅ migrate_v2.sh loading pattern
- ✅ Function coexistence
- ✅ Loading order independence
- ✅ Variable export
- ✅ Direct loading (backward compat)

### Dependencies
- ✅ All modules load independently
- ✅ Dependency chains validated
- ✅ No circular dependencies
- ✅ Correct dependency declarations

## Adding New Tests

### Test File Structure
```bash
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="${SCRIPT_DIR}/.."
LIB_DIR="${PARENT_DIR}/lib"

TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
FAILED_TESTS=()

run_test() {
    local name="$1"
    shift
    TEST_COUNT=$((TEST_COUNT + 1))
    if ("$@") 2>/dev/null; then
        echo "[PASS] ${name}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "[FAIL] ${name}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_TESTS+=("${name}")
    fi
}

# Your tests here

echo "Total: ${TEST_COUNT}, Passed: ${PASS_COUNT}, Failed: ${FAIL_COUNT}"
[[ ${FAIL_COUNT} -eq 0 ]] && exit 0 || exit 1
```

### Best Practices
1. Use subshells (`bash -c`) for tests that might exit
2. Test both success and failure cases
3. Test edge cases (empty inputs, missing files, etc.)
4. Isolate tests (unset variables between tests if needed)
5. Provide clear test names
6. Test backward compatibility when applicable

## Continuous Integration

Tests can be integrated into CI/CD pipelines:

```bash
#!/bin/bash
set -e
cd migration_automation/scripts/tests
./run_all_tests.sh
```

## Troubleshooting

### Test Fails with "command not found"
- Ensure test files are executable: `chmod +x test_*.sh`
- Check that library paths are correct

### Tests Pass Individually but Fail in Suite
- Check for variable pollution between tests
- Ensure proper cleanup in test framework

### Circular Dependency Detected
- Review module dependency declarations in core.sh
- Use `core_validate_module_graph` to debug

## Performance

Test suite execution time:
- Quick mode: ~2-5 seconds
- Full suite: ~10-30 seconds (depending on system)

## Coverage Goals

- ✅ 100% syntax validation
- ✅ 100% module loading coverage
- ✅ 100% dependency resolution coverage
- ✅ 90%+ function availability coverage
- ✅ 100% integration scenario coverage
