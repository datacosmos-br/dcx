# Codebase Structure

**Analysis Date:** 2026-01-31

## Directory Layout

```
dcx/
├── bin/                    # Executables and wrapper
│   ├── dcx                 # Shell wrapper (entry point)
│   ├── dcx-linux-amd64     # Go binary (platform-specific)
│   ├── dcx-linux-arm64     # Go binary (platform-specific)
│   ├── dcx-darwin-amd64    # Go binary (platform-specific)
│   ├── dcx-darwin-arm64    # Go binary (platform-specific)
│   └── completions/        # Shell completions
│
├── cmd/dcx/                # Go source code
│   ├── main.go             # Entry point, command router
│   ├── config.go           # Config subcommand handler
│   ├── platform.go         # Platform detection
│   ├── binary.go           # Binary discovery/management
│   ├── tools.go            # Tool management
│   ├── validate.go         # Validation handler
│   └── lint.go             # Linting handler
│
├── lib/                    # Shell libraries (modules)
│   ├── core.sh             # Module system, paths, Go binary discovery (always load first)
│   ├── logging.sh          # Structured logging with context
│   ├── runtime.sh          # Validators (need_cmd, assert_file, etc.)
│   ├── config.sh           # Config management (YAML operations via Go)
│   ├── parallel.sh         # Parallel execution utilities
│   ├── plugin.sh           # Plugin discovery and loading
│   ├── shared.sh           # Shared utilities
│   ├── constants.sh        # Project constants
│   └── update.sh           # Update/upgrade functionality
│
├── plugins/                # Built-in plugins
│   └── dcx-oracle/         # Oracle plugin (example)
│       ├── plugin.yaml     # Plugin metadata and version requirement
│       ├── init.sh         # Plugin initialization (loads libs)
│       ├── lib/            # Plugin-specific libraries (oracle_*.sh)
│       ├── commands/       # Plugin commands (dcx oracle <cmd>)
│       │   ├── restore.sh  # RMAN restore
│       │   ├── migrate.sh  # Data Pump migration
│       │   ├── validate.sh # Environment validation
│       │   ├── keyring.sh  # Credential management
│       │   ├── sql.sh      # SQL execution
│       │   └── rman.sh     # RMAN commands
│       ├── etc/            # Plugin configuration
│       ├── docs/           # Plugin documentation
│       ├── examples/       # Plugin examples
│       └── tests/          # Plugin tests
│
├── etc/                    # Configuration and metadata
│   ├── project.yaml        # Project constants (name, version, platforms, tools)
│   ├── defaults.yaml       # Default configuration
│   ├── tools.yaml          # Tool definitions and versions
│   └── rules/              # Linting and validation rules
│       └── bash-patterns.yml # Bash linting patterns
│
├── tests/                  # Test suite for core DCX
│   ├── run_all_tests.sh    # Test runner
│   ├── test_helpers.sh     # Test utilities and assertions
│   ├── test_core.sh        # Tests for lib/core.sh
│   ├── test_logging.sh     # Tests for lib/logging.sh
│   ├── test_config.sh      # Tests for lib/config.sh
│   ├── test_runtime.sh     # Tests for lib/runtime.sh
│   ├── test_plugin.sh      # Tests for lib/plugin.sh
│   ├── test_parallel.sh    # Tests for lib/parallel.sh
│   ├── test_update.sh      # Tests for lib/update.sh
│   └── lib/                # Test libraries
│       └── test_*.sh       # Reusable test modules
│
├── scripts/                # Build and utility scripts
│   ├── build.sh            # Build Go binary
│   ├── build-binaries.sh   # Cross-platform binary builds
│   └── create-platform-release.sh # Release packaging
│
├── docs/                   # Documentation (README, guides)
├── examples/               # Example scripts and configurations
│   ├── example_workflow.sh # Example DCX workflow
│   └── config.yaml         # Example configuration
│
├── share/                  # Installed artifacts (runtime)
├── cache/                  # Build cache
├── release/                # Release artifacts
│
├── Makefile                # Build targets (build, test, install, lint)
├── go.mod                  # Go module definition
├── go.sum                  # Go dependencies lock file
├── install.sh              # Installation script
├── VERSION                 # Current version number
├── LICENSE                 # MIT License
├── README.md               # Project overview
└── CLAUDE.md               # Claude Code development guidelines
```

## Directory Purposes

**bin/**
- Purpose: Executable entry points and platform-specific binaries
- Contains: Shell wrapper (`dcx`), compiled Go binaries for each platform
- Key files: `dcx` (router), platform-specific binaries (linux-amd64, darwin-arm64, etc.)
- Generated during: Build process (scripts/build-binaries.sh)

**cmd/dcx/**
- Purpose: Go source code for binary
- Contains: Command handlers (config, binary, tools, validate, lint), platform detection
- Entry point: `main.go` - parses args and routes to handlers
- Compilation: `scripts/build.sh` produces `bin/dcx-<platform>` binaries

**lib/**
- Purpose: Reusable shell modules for scripts and plugins
- Contains: Module system, logging, config, runtime utilities, plugin management
- Load order: `core.sh` (always first), then on-demand via `core_load`
- Dependency graph: core → {logging, shared, constants} → {runtime, plugin, config} → {parallel, update}
- Guard pattern: Each module has `_DCX_<MODULE>_LOADED` guard to prevent multiple sourcing

**plugins/**
- Purpose: Extend DCX with domain-specific functionality
- Contains: Plugin directories (e.g., dcx-oracle/), each with commands and libraries
- Structure: `plugins/<name>/plugin.yaml` (metadata), `commands/*.sh` (executables)
- Installation: Built-in plugins in `plugins/`, user plugins in `~/.config/dcx/plugins/`

**etc/**
- Purpose: Configuration, metadata, and rules
- Key files:
  - `project.yaml`: Single source of truth for project name, repo, tool versions, platforms
  - `defaults.yaml`: Default configuration values
  - `tools.yaml`: Bundled tool definitions
  - `rules/bash-patterns.yml`: Linting patterns for `dcx lint`

**tests/**
- Purpose: Test suite for core DCX library
- Structure: One test file per library module (test_core.sh, test_logging.sh, etc.)
- Execution: `tests/run_all_tests.sh` runs all tests
- Test helpers: `test_helpers.sh` provides `run_test()` and `test_summary()`

**scripts/**
- Purpose: Build and release automation
- Key scripts:
  - `build.sh`: Build Go binary for current platform
  - `build-binaries.sh`: Cross-platform builds (linux-amd64, darwin-arm64, etc.)
  - `create-platform-release.sh`: Package release tarball

**docs/ and examples/**
- Purpose: Documentation and reference examples
- Examples show: Plugin loading, config management, logging patterns

## Key File Locations

**Entry Points:**
- `bin/dcx`: Shell wrapper that routes commands to plugins or Go binary
- `cmd/dcx/main.go`: Go binary entry point

**Configuration:**
- `etc/project.yaml`: Project constants (name, version, tool versions, platforms)
- `etc/defaults.yaml`: Default configuration
- `~/.config/dcx/config.yaml`: User-level configuration (XDG compliant)

**Core Logic:**
- `lib/core.sh`: Module system and path detection
- `lib/plugin.sh`: Plugin discovery and loading
- `lib/logging.sh`: Structured logging
- `lib/config.sh`: YAML configuration operations
- `cmd/dcx/*.go`: Go handlers for binary/tool/config operations

**Testing:**
- `tests/run_all_tests.sh`: Test entry point
- `tests/test_core.sh`, `tests/test_logging.sh`, etc.: Module-specific tests

**Build:**
- `Makefile`: Build targets
- `scripts/build.sh`: Go binary compilation
- `scripts/build-binaries.sh`: Cross-platform builds

## Naming Conventions

**Files:**
- `*.sh`: Shell scripts and libraries (lowercase with underscores)
- `*.go`: Go source files (lowercase with underscores)
- `*.yaml`: Configuration and metadata files
- `test_*.sh`: Test files (one per module tested)
- `lib/*.sh`: Reusable libraries (module name matches lib/modulename.sh)

**Directories:**
- `plugins/<name>/`: Plugin directory (lowercase, hyphenated if multi-word)
- `lib/`: Core libraries
- `cmd/<binary>/`: Go source for binary
- `etc/`: Configuration and metadata
- `tests/`: Test suite

**Shell Functions:**
- `log_*`: Logging functions (log_info, log_error, log_warn)
- `dc_*`: Public functions exported to users
- `_dc_*`: Internal helpers (single underscore = private)
- `__*`: Build-time only (double underscore = not exported)
- Module functions follow pattern: `<module>_<verb>_<noun>()` (e.g., `config_get`, `plugin_info`)

**Variables:**
- `DCX_*`: Exported environment variables
- `_DCX_*`: Private globals
- Constants in CAPS (DCX_HOME, DCX_VERSION)
- Module-private: `_<MODULE>_VAR`

## Where to Add New Code

**New Plugin:**
- Create directory: `plugins/<name>/`
- Add metadata: `plugins/<name>/plugin.yaml`
- Add initialization: `plugins/<name>/init.sh` (loads libs if needed)
- Add commands: `plugins/<name>/commands/*.sh` (one file per command)
- Add libraries (optional): `plugins/<name>/lib/*.sh`
- Add tests: `plugins/<name>/tests/test_*.sh`

**New Shell Library (Core):**
- Create file: `lib/modulename.sh`
- Register in core.sh: `core_register_module "modulename" "$DCX_LIB_DIR/modulename.sh" "dependencies"`
- Add guard: `[[ -n "${_DCX_MODULENAME_LOADED:-}" ]] && return 0`
- Create tests: `tests/test_modulename.sh`

**New Go Command Handler:**
- Create file: `cmd/dcx/handler.go` (e.g., `cmd/dcx/newcmd.go`)
- Add function: `handleNewcmd(args []string)`
- Register in main.go switch statement
- Add help text in `printHelp()` function

**New Configuration:**
- User config: Create in `~/.config/dcx/config.yaml` (via `dcx config set`)
- Default config: Add to `etc/defaults.yaml`
- Project config: Update `etc/project.yaml` if affects builds

**Utilities:**
- Shared helpers: Add to `lib/shared.sh`
- Validators: Add to `lib/runtime.sh` (need_cmd, assert_file, etc.)
- Logging helpers: Extend `lib/logging.sh` with new log levels/formats

## Special Directories

**cache/**
- Purpose: Build cache and temporary artifacts
- Generated: Yes (during builds)
- Committed: No (.gitignore excludes)
- Cleared: `make clean`

**release/**
- Purpose: Release artifacts (tarballs, checksums)
- Generated: Yes (by build-binaries.sh)
- Committed: No
- Contains: Tarballs for each platform, SHA256 checksums

**share/**
- Purpose: Installed artifacts (mirrors installation layout)
- Generated: Yes (during `make install`)
- Committed: No
- Maps to: `~/.local/share/dcx/` when installed

**build/bash/**
- Purpose: Bash source (for reference or vendoring)
- Generated: No (checked in for build consistency)
- Committed: Yes
- Used by: Cross-compilation toolchain (if bundling bash)

## Module Dependency Graph

```
core.sh (independent - always loads first)
  ↓
┌─ logging.sh (no deps)
├─ shared.sh (no deps)
├─ constants.sh (depends: core)
│
└─ runtime.sh (depends: logging)
   ↓
   ├─ config.sh (depends: runtime)
   │  ↓
   │  └─ plugin.sh (depends: config)
   │
   └─ parallel.sh (depends: runtime)

   update.sh (depends: logging, config, constants)
```

**Load patterns:**
- Auto-load: `core.sh` always loads (in lib/core.sh itself)
- On-demand: All others via `core_load "module1" "module2"`
- Dependency resolution: Automatic via `_dc_load_module()`
- Idempotent: Already-loaded modules return immediately

---

*Structure analysis: 2026-01-31*
