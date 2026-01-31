# Coding Conventions

**Analysis Date:** 2026-01-31

## Naming Patterns

**Files:**
- Shell scripts use lowercase with hyphens: `lib/core.sh`, `test_logging.sh`
- Module load guards use pattern: `_DCX_<MODULE>_LOADED`
- All environment variables prefixed with `DCX_`: `DCX_HOME`, `DCX_LOG_LEVEL`, `DCX_PLATFORM`
- Private functions prefixed with underscore: `_dc_go_binary()`, `_dc_load_module()`, `_dc_should_log()`
- Public API functions use `dc_` prefix: `dc_init()`, `dc_load()`, `dc_version()`
- Logging functions use `log_*` pattern: `log_debug()`, `log_info()`, `log_error()`, `log_fatal()`
- Module registry functions use `core_*`: `core_register_module()`, `core_load()`, `core_require()`

**Functions:**
- Public functions: `dc_<action>()` or `log_<type>()` or `parallel_<operation>()`
- Private functions: `_dc_<action>()` or `_<scope>_<action>()`
- Functions are lowercase with underscores: `need_cmd`, `assert_file`, `parallel_run`
- Action verbs first: `dc_detect_platform()`, `dc_load_plugin()`, `dc_copy_install_files()`

**Variables:**
- Global state variables use UPPERCASE: `DCX_HOME`, `DCX_VERSION`, `DCX_LOG_LEVEL`
- Global arrays use UPPERCASE with `_` prefix for private: `DCX_PLUGIN_DIRS`, `_DCX_MODULE_DEPS`, `_DCX_LOG_LEVELS`
- Local variables use lowercase: `platform`, `file`, `cmd`, `module`
- Configuration variable defaults set inline: `DCX_LOG_LEVEL="${DCX_LOG_LEVEL:-info}"`
- Counters for tests: `TESTS_RUN`, `TESTS_PASSED`, `TESTS_FAILED`, `TOTAL_TESTS`

**Types:**
- Associative arrays: `declare -gA _DCX_MODULE_FILES=()` (global, associative)
- Indexed arrays: `declare -ga DCX_PLUGIN_DIRS=()` (global, array)
- Read-only variables: `declare -r _DCX_CORE_LOADED=1`
- No explicit types in function calls; rely on context

## Code Style

**Formatting:**
- 4-space indentation (no tabs)
- Bash shebang: `#!/usr/bin/env bash`
- Set strict mode: `set -euo pipefail` in scripts and test files
- One statement per line
- Line length: No strict limit, but keep reasonably readable (~100 chars)

**Linting:**
- ShellCheck annotations: `# shellcheck source=core.sh` for sourced files
- No automatic linting enforced, but ShellCheck directives in comments show intent
- Comments use ShellCheck format: `# shellcheck source=<file>` and `# shellcheck disable=<rule>`

**Section Headers:**
- Major sections use 75-char blocks:
  ```bash
  #===============================================================================
  # SECTION NAME
  #===============================================================================
  ```
- Subsections use 75-char blocks with leading `#---`:
  ```bash
  #-------------------------------------------------------------------------------
  # function_name - Brief description
  #-------------------------------------------------------------------------------
  ```

**Comments:**
- Function documentation above function definition:
  ```bash
  #-------------------------------------------------------------------------------
  # log - Main logging function with context
  #-------------------------------------------------------------------------------
  # Usage: log info "Starting process"
  #        log error "Failed to connect" "module=network"
  #-------------------------------------------------------------------------------
  ```
- Inline comments explain why, not what: `# Initialize dirs if not done`
- Not verbose with obvious code

## Import Organization

**Order:**
1. Shebang and license header
2. Module load guard (prevent multiple sourcing)
3. Section headers and code

**Pattern:**
```bash
#!/usr/bin/env bash
#===============================================================================
# Module name and description
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DCX_MODULE_LOADED:-}" ]] && return 0
declare -r _DCX_MODULE_LOADED=1

# Source dependencies (with shellcheck annotations)
# shellcheck source=core.sh
source "${BASH_SOURCE[0]%/*}/core.sh"
```

**Path Aliases:**
- Relative to script: `"${BASH_SOURCE[0]%/*}/core.sh"` (not `./lib/core.sh`)
- XDG directories: `"${XDG_CONFIG_HOME:-$HOME/.config}/dcx"`
- Use `$(dirname ...)` when needed for absolute paths in discovery

## Error Handling

**Patterns:**
1. **Command check with error message:**
   ```bash
   need_cmd() {
       local cmd="$1"
       command -v "$cmd" &>/dev/null || {
           echo "ERROR: Required command not found: $cmd" >&2
           return 1
       }
   }
   ```

2. **File assertion:**
   ```bash
   assert_file() {
       local file="$1"
       [[ -f "$file" ]] || {
           echo "ERROR: File not found: $file" >&2
           return 1
       }
   }
   ```

3. **Fatal errors (exit immediately):**
   ```bash
   log_fatal() { log fatal "$@"; exit 1; }
   ```

4. **Conditional sourcing:**
   ```bash
   source "$file" || { echo "ERROR: Failed to load: $module" >&2; return 1; }
   ```

**Error Messages:**
- Format: `[LEVEL] message` for simple logging
- Go to stderr: `echo "ERROR: ..." >&2`
- Include context: `"ERROR: File not found: $file"` (not just `"not found"`)
- Use log functions when possible: `log_error "message"`

**No Fallbacks:**
- Per project CLAUDE.md: NEVER create fallback/bypass logic
- If something fails, STOP and report the actual error
- Example: No `git clone` fallback if tarball download fails
- Always use explicit error handling, not silent failures

## Logging

**Framework:** `log` function in `lib/logging.sh`

**Patterns:**
```bash
# Basic usage
log info "Starting process"
log error "Connection failed"
log debug "Variable value: $value"

# With context
log warn "Issue detected" "module=network"

# Convenience functions
log_debug "message"
log_info "message"
log_success "message"
log_warn "message"
log_error "message"
log_fatal "message"  # Exits with code 1

# Aliases (for compatibility)
warn "message"  # -> log warn
die "message"   # -> log fatal

# Progress logging
log_phase "Setup" "Initializing system"
log_step "Creating directories"
log_step_done "Directories created"
log_progress 5 10 "Processing items"

# Command logging
log_cmd docker ps                    # Logs and executes, shows duration
log_cmd_start "Long operation"
log_cmd_end "Long operation" success
```

**Configuration:**
- Global level: `log_set_level debug|info|warn|error`
- Per-module level: `log_set_module_level "config.sh" "debug"`
- Log file: `log_init_file "/path/to/file"`
- Format: `DCX_LOG_FORMAT=text` or `json`
- Color: `DCX_LOG_COLOR=auto|always|never`

**Log Levels:**
- `debug=0` - Detailed diagnostics
- `info=1` - Informational messages
- `success=2` - Operation completion
- `warn=3` - Warnings
- `error=4` - Errors (non-fatal)
- `fatal=5` - Fatal errors (exit)

## Comments

**When to Comment:**
- Explain non-obvious logic: `# Wait for any child to finish and update pids array`
- Document edge cases: `# Small sleep to avoid busy loop`
- Explain why, not what: Don't comment `count=$((count + 1))` as "increment counter"
- Complex algorithms: Explain the approach

**JSDoc/TSDoc:**
- Use structured function documentation blocks above functions:
  ```bash
  #-------------------------------------------------------------------------------
  # function_name - One-line description
  #-------------------------------------------------------------------------------
  # Usage: function_name arg1 arg2
  # Description: Longer explanation
  # Arguments:
  #   $1 - First argument
  #   $2 - Second argument
  # Returns: 0 on success, 1 on failure
  #-------------------------------------------------------------------------------
  ```

**Avoid:**
- Over-commenting obvious code
- Comments that duplicate code: `# set x to 5` above `x=5`
- Outdated comments

## Function Design

**Size:** Functions typically 20-50 lines; complex functions use helper functions

**Parameters:**
- Named parameters: `config_get() { local file="$1"; local key="$2"; ... }`
- Optional parameters with defaults: `local default="${3:-}"`
- Validate parameters at start of function: `[[ -z "$key" ]] && return 1`

**Return Values:**
- Exit code: 0 for success, 1 for failure
- Output via stdout: `echo "$value"`
- Errors via stderr: `echo "ERROR: ..." >&2`
- Multiple values: Use stdout lines or return single value

## Module Design

**Exports:**
- Public functions have no prefix or `dc_`/`log_`/`parallel_` prefix
- Private functions have `_` prefix
- Global variables exported: `export DCX_HOME`
- Module registry: `core_register_module "name" "$path" "deps"`

**Barrel Files:**
- No barrel files used; each module is standalone
- Modules sourced individually: `source "$DCX_LIB_DIR/logging.sh"`
- Module dependencies resolved via `core_register_module`

**Module System:**
- Modules register themselves: `core_register_module "logging" "$DCX_LIB_DIR/logging.sh" ""`
- Lazy loading: `core_load "logging"` loads module only once
- Dependency resolution: Modules list dependencies as string: `"logging runtime"`
- Idempotent: Multiple `source` calls prevented via guard: `[[ -n "${_DCX_LOGGING_LOADED:-}" ]] && return 0`

---

*Convention analysis: 2026-01-31*
