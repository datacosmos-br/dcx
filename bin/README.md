# DCX/bin - Binary Directory

This directory contains the CLI tools and bundled binaries for dc-scripts.

## Directory Structure

```
bin/
├── dcx                 # Main CLI wrapper (committed)
├── README.md           # This file (committed)
├── .gitkeep           # Documentation placeholder (committed)
├── completions/       # Shell completions (committed)
│   ├── dcx.bash
│   └── dcx.zsh
└── [generated]/       # Platform-specific binaries (generated)
    ├── gum-linux-amd64
    ├── yq-linux-amd64
    ├── rg-linux-amd64
    └── ...
```

## Committed Files

These files are always present in the git repository:

- **`dcx`** - Main CLI entry point and platform selector
- **`README.md`** - This documentation
- **`completions/`** - Shell completion scripts
- **`.gitkeep`** - Documentation and build instructions

## Generated Files

These files are created during the build/release process and are **not** committed to git:

- **Go tools**: `gum-*`, `yq-*`
- **Rust tools**: `rg-*`, `fd-*`, `sd-*`, `frawk-*`, `coreutils-*`
- **Static binaries**: `bash-*`

## Building

```bash
# Build for all supported platforms (requires cross-compilation setup)
make binaries

# Build for current platform only
make binaries-local

# Create release package with all binaries
make release

# Publish to GitHub Releases
make publish
```

## Platform Support

Binaries are built for these platforms:
- **Linux**: amd64, arm64, 386
- **macOS**: amd64, arm64
- **Windows**: amd64, arm64, 386

Naming: `{tool}-{os}-{arch}` (e.g., `gum-linux-amd64`)

## Installation

End users don't need to build binaries. The `install.sh` script automatically downloads the appropriate platform binaries from GitHub Releases.