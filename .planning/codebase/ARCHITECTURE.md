# Architecture

**Analysis Date:** 2026-01-31

## Pattern Overview

**Overall:** Hybrid shell/Go polyglot architecture with plugin system. DCX follows a **Gateway + Modular Library** pattern where a shell wrapper delegates to a Go binary for heavy lifting, while maintaining a rich shell library ecosystem for scripting and plugin extensibility.

**Key Characteristics:**
- Dual-language: Shell for plugins/scripting, Go for binary distribution and tool management
- Plugin-first design: Extensibility through shell-based plugins in standard directories
- Module system: Lazy-loaded shell libraries with dependency tracking
- Cross-platform: Go binary handles platform detection and bundled tool distribution
- XDG Base Directory compliant: Respects standard user config/cache locations

## Layers

**CLI/Gateway Layer:**
- Purpose: Entry point routing and command dispatch
- Location: `bin/dcx` (shell wrapper), `cmd/dcx/main.go` (Go binary)
- Contains: Command router, plugin discovery, subcommand handlers
- Depends on: DCX_HOME detection, platform detection, plugin registry
- Used by: End users and scripts

**Plugin Execution Layer:**
- Purpose: Load and execute plugin commands
- Location: `bin/dcx` (plugin dispatch), plugin directories (`plugins/*/`, `~/.config/dcx/plugins/`)
- Contains: Plugin discovery logic, command execution, environment setup
- Depends on: Plugin metadata (plugin.yaml), command scripts
- Used by: CLI gateway via `_dcx_is_plugin()` and `_dcx_exec_plugin()`

**Go Binary Layer (Tool Management):**
- Purpose: Platform detection, bundled tool discovery, YAML config operations
- Location: `cmd/dcx/main.go`, `cmd/dcx/*.go` files
- Contains: `binary find`, `tools list/install`, `config yaml-*`, `validate`, `lint`
- Depends on: Platform detection via `uname`, YAML library, local filesystem
- Used by: Shell libraries, wrapper script for binary/tool discovery

**Shell Library Layer:**
- Purpose: Provide reusable functionality for scripts and plugins
- Location: `lib/*.sh` (9 modules)
- Contains: Module system, logging, configuration, runtime validators, plugin management, parallel execution
- Depends on: Go binary for platform/binary discovery, external tools (yq, gum)
- Used by: Plugin commands, user scripts via `source` or `core_load`

**Plugin Extension Layer:**
- Purpose: Extend DCX with domain-specific functionality
- Location: `plugins/*/`, `~/.config/dcx/plugins/*/`
- Contains: Plugin metadata (plugin.yaml), command scripts, plugin-specific libraries
- Depends on: DCX core library, plugin requirements specified in plugin.yaml
- Used by: Users via `dcx <plugin-name> <command>`

## Data Flow

**Command Execution Flow:**

1. User invokes: `dcx <cmd> [args...]`
2. Shell wrapper (`bin/dcx`) receives command
3. Determine DCX_HOME (dev or installed mode)
4. Check if command is a plugin name via `_dcx_is_plugin()`
5. If plugin: locate plugin dir, source plugin metadata, execute `plugins/*/commands/<cmd>.sh`
6. If not plugin: delegate to Go binary: `$DCX_GO <cmd> [args...]`
7. Go binary parses command and dispatches to handler (config, binary, tools, validate, lint)

**Plugin Discovery Flow:**

```
User: dcx oracle restore
  ↓
bin/dcx checks: is "oracle" a plugin?
  ↓
_dcx_find_plugin("oracle") searches:
  1. $DCX_HOME/plugins/oracle/plugin.yaml
  2. $XDG_CONFIG_HOME/dcx/plugins/oracle/plugin.yaml
  ↓
Found at: $DCX_HOME/plugins/oracle
  ↓
Load: $DCX_HOME/plugins/oracle/plugin.yaml
  ↓
Execute: $DCX_HOME/plugins/oracle/commands/restore.sh [args...]
```

**Module Loading Flow (Shell Libraries):**

```
Script: source lib/core.sh
  ↓
core.sh loads immediately (always first):
  - Path detection (DCX_HOME, DCX_LIB_DIR, etc.)
  - Go binary discovery
  - Platform detection
  ↓
Script: core_load "config" "logging"
  ↓
_dc_load_module("logging"):
  - Check if already loaded
  - Resolve dependencies (none for logging)
  - Source $DCX_LIB_DIR/logging.sh
  - Mark as loaded
  ↓
_dc_load_module("config"):
  - Check if already loaded
  - Resolve dependencies (runtime)
  - Load "runtime" first
  - Source $DCX_LIB_DIR/config.sh
  - Mark as loaded
```

**State Management:**

- **Environment variables:** DCX_HOME, DCX_PLATFORM, DCX_GO, plugin paths exported globally
- **Module registry:** `_DCX_MODULE_FILES`, `_DCX_MODULE_DEPS`, `_DCX_MODULE_LOADED` (associative arrays in core.sh)
- **Plugin cache:** Optional caching of plugin metadata to avoid repeated YAML parsing
- **Configuration:** User config in `$XDG_CONFIG_HOME/dcx/` (XDG compliant), project config in `etc/project.yaml`

## Key Abstractions

**Module System:**
- Purpose: Lazy-load shell libraries with dependency resolution
- Examples: `lib/core.sh`, `lib/logging.sh`, `lib/config.sh`, `lib/runtime.sh`, `lib/plugin.sh`
- Pattern: Associative array registry with guard variables to prevent multiple sourcing

**Plugin Abstraction:**
- Purpose: Package domain-specific functionality as self-contained units
- Examples: `dcx-oracle/` plugin with RMAN/Data Pump commands
- Pattern: Plugin directory contains `plugin.yaml` metadata, `commands/*.sh` executable scripts, `lib/` for shared code

**Binary Finder:**
- Purpose: Unified interface to locate tools (bundled or system)
- Examples: Go function `findBinary()`, shell wrapper in `bin/dcx`
- Pattern: Check multiple locations (bundled, system paths) with fallback

**Configuration Handler:**
- Purpose: Read/write YAML files from shell scripts
- Examples: `config_get`, `config_set`, `config_has` (shell wrappers around Go `config yaml-*`)
- Pattern: Shell functions delegate to Go binary for YAML parsing

## Entry Points

**Main Entry Point:**
- Location: `bin/dcx` (shell wrapper)
- Triggers: User invokes `dcx` command
- Responsibilities:
  1. Determine DCX_HOME (development vs. installed)
  2. Export tool paths (GUM, YQ, RG, FD, SD, SG) from Go binary
  3. Route to plugin system or Go binary
  4. Handle shell-specific commands (plugin, source, env)

**Go Binary Entry Point:**
- Location: `cmd/dcx/main.go`
- Triggers: Shell wrapper delegates non-plugin commands
- Responsibilities:
  1. Parse subcommand (version, platform, binary, tools, config, validate, lint)
  2. Load project config from `etc/project.yaml`
  3. Dispatch to handler functions
  4. Return results or exit codes

**Plugin Command Entry Point:**
- Location: `plugins/<name>/commands/<command>.sh`
- Triggers: User invokes `dcx <plugin> <command>`
- Responsibilities:
  1. Load plugin environment (DCX_PLUGIN_DIR, DCX_PLUGIN_LIB, DCX_PLUGIN_ETC)
  2. Source plugin initialization (`init.sh`)
  3. Execute command logic
  4. Report results/errors

**Library Entry Point (for user scripts):**
- Location: `lib/core.sh`
- Triggers: Script sources `lib/core.sh` or execs `eval "$(dcx source)"`
- Responsibilities:
  1. Set up paths and Go binary reference
  2. Register built-in modules
  3. Provide module loading functions (core_load, core_require)
  4. Expose module system for lazy-loading

## Error Handling

**Strategy:** Explicit fail-fast with context. No silent failures or fallbacks.

**Patterns:**

1. **Command-level errors (shell wrapper):**
   - Plugin not found: echo error to stderr, suggest `dcx plugin list`
   - Command script not found: echo error to stderr, list available commands
   - Exit with code 1

2. **Go binary errors:**
   - Missing config file: return defaults and continue (for optional configs)
   - Invalid YAML: print error to stderr, exit 1
   - Missing binary: warn but continue (tool is optional)

3. **Module loading errors:**
   - Module not registered: log error to stderr, return 1
   - Dependency failed: propagate error up
   - Source file missing: skip if optional, fail if required

4. **Plugin execution errors:**
   - Export DCX_PLUGIN_DIR before executing command
   - Command scripts should follow local error handling patterns
   - Plugin should trap errors and provide context

## Cross-Cutting Concerns

**Logging:**
- Structured logging via `lib/logging.sh`
- Supports text and JSON formats
- Per-module log level control
- Optional file logging with DCX_LOG_FILE

**Validation:**
- Pre-execution checks in `lib/runtime.sh`
- `need_cmd()` - verify command exists
- `assert_file()` - verify file exists
- `assert_dir()` - verify directory exists
- Plugin system validates plugin.yaml on load

**Authentication:**
- Not built into core DCX
- Plugin responsibility (e.g., dcx-oracle uses credential management)
- Plugins can use environment variables or configuration files

**Platform Detection:**
- Done once at module load time via Go binary: `dcx config get platform`
- Result cached in DCX_PLATFORM for shell scripts
- Enables cross-platform binary bundling

---

*Architecture analysis: 2026-01-31*
