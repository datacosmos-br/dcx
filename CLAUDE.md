# CLAUDE.md - dcx Project Guidelines

This file provides guidance to Claude Code when working with this repository.

## Overview

dcx (Datacosmos Command eXecutor) is a modular CLI framework with plugin system for automation tasks.

## Key Commands

```bash
# Run tests
cd tests && ./run_all_tests.sh

# Quick syntax check
bash -n lib/core.sh

# Install locally
./install.sh --local
```

## Architecture

### Module System
- `lib/core.sh` - Core module loader
- `lib/*.sh` - Shared libraries
- `bin/dcx` - Main CLI entry point
- `etc/` - Configuration files

### Plugin System
- Plugins installed to `~/.config/dcx/plugins/` or `~/.local/share/dcx/plugins/`
- Each plugin has: `plugin.yaml`, `init.sh`, `lib/`, `commands/`

## Environment Variables

All variables use `DCX_` prefix:
- `DCX_HOME` - Installation directory
- `DCX_CONFIG_DIR` - User config directory
- `DCX_VERSION` - Current version
- `DCX_DEBUG` - Enable debug mode

## Release Process

1. Update VERSION file
2. Run all tests: `./tests/run_all_tests.sh`
3. Create release tarball: `make release`
4. Create GitHub release with tarball upload
5. Tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`

---

## Development Principles

### NO FALLBACK / NO BYPASS Policy

**CRITICAL**: When developing for this project:

1. **Never add fallback code** that hides problems
   - If a download fails, fail clearly - don't silently clone from git
   - If a dependency is missing, report it - don't skip the feature
   - If a test fails, fix it - don't disable the test

2. **Always fix root cause**
   - Release tarball missing? Upload it to the release
   - API returning wrong data? Fix the API call
   - Configuration broken? Fix the configuration

3. **No workarounds**
   - Don't add "if this fails, try that" logic
   - Don't catch errors and continue silently
   - Don't use try/catch to hide failures

4. **Fail fast and loud**
   - Use `set -e` in bash scripts
   - Return proper exit codes
   - Log clear error messages

### Example

```bash
# BAD - fallback hides the real problem
if ! download_tarball; then
    warn "Tarball not found, cloning from git..."
    git clone ...
fi

# GOOD - fail clearly, fix root cause
if ! download_tarball; then
    fatal "Tarball not found. Ensure release was created with 'make release'"
fi
```

The solution is to ensure the tarball exists, not to add a workaround.
