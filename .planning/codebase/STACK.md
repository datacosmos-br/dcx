# Technology Stack

**Analysis Date:** 2026-01-31

## Languages

**Primary:**
- Bash - Latest (5.x compatible) - Core CLI and plugin system, all library modules
- Go 1.25.6 - CLI binary for platform detection, tool management, configuration validation

**Secondary:**
- YAML - Configuration files (project.yaml, defaults.yaml, plugin.yaml, etc.)
- Shell Script - Installation scripts, build automation, test harnesses

## Runtime

**Environment:**
- Linux (amd64, arm64), macOS (amd64, arm64), Windows (amd64) - via Go binaries
- Requires: POSIX-compliant shell (bash 4.0+)

**Package Manager:**
- Go Modules (go.mod/go.sum) - Minimal dependencies
- No package manager for shell components (self-contained libraries)

## Frameworks

**Core:**
- Custom bash framework (`lib/` modules) - Plugin system, logging, parallel execution, configuration management
- Go standard library - No external Go dependencies beyond gopkg.in/yaml.v3

**Bundled Tools:**
- gum 0.14.5 (Go, charmbracelet) - Terminal UI/prompts
- yq 4.44.3 (Go, mikefarah) - YAML processing
- ripgrep (rg) 14.1.1 (Rust) - Fast file search (optional)
- fd 10.2.0 (Rust) - File finder (optional)
- sd 1.0.0 (Rust) - Regex-based text replacement (optional)

**Testing:**
- Custom bash test framework (`tests/run_all_tests.sh`) - Source code validation, integration testing
- No external test dependencies

**Build/Dev:**
- Make - Build orchestration (Makefile)
- Shellcheck - Bash static analysis (optional)
- tar/gzip - Release packaging
- Git - Version control

## Key Dependencies

**Critical:**
- `gopkg.in/yaml.v3 v3.0.1` - YAML parsing in Go CLI (go.mod)
- curl or wget - File downloads (installer, updates)
- gum v0.14.5 - Required terminal UI for interactive features
- yq v4.44.3 - Required YAML configuration processing

**Infrastructure:**
- `charmbracelet/gum` (Go) - Interactive CLI prompts and formatting
- `mikefarah/yq` (Go) - YAML/JSON configuration management
- `BurntSushi/ripgrep` (Rust) - Fast code search
- `sharkdp/fd` (Rust) - Directory traversal
- `chmln/sd` (Rust) - Stream editor for text replacement

## Configuration

**Environment:**
- Configured via YAML files: `etc/project.yaml`, `etc/defaults.yaml`
- User overrides: `$DCX_CONFIG_DIR` (typically `$HOME/.config/dcx`)
- Plugins: `$DCX_HOME/plugins` or `$XDG_CONFIG_HOME/dcx/plugins`

**Key Configuration Files:**
- `etc/project.yaml` - Project metadata, tool versions, supported platforms
- `etc/defaults.yaml` - Logging, parallel execution, update behavior
- `plugins/*/plugin.yaml` - Plugin metadata and capabilities

**Environment Variables (DCX Prefixed):**
- `DCX_HOME` - Installation directory (default: `$HOME/.local/share/dcx`)
- `DCX_CONFIG_DIR` - User configuration directory
- `DCX_VERSION` - Current version
- `DCX_DEBUG` - Debug mode

## Platform Requirements

**Development:**
- bash 4.0+, gawk, grep, sed, awk
- Go 1.25.6 (for building dcx binary only)
- make - Build orchestration
- shellcheck - Linting (optional)
- curl or wget - Binary downloads

**Production:**
- Deployment target: Linux (amd64/arm64), macOS (amd64/arm64), Windows (amd64)
- Standalone tarball with bundled Go binaries and shell libraries
- Installation: `curl -fsSL https://raw.githubusercontent.com/datacosmos-br/dcx/main/install.sh | bash`
- Or: Manual extraction to `$HOME/.local/share/dcx`

## Cross-Platform Binary Support

**Included Binaries (by platform):**
- `gum-{platform}` - Terminal UI toolkit (required)
- `yq-{platform}` - YAML processor (required)
- `rg-{platform}`, `fd-{platform}`, `sd-{platform}` - Optional search/replace tools

**Build Targets:** linux-amd64, linux-arm64, darwin-amd64, darwin-arm64, windows-amd64

**Release Format:** Universal tarball with all platform binaries included

---

*Stack analysis: 2026-01-31*
