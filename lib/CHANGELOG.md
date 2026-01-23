# Changelog - Library Reorganization v4.0.0

## Version 4.1.0 (2026-01-15) - Logging & Config Improvements

### Added

#### Logging Enhancements (`logging.sh`)
- **Automatic Context Capture**: All log functions now automatically capture caller function, module name, and line number
- **Structured Logging**: Optional JSON output format (`LOG_STRUCTURED=1`)
- **Module-Level Control**: Per-module log levels (`log_set_module_level`, `log_get_module_level`)
- **Context Display**: Show context in logs when `LOG_SHOW_CONTEXT=1`
- New functions: `log_set_module_level()`, `log_get_module_level()`, `log_configure_from_env()`

#### Configuration Enhancements (`config.sh`)
- **Hierarchical Loading**: Load config in order (defaults → global → local → env vars)
- **Schema Validation**: Type validation (string, int, uint, bool, enum, path, url)
- **Profile System**: Support for environment-specific configs (dev, prod, test)
- **Config Logging**: Automatic logging of loaded configuration files
- New functions:
  - `config_load_hierarchical()` - Load config hierarchically
  - `config_load_profile()` - Load profile-specific config
  - `config_detect_profile()` - Auto-detect profile from environment
  - `config_load_with_profile()` - Load config with automatic profile detection
  - `config_register_schema()` - Register validation schema
  - `config_validate_schema()` - Validate config against schemas
  - `config_log_loaded()` - List loaded config files
  - `config_print_sources()` - Show source of each config variable
  - `config_print_schema()` - Display registered schemas

#### Configuration Defaults (`config_defaults.sh`) - NEW FILE
- Centralized default values for all configuration variables
- Pre-registered validation schemas
- Inline documentation for each variable

#### Profile Configuration Files (`config/profiles/`)
- `dev.conf`: Development environment (verbose logging, relaxed validation)
- `prod.conf`: Production environment (standard logging, strict validation)
- `test.conf`: Test environment (very verbose, relaxed validation)

#### Core Integration (`core.sh`)
- `core_setup_all()` now supports:
  - `--config-profile PROFILE` - Load specific profile
  - `--config-base DIR` - Base directory for config files
  - `--config-app NAME` - Application name for config
  - `--validate-config` - Validate configuration against schemas

#### New Test Suites
- `test_logging_context.sh` - Tests automatic context capture
- `test_config_hierarchical.sh` - Tests hierarchical config loading
- `test_config_validation.sh` - Tests schema validation
- `test_config_profiles.sh` - Tests profile system

#### Registered New Modules
- `oracle_core.sh` - Core Oracle environment validation
- `oracle_env.sh` - Oracle environment setup with config integration

#### Code Quality
- Removed fallback code in `runtime.sh:on_err()` (fail-fast)
- Replaced `echo "ERROR"` with `warn` in `oracle_rman.sh`

### Changed
- `logging.sh`: All log functions now use `_log_with_context()` internally
- `config.sh`: `runtime_load_config()` now accepts `respect_env` parameter
- `restore.sh`: Uses `config_load_hierarchical()` for configuration loading
- `migrate_v2.sh`: Uses `config_load_with_profile()` for configuration loading

### Fixed
- Environment variable precedence in hierarchical config loading
- Shell expression evaluation in config values (`$(cd ... && pwd)`)
- Module context extraction from file paths

## Version 4.0.0 (2026-01-15)

### Major Changes

#### Complete Architecture Reorganization

**New Module System:**
- Implemented generic module loader with automatic dependency resolution
- Added module registry system (`core_register_module`)
- Lazy loading: modules loaded only when explicitly requested
- No circular dependencies: clean dependency graph

**Core Module Functions:**
- `core_load(name)` - Load module and dependencies
- `core_require(name...)` - Ensure modules are loaded (idempotent)
- `core_list_modules()` - List all registered modules
- `core_module_info(name)` - Show module details
- `core_check_dependencies()` - Validate dependency declarations
- `core_validate_module_graph()` - Detect circular dependencies
- `core_get_loaded_modules()` - List currently loaded modules

**Backward Compatibility:**
- `core_load_module()` - Still works (deprecated)
- `core_load_modules()` - Still works (deprecated)
- Direct module loading still supported

#### Dependency Architecture

**Layer 0: logging.sh**
- No dependencies
- Base logging functionality

**Layer 1: runtime.sh**
- Depends only on logging.sh
- Generic utilities (validators, confirmations, filesystem, etc.)

**Layer 2: core.sh**
- Depends on logging.sh + runtime.sh
- Module loader and manager

**Layer 3: Optional Modules**
- config.sh, queue.sh, report.sh: depend on runtime.sh
- oracle.sh: depends on runtime.sh
- oracle_*.sh: depend on runtime.sh (and oracle.sh where applicable)

#### Module Refactoring

**config.sh, queue.sh, report.sh:**
- Removed dependency on core.sh
- Load runtime.sh directly when needed
- Can be loaded directly OR via core.sh

**oracle.sh:**
- Uses core_require when core.sh is available
- Falls back to direct loading for backward compatibility
- Automatically loads oracle_*.sh sub-modules

**oracle_*.sh modules:**
- Removed dependency on core.sh
- Load runtime.sh directly when needed
- Can be loaded independently or via oracle.sh/core.sh

### Testing Infrastructure

**New Test Suites:**
- `test_core.sh` - Comprehensive core module system tests (40+ tests)
- `test_module_dependencies.sh` - Dependency validation tests (19 tests)
- `test_integration.sh` - Real-world integration scenarios (10 tests)

**Enhanced Test Runner:**
- `run_all_tests.sh` - Complete test suite with 8 phases
- Syntax validation for all library files
- Integration tests
- Unit tests for each module
- Quick mode for fast validation

**Test Coverage:**
- ✅ 100% syntax validation
- ✅ 100% module loading coverage
- ✅ 100% dependency resolution coverage
- ✅ 100% integration scenario coverage
- ✅ Circular dependency detection
- ✅ Backward compatibility validation

### Script Updates

**restore.sh:**
```bash
source lib/core.sh
core_require runtime config
source lib/oracle.sh
```

**migrate_v2.sh:**
```bash
source lib/core.sh
core_require runtime config queue report
core_load oracle
```

### Benefits

1. **Flexibility**: Scripts load only what they need
2. **No Circular Dependencies**: Automatic resolution prevents cycles
3. **Extensibility**: Easy to add new modules via `core_register_module`
4. **Maintainability**: Clear separation of concerns
5. **Testability**: Modules can be tested independently
6. **Backward Compatibility**: Legacy code continues to work

### Migration Guide

**Old Way (Still Works):**
```bash
source lib/logging.sh
source lib/runtime.sh
source lib/config.sh
```

**New Way (Recommended):**
```bash
source lib/core.sh
core_require runtime config
```

**For Oracle Modules:**
```bash
source lib/core.sh
core_load oracle  # Loads oracle.sh and all oracle_*.sh
```

### Breaking Changes

None - all changes are backward compatible.

### Deprecated Functions

- `core_load_module()` - Use `core_load()` or `core_require()` instead
- `core_load_modules()` - Use `core_require()` instead

These functions still work but show deprecation warnings.
