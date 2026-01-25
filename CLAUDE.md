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

**MANDATORY - ZERO TOLERANCE**

This is a core principle of this project. Any fallback, workaround, or bypass code is **FORBIDDEN**.

#### What is forbidden:

1. **Fallback logic**
   ```bash
   # FORBIDDEN - Never do this
   if ! download_tarball; then
       git clone ...  # This hides the real problem
   fi
   ```

2. **Silent error handling**
   ```bash
   # FORBIDDEN
   some_command || true  # Hiding failures
   some_command 2>/dev/null  # Hiding errors
   ```

3. **Conditional bypasses**
   ```bash
   # FORBIDDEN
   if ! binary_exists; then
       echo "Binary not found, using alternative..."
   fi
   ```

#### What is required:

1. **Fix root cause immediately**
   - Binary missing in tarball? Include it in tarball
   - API returning wrong data? Fix the API
   - Test failing? Fix the code, not the test

2. **Fail fast and loud**
   ```bash
   # CORRECT
   set -euo pipefail  # Always at top of scripts

   if ! download_tarball; then
       fatal "Tarball not found at $URL. Create release with 'make release' first."
       exit 1
   fi
   ```

3. **Clear error messages**
   - Tell user exactly what failed
   - Tell user how to fix it
   - Never suggest workarounds

#### Why this matters:

- Fallbacks hide bugs that will resurface later
- Workarounds create technical debt
- Silent failures cause data corruption
- Root cause fixes are permanent

#### Memory rule for Claude:

**BEFORE writing any code that handles failure, ASK:**
- Am I hiding a problem or fixing it?
- If the "alternative" works, why isn't it the primary path?
- What is the ROOT CAUSE and how do I fix THAT?

If you're about to write `|| true`, `2>/dev/null`, or "if this fails, try that" - STOP. Fix the root cause instead.
