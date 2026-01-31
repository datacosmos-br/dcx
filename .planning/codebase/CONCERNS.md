# Codebase Concerns

**Analysis Date:** 2025-01-31

## Tech Debt

**Eval-based Command Execution in parallel.sh:**
- Issue: `eval "$cmd" &` in line 53 of `lib/parallel.sh` executes arbitrary commands
- Files: `lib/parallel.sh` (line 53), `tests/test_helpers.sh` (lines 50, 101, 112)
- Impact: Quote injection vulnerability possible if commands contain special characters; difficult to debug failed commands
- Fix approach: Use array-based execution instead: `bash -c "$cmd"` or pass args as array `"${cmd[@]}"`

**Silent Error Suppression Throughout Codebase:**
- Issue: Widespread use of `2>/dev/null` and `|| true` hiding failures
- Files: `lib/core.sh` (line 51), `lib/config.sh` (multiple), `lib/shared.sh` (lines 51-60), `lib/plugin.sh` (line 185), `install.sh` (multiple)
- Impact: Errors in critical operations (file downloads, binary discovery, config operations) are silently ignored; makes debugging extremely difficult; installation can appear successful when it actually failed
- Fix approach: Log errors explicitly with context; only suppress errors for truly optional operations (e.g., debug output)

**Fallback to Git Clone in Plugin Installation:**
- Issue: Lines 346-356 in `lib/plugin.sh` fall back to `git clone` when install.sh fails
- Files: `lib/plugin.sh`
- Impact: Creates two separate installation paths making support harder; `git clone` full depth still downloads history unnecessarily; no validation that clone actually produced a plugin
- Fix approach: Remove fallback entirely per CLAUDE.md rules; require explicit install.sh; make git clone depth configurable if needed

**Go Binary Discovery Fragility:**
- Issue: Multiple fallback attempts to find Go binary with different names/paths in `bin/dcx` and `lib/core.sh`
- Files: `bin/dcx` (lines 41-55), `lib/core.sh` (lines 27-38)
- Impact: Finding wrong binary version if multiple exist; no clear logging of which binary was selected; duplicated logic across two files
- Fix approach: Consolidate binary discovery into single function; log selected binary path when DCX_DEBUG=1

**Module Loading Without Validation:**
- Issue: `source "$file"` in `lib/core.sh` line 107 doesn't validate file is readable or sourcing succeeded
- Files: `lib/core.sh` (line 107)
- Impact: Silent failure if file is unreadable; error messages don't indicate which module failed; hard to debug configuration issues
- Fix approach: Verify file exists and is readable before sourcing; check sourcing return code; include file path in error

## Known Bugs

**Plugin Load Ignores Errors:**
- Symptoms: Failed plugin dependencies silently skipped; `dc_load_all_plugins` uses `|| true`
- Files: `lib/plugin.sh` (line 185)
- Trigger: Install plugin with missing dependency, then load plugins
- Workaround: Manually check `dcx plugin list` to see load status
- Fix: Remove `|| true`, return error code on failed load

**Version Check Not Implemented:**
- Symptoms: Plugin requiring specific DCX version still loads even if version mismatches
- Files: `lib/plugin.sh` (line 131) - "intentionally not implemented"
- Trigger: Install plugin requiring v1.0.0 when running v0.0.1
- Workaround: None - plugin may fail at runtime
- Fix: Implement semantic version comparison using `dcx/pkg/semver` from Go binary

**Shell Wrapper yq Dependency Without Fallback:**
- Symptoms: `bin/dcx` calls `yq` directly (line 142) without checking if it exists
- Files: `bin/dcx` (line 142)
- Trigger: Run plugin help on system without yq installed
- Workaround: Install yq manually: `dcx tools install yq`
- Fix: Use Go binary for YAML parsing instead of shelling out to yq

**Auto-Update Check Runs in Background Without Error Reporting:**
- Symptoms: Update check failures (network, API, parsing) are silently ignored
- Files: `lib/update.sh` (lines 210-220)
- Trigger: GitHub API returns non-JSON, or network fails
- Workaround: Manually check version: `dcx version` and `dcx update check`
- Fix: Log errors to DCX_HOME/.last_update_check.error for diagnostics

## Security Considerations

**Shell Injection in Plugin Installation:**
- Risk: `dcx plugin install` with malicious organization name via DCX_PLUGIN_ORG env var
- Files: `lib/plugin.sh` (line 294)
- Current mitigation: Assumes organization is trusted; GitHub HTTPS + TLS
- Recommendations:
  - Validate DCX_PLUGIN_ORG matches pattern `^[a-zA-Z0-9_-]+$`
  - Document that changing DCX_PLUGIN_ORG is equivalent to trusting that organization
  - Show full repo URL before installing

**Unquoted Variable Expansion in eval:**
- Risk: Commands passed to `parallel_run` with unquoted variables expand before eval
- Files: `lib/parallel.sh` (line 53)
- Current mitigation: Functions documented to pass quoted strings
- Recommendations: Change to array-based execution to eliminate eval entirely

**curl | bash Installer Security:**
- Risk: Standard curl | bash execution chain - full attack surface
- Files: `install.sh` (entire file)
- Current mitigation:
  - HTTPS enforced (checksum in header not validated before download)
  - Checksum verification after download
  - Strict error handling
- Recommendations:
  - Document that users should verify checksums manually before piping
  - Consider gpg signature verification
  - Add checksum to release metadata

**Go Binary Execution Without Validation:**
- Risk: `DCX_GO` binary executed directly without verifying it's the right file
- Files: `lib/core.sh` (line 42), `bin/dcx` (line 248)
- Current mitigation: Binary name checked for platform string, path verified exists
- Recommendations:
  - Store binary checksum in installation metadata
  - Verify checksum on startup in dev mode
  - Document binary integrity checking

## Performance Bottlenecks

**Plugin Discovery Scans Filesystem Every Call:**
- Problem: `dc_discover_plugins` walks filesystem each time; results not cached
- Files: `lib/plugin.sh` (lines 60-73)
- Cause: No cache invalidation strategy; plugins loaded in loop without aggregation
- Improvement path:
  - Cache discovery results per session with TTL
  - Implement file watcher for plugin directory changes
  - Batch plugin loads

**Parallel Execution CPU Spinning:**
- Problem: `parallel_run` sleeps 0.1s when at max jobs; busy-waits with `kill -0`
- Files: `lib/parallel.sh` (lines 36-50)
- Cause: Polling loop instead of wait on background jobs
- Improvement path:
  - Use bash job control `wait -n` (bash 5.1+)
  - Fall back to better exponential backoff: start 0.01s, increase to 1s max
  - Consider using `wait -p` to get PID that completed

**Redundant Platform Detection:**
- Problem: `dc_detect_platform` calls Go binary repeatedly; called in bin/dcx and lib/core.sh separately
- Files: `bin/dcx` (line 43), `lib/core.sh` (line 46)
- Cause: Each file detects platform independently
- Improvement path: Detect once in wrapper, pass as env var to sourced scripts

**Update Check Runs in Background with No Throttling:**
- Problem: `dc_maybe_check_update` spawns background process; if user runs many dcx commands, many processes spawn
- Files: `lib/update.sh` (line 220)
- Cause: No PID tracking or duplicate check prevention
- Improvement path: Write PID to lock file, check if previous check still running

## Fragile Areas

**Module Dependency System:**
- Files: `lib/core.sh` (lines 85-109)
- Why fragile: Dependency order hardcoded; circular dependency not detected; missing module file continues silently (line 102)
- Safe modification:
  - Add dependency graph validation on startup
  - Detect cycles with DFS
  - Fail explicitly if module file missing
- Test coverage: No unit tests for module loading; no circular dependency detection tests

**Plugin System with Multiple Search Paths:**
- Files: `lib/plugin.sh` (lines 33-52), `bin/dcx` (lines 74-89)
- Why fragile:
  - Plugin dirs duplicated in two places (must be kept in sync)
  - Order of search matters (user plugins override system plugins) but not documented
  - Project-local plugins `.dcx/plugins` breaks when cd'd away
- Safe modification:
  - Consolidate plugin dir discovery into one function
  - Document search order in function
  - Consider symlinks to avoid .dcx duplication
- Test coverage: `test_plugin.sh` exists but doesn't test discovery order or path resolution

**Shell Wrapper Plugin Execution:**
- Files: `bin/dcx` (lines 91-134)
- Why fragile:
  - `exec "$cmd_script"` replaces shell; error in script kills wrapper
  - Dynamic PATH modification may conflict with user environment
  - Command script expected to be executable; creates it with chmod if missing (line 124)
- Safe modification:
  - Run in subshell `bash "$cmd_script"` to isolate errors
  - Document PATH behavior
  - Validate script is already executable before sourcing
- Test coverage: Plugin execution not tested in test suite

**Auto-Update Mechanism with Last Check File:**
- Files: `lib/update.sh` (lines 185-221)
- Why fragile:
  - Race condition: multiple dcx instances can check simultaneously
  - Last check file must be writable in DCX_HOME
  - Parse of $now file as integer fails silently if corrupted
  - Background process errors never reported
- Safe modification:
  - Use atomic write with mv from temp file
  - Add lock file for mutual exclusion
  - Validate timestamp is integer; reset on parse failure
  - Capture background job output to error log
- Test coverage: No tests for concurrent update checks

**Config System via Go Binary:**
- Files: `lib/config.sh` (all functions)
- Why fragile:
  - All config operations shell out to Go binary
  - No validation of returned YAML structure
  - Error from Go binary not explicitly handled
  - Assumes yq is available in Go binary
- Safe modification:
  - Return structured output from Go; validate schema
  - Check Go binary exit code
  - Document config file format
- Test coverage: Tests exist but don't verify error cases

## Scaling Limits

**Plugin System Scales Poorly with Many Plugins:**
- Current capacity: ~10-20 plugins before discovery becomes noticeable (filesystem scan)
- Limit: If 100+ plugins, discovery and listing become slow
- Scaling path:
  - Implement metadata cache in `.dcx/plugin-metadata.json`
  - Watch filesystem for changes to invalidate cache
  - Index plugins by name for O(1) lookup instead of O(n)
  - Pre-filter plugin dirs based on plugin.yaml pattern match

**Parallel Job Execution Limited by Bash Capabilities:**
- Current capacity: ~100 concurrent jobs manageable; beyond that PID array becomes large
- Limit: Bash arrays have no theoretical limit but O(n) iteration gets slow
- Scaling path:
  - Switch to fifo-based queue for large job counts
  - Use named pipes for inter-process communication
  - Consider implementing in Go for unbounded parallelism

**Configuration File Growth:**
- Current capacity: Config YAML parsing has no size limit
- Limit: Sourcing entire config into memory; very large configs (>10MB) slow to parse
- Scaling path:
  - Use Go binary for streaming YAML parsing
  - Implement lazy loading: parse only requested keys
  - Cache parsed config with mtime-based invalidation

## Dependencies at Risk

**yq Dependency Without Version Pinning:**
- Risk: `yq` API changed between v3 and v4; -r flag behavior differs
- Files: `lib/plugin.sh` (lines 98, 145), `bin/dcx` (line 142)
- Impact: Bundled yq-darwin-arm64 etc. must match version; if system yq used, behavior may differ
- Migration plan:
  - Pin yq to 4.x minimum in install.sh and build scripts
  - Test output format of yq 4.35 (current stable)
  - Add version check: `yq --version` output validation

**curl/wget for Installation:**
- Risk: Deprecated features, security fixes
- Files: `install.sh` (line 32-35), `lib/shared.sh` (line 94-99)
- Impact: Requires curl OR wget; behavior differs slightly between them
- Migration plan:
  - Prefer curl (more common); warn if only wget available
  - Add fallback to Go binary's http client
  - Document minimum curl version (7.40+)

**Go Binary Dependency for Core Operations:**
- Risk: Go binary missing or corrupted breaks entire dcx
- Files: `lib/core.sh` (entire file depends on DCX_GO), `bin/dcx` (lines 41-67)
- Impact: Module system can't work without Go binary; config operations fail silently
- Migration plan:
  - Implement fallback to yq/jq for config operations
  - Add diagnostic command: `dcx doctor` that checks binary integrity
  - Include binary checksums in VERSION file

## Missing Critical Features

**No Health Check / Diagnostics Command:**
- Problem: Can't verify dcx installation is valid
- Blocks: Troubleshooting installation issues; verifying updates
- Recommended feature:
  ```bash
  dcx doctor
  # Check: Binary exists and is executable
  # Check: Go binary checksum valid
  # Check: All required libraries sourceable
  # Check: Plugin directories accessible
  # Check: Config file valid YAML
  # Report version and platform
  ```

**No Plugin Dependency Resolution:**
- Problem: Plugin A requires plugin B; no way to express or validate this
- Blocks: Installing plugin sets that work together
- Recommended feature: `requires.plugins: [oracle, backup]` in plugin.yaml with validation

**No Version Pinning in Shell Libraries:**
- Problem: Library functions may change behavior; no way to require specific version
- Blocks: Reliable plugin development; semantic versioning guarantees
- Recommended feature: `core_require_version "0.1.0"` function that validates DCX_VERSION

**No Rollback on Failed Update:**
- Problem: If update fails mid-installation, dcx left in broken state
- Blocks: Safe auto-updates
- Recommended feature: Keep backup from line 120 in `lib/update.sh`; restore on failure

**No Plugin Sandboxing:**
- Problem: Plugins run with full shell access; can modify dcx core files
- Blocks: Trusting untrusted plugins
- Recommended feature: Namespace plugin environment, restrict file access

## Test Coverage Gaps

**Module System Not Tested:**
- What's not tested: Dependency resolution, circular dependencies, missing files
- Files: `lib/core.sh`
- Risk: Broken module loading would only be discovered at runtime
- Priority: High - core feature

**Error Cases in Plugin Loading Not Tested:**
- What's not tested: Missing plugin.yaml, invalid YAML, missing commands, failed dependencies
- Files: `lib/plugin.sh`
- Risk: Malformed plugins cause cryptic errors
- Priority: Medium - user-facing

**Parallel Execution Error Handling Not Tested:**
- What's not tested: Command failures in parallel jobs, partial failure scenarios, signal handling
- Files: `lib/parallel.sh`
- Risk: Failures silently accumulate; cleanup not verified
- Priority: Medium - data loss possible

**Config Operations With Go Binary Not Tested:**
- What's not tested: Go binary errors, invalid YAML returns, malformed keys
- Files: `lib/config.sh`
- Risk: Silent failures in config management
- Priority: Medium - configuration reliability

**Update Path Not End-to-End Tested:**
- What's not tested: Full update lifecycle, backup/restore, version comparison, background check
- Files: `lib/update.sh`
- Risk: Updates corrupt installation
- Priority: High - installation integrity

**Install.sh Not Tested in CI:**
- What's not tested: Actual curl | bash execution, permission handling, path expansion
- Files: `install.sh`
- Risk: Installer works in dev but fails for users
- Priority: High - user-facing critical path

---

*Concerns audit: 2025-01-31*
