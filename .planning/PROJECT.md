# dcx - Datacosmos Command eXecutor

## Project Overview

**dcx** is a modular CLI tool with a plugin system, designed for enterprise automation workflows.

### Core Technologies
- **Go**: Main CLI application (`cmd/dcx/main.go`)
- **Bash**: Comprehensive shell libraries (`lib/*.sh`) for configuration, logging, parallel execution, plugins, and self-updates

### Architecture
- Hybrid Go/Bash design - Go binary handles commands, Bash libraries provide extensibility
- Plugin system with `plugin.yaml` metadata and discoverable commands
- Bundled binaries (gum, yq, ripgrep, fd) for zero external dependencies
- Hierarchical YAML configuration (system, user, project scopes)

## Key Directories

```
dcx/
├── bin/                 # Wrapper script + platform-specific Go binaries
├── cmd/dcx/             # Go CLI source code
├── lib/                 # Bash library modules (core, logging, parallel, plugin, etc.)
├── etc/                 # Configuration files (project.yaml, defaults.yaml)
├── tests/               # Shell-based test suite
├── scripts/             # Build and release scripts
├── dcx-oracle/          # Oracle plugin (RMAN, Data Pump, OCI)
└── Makefile             # Central development entry point
```

## Development Commands

```bash
make validate     # Full validation (lint, syntax, tests)
make test         # Run test suite
make binaries     # Build for local platform
make release      # Create distributable tarball
make install      # Install to ~/.local
```

## Environment Variables

All variables use `DCX_` prefix:
- `DCX_HOME` - Installation directory
- `DCX_CONFIG_DIR` - User configuration
- `DCX_VERSION` - Current version
- `DCX_DEBUG` - Debug mode

## Current Version

v0.0.1

## Development Rules

1. **No Fallbacks** - Fix root causes, never suppress errors
2. **Validate Before Done** - Test actual commands, verify output
3. **Atomic Changes** - Find ALL occurrences before refactoring
4. **Explicit Errors** - Use `fatal "reason"`, not `|| true`

## Issue Tracking

This project uses **bd (beads)** for all issue tracking:
- `bd ready` - Find available work
- `bd create "title" -t bug|feature|task -p 0-4` - Create issue
- `bd update <id> --status in_progress` - Claim work
- `bd close <id>` - Complete work
- `bd sync` - Sync with git

## Priority Levels

- P0: Critical (security, data loss, broken builds)
- P1: High (major features, important bugs)
- P2: Medium (default)
- P3: Low (polish)
- P4: Backlog (future ideas)
