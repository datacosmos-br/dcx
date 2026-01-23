# DCX - Datacosmos Command eXecutor

A comprehensive bash library with bundled tools and CLI interface for enterprise automation workflows.

## Features

- **CLI tool** (`dcx`) for managing scripts, plugins, and updates
- **Bundled binaries** - No external dependencies required:
  - **Go tools**: gum (terminal UI), yq (YAML/JSON)
  - **Rust tools**: ripgrep (rg), fd, sd, frawk, coreutils
  - **Static bash** for maximum portability
- **Plugin system** - Extend with plugins from GitHub
- **Auto-update** - Keep dc-scripts current
- **Hierarchical config** - Defaults → global → local → env
- **Structured logging** - JSON/text formats, per-module levels
- **Report system** - Workflow tracking with markdown output
- **95 tests** ensuring reliability

## Installation

### One-liner (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/datacosmos-br/dcx/main/install.sh | bash
```

### From Source

```bash
git clone https://github.com/datacosmos-br/dcx.git
cd dc-scripts
make install
```

### Manual Install

```bash
# Download latest release
VERSION=0.0.1
curl -fsSL "https://github.com/datacosmos-br/dcx/releases/download/v${VERSION}/dcx-${VERSION}.tar.gz" | tar xz
cd dc-scripts-${VERSION}
./install.sh
```

## CLI Usage

```bash
# Show version and bundled tools
dcx version

# Check for updates
dcx update

# Plugin management
dcx plugin list              # List installed plugins
dcx plugin install REPO      # Install from GitHub
dcx plugin remove NAME       # Remove plugin
dcx plugin update            # Update all plugins

# Configuration
dcx config show              # Show merged config
dcx config get log.level     # Get config value
dcx config set log.level debug  # Set config value
dcx config paths             # Show config search paths
dcx config init              # Create initial config interactively

# Help
dcx help
```

## Library Usage

### Basic Setup

```bash
#!/usr/bin/env bash
source ~/.local/share/dc-scripts/lib/core.sh
dc_load  # Loads all modules

# Your script here...
```

### Loading Specific Modules

```bash
#!/usr/bin/env bash
source ~/.local/share/dc-scripts/lib/core.sh
dc_source config    # Load only config module
dc_source runtime   # Load runtime module
dc_source logging   # Load logging module
dc_source report    # Load report module
```

## Modules

### core.sh - Bootstrap & Module System

```bash
dc_init       # Initialize (sets up paths, checks tools)
dc_require    # Ensure initialized
dc_version    # Print version
dc_source X   # Source module X
dc_load       # Load all modules
```

### config.sh - Hierarchical Configuration

```bash
# Read values
host=$(config_get config.yaml "database.host" "localhost")

# Write values
config_set config.yaml "database.port" "5432"

# Check existence
config_has config.yaml "database.host"

# List keys
config_keys config.yaml "database"

# Validate required keys
config_validate config.yaml "database.host" "database.port"

# Merge configs (overlay overrides base)
config_merge base.yaml overlay.yaml > merged.yaml

# Hierarchical loading (defaults → global → local → env)
config_load_hierarchical > merged.yaml
config_get_merged "log.level" "info"

# Load profile (dev/staging/prod)
config_load_profile "production" > prod.yaml

# Export to environment
config_to_env config.yaml "APP_"  # APP_DATABASE_HOST, etc.

# Schema validation
config_register_schema "mymodule" "required.key1" "required.key2"
config_validate_schema config.yaml "mymodule"
```

### runtime.sh - Validators & UI

#### Validators

```bash
need_cmd docker              # Verify command exists
need_cmds docker kubectl     # Verify multiple commands
assert_file /path/to/file    # Verify file exists
assert_dir /path/to/dir      # Verify directory exists
assert_nonempty "$VAR" "VAR" # Verify non-empty
assert_var HOME              # Verify env var is set
```

#### Interactive UI (via gum)

```bash
# Confirmations
confirm "Deploy to production?"

# Selections
env=$(choose "dev" "staging" "prod")
features=$(choose_multi "feature1" "feature2" "feature3")

# Input
name=$(input "Enter your name")
password=$(input_password "Enter password")
description=$(input_multiline "Enter description")

# Fuzzy filter
selected=$(echo -e "opt1\nopt2\nopt3" | filter "Select")

# File browser
file=$(file_select /path/to/start)
```

#### Output

```bash
# Logging (basic)
log info "Starting process..."
log warn "Something might be wrong"
log error "Something went wrong"

# Styled text
style --bold "Important"
style --foreground 212 "Pink text"

# Spinner during execution
spin "Loading..." sleep 2

# Tables (CSV input)
echo -e "Name,Age\nJohn,30" | table

# Markdown rendering
format_md "# Title\n\nSome **bold** text"
```

### logging.sh - Structured Logging

```bash
# Log levels: debug, info, success, warn, error, fatal
log_debug "Debug message"
log_info "Info message"
log_success "Success message"
log_warn "Warning message"
log_error "Error message"
log_fatal "Fatal error"  # Exits script

# Set global log level
log_set_level "debug"

# Per-module log levels
log_set_module_level "mymodule.sh" "debug"

# Log to file
log_init_file "/var/log/myapp.log"

# JSON format
DC_LOG_FORMAT=json log_info "Structured log"

# Phase/step logging
log_phase "Deployment" "Deploying to production"
log_step "Building image"
log_step_done "Building image"

# Progress indicator
log_progress 5 10 "Processing items"

# Command logging
log_cmd make build  # Logs command and duration
```

### parallel.sh - Parallel Execution

```bash
# Run commands in parallel (max 4 concurrent)
parallel_run 4 "cmd1" "cmd2" "cmd3" "cmd4" "cmd5"

# Map function over items
parallel_map 4 process_item item1 item2 item3

# Process stdin lines
cat items.txt | parallel_pipe 4 process_line

# Batch execution
parallel_batch 4 2 "cmd1" "cmd2" "cmd3" "cmd4"

# Wait for all background jobs
cmd1 & cmd2 & cmd3 &
parallel_wait_all

# Auto-detect parallelism (uses CPU count)
parallel_auto "cmd1" "cmd2" "cmd3"

# Get CPU count
cores=$(parallel_cpu_count)

# Set default max jobs
parallel_limit 8
```

### report.sh - Workflow Tracking

```bash
# Initialize report (optional markdown file output)
report_init "Database Migration" "migration-report.md"

# Phases
report_phase "Preparation" "Setting up environment"
report_step "Checking dependencies"
report_step_done "Checking dependencies" "success"

report_phase "Migration" "Running migration scripts"
report_track_item "users_table" "success" "1000 rows migrated"
report_track_item "orders_table" "failed" "Connection timeout"

# Metrics
report_metric "total_rows" "5000"
report_metric_add "processed_rows" 100

# Interactive
report_confirm "Continue with rollback?"
choice=$(report_select "Select action" "retry" "skip" "abort")

# Progress
for i in {1..10}; do
    report_progress $i 10 "Migrating"
    sleep 1
done

# Finalize (auto-determines status from tracked items)
report_finalize

# Or with explicit status
report_finalize "partial"
```

### plugin.sh - Plugin System

```bash
# Discover plugins
dc_discover_plugins

# Load plugin
dc_load_plugin /path/to/plugin

# Load all discovered plugins
dc_load_all_plugins

# Plugin info
dc_plugin_info /path/to/plugin "name"
dc_plugin_info /path/to/plugin "version"

# List plugins
dc_plugin_list           # Table format
dc_plugin_list json      # JSON format
dc_plugin_list simple    # Simple list

# Install from GitHub
dc_plugin_install "datacosmos-br/dc-scripts-oracle"

# Remove plugin
dc_plugin_remove "dc-scripts-oracle"

# Update plugins
dc_plugin_update          # All plugins
dc_plugin_update "name"   # Specific plugin
```

### update.sh - Auto-Update

```bash
# Check for updates
latest=$(dc_check_update)
if [[ -n "$latest" ]]; then
    echo "New version available: $latest"
fi

# Update to latest
dc_self_update

# Update to specific version
dc_self_update "0.2.1"

# Check bundled binaries
dc_check_binaries

# Release notes
dc_release_notes "0.0.1"
```

## Configuration

### Hierarchical Loading

Config is loaded in order (later overrides earlier):
1. **Defaults** - `$DC_HOME/etc/defaults.yaml`
2. **System** - `/etc/dc-scripts/config.yaml`
3. **User** - `~/.config/dc-scripts/config.yaml`
4. **Installation** - `$DC_HOME/etc/dc-scripts.yaml`
5. **Local** - `.dc-scripts/config.yaml` or `dc-scripts.yaml`
6. **Environment** - `DC_*` variables

### Example Config

```yaml
# ~/.config/dc-scripts/config.yaml
log:
  level: info        # debug, info, warn, error, fatal
  format: text       # text, json
  color: auto        # auto, always, never

parallel:
  max_jobs: 8
  timeout: 3600

update:
  auto_check: true
  check_interval: 86400

plugins:
  auto_load: true
```

## Plugin Development

Create a plugin with this structure:

```
my-plugin/
├── plugin.yaml      # Metadata (required)
├── lib/
│   ├── init.sh      # Auto-loaded on plugin load
│   └── mymodule.sh  # Additional modules
└── bin/             # Plugin binaries (added to PATH)
```

### plugin.yaml

```yaml
name: my-plugin
version: 1.0.0
description: My awesome plugin
author: Your Name

requires:
  dc-scripts: ">=0.0.1"
  commands:
    - sqlplus
    - rman

modules:
  - mymodule
```

## Shell Completions

### Bash

```bash
source ~/.local/share/dc-scripts/bin/completions/dcx.bash
```

### Zsh

```bash
# Add to fpath
fpath=(~/.local/share/dc-scripts/bin/completions $fpath)
autoload -Uz compinit && compinit
```

## Development

```bash
# Run tests
make test

# Full validation (lint + syntax + tests)
make validate

# Build binaries for local platform
make binaries-local

# Build all binaries (requires Go, Rust, cross)
make binaries

# Show help
make help
```

## Project Structure

```
dc-scripts/
├── bin/
│   ├── dcx              # CLI wrapper
│   ├── completions/     # Shell completions
│   │   ├── dcx.bash
│   │   └── dcx.zsh
│   └── README.md        # Binary directory docs
├── lib/
│   ├── core.sh          # Bootstrap + module system
│   ├── config.sh        # Hierarchical config
│   ├── runtime.sh       # Validators + UI
│   ├── parallel.sh      # Parallel execution
│   ├── logging.sh       # Structured logging
│   ├── report.sh        # Workflow tracking
│   ├── plugin.sh        # Plugin system
│   └── update.sh        # Auto-update
├── etc/
│   └── defaults.yaml    # Default configuration
├── plugins/             # Installed plugins
├── tests/
├── build/               # Build artifacts (ignored)
├── release/             # Release artifacts (ignored)
├── Makefile
├── install.sh
├── VERSION
└── README.md
```

## Bundled Tools

| Tool | Version | Description |
|------|---------|-------------|
| gum | 0.14.5 | Terminal UI toolkit |
| yq | 4.44.3 | YAML/JSON processor |
| ripgrep (rg) | 14.1.1 | Fast grep alternative |
| fd | 10.2.0 | Fast find alternative |
| sd | 1.0.0 | Fast sed alternative |
| frawk | 0.4.8 | Fast awk alternative |
| coreutils | 0.0.27 | Rust coreutils |
| bash | 5.2 | Static bash (Linux) |

## License

MIT License - see [LICENSE](LICENSE)

## Credits

- [charmbracelet/gum](https://github.com/charmbracelet/gum) - Terminal UI toolkit
- [mikefarah/yq](https://github.com/mikefarah/yq) - YAML/JSON processor
- [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) - Fast grep
- [sharkdp/fd](https://github.com/sharkdp/fd) - Fast find
- [chmln/sd](https://github.com/chmln/sd) - Fast sed
- [ezrosent/frawk](https://github.com/ezrosent/frawk) - Fast awk
- [uutils/coreutils](https://github.com/uutils/coreutils) - Rust coreutils
