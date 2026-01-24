#!/usr/bin/env bash
#===============================================================================
# scripts/build.sh - Build DCX Go binary
#===============================================================================
set -euo pipefail

# Detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read version from VERSION file
VERSION=$(cat "$PROJECT_DIR/VERSION" 2>/dev/null || echo "dev")

# Build flags
LDFLAGS="-s -w -X main.Version=${VERSION}"

# Default platform (current)
GOOS=${GOOS:-$(go env GOOS)}
GOARCH=${GOARCH:-$(go env GOARCH)}

usage() {
    cat << EOF
Usage: $0 [command]

Commands:
  build         Build for current platform (default)
  all           Build for all platforms
  install       Build and install to bin/
  clean         Remove build artifacts
  help          Show this help

Environment:
  GOOS          Target OS (default: current)
  GOARCH        Target architecture (default: current)

Examples:
  $0                           # Build for current platform
  $0 all                       # Build for all platforms
  GOOS=darwin GOARCH=arm64 $0  # Build for macOS ARM
EOF
}

build_one() {
    local os="$1"
    local arch="$2"
    local output="$PROJECT_DIR/bin/dcx-${os}-${arch}"

    # Add .exe extension for Windows
    if [[ "$os" == "windows" ]]; then
        output="${output}.exe"
    fi

    echo "Building dcx for ${os}-${arch}..."

    GOOS="$os" GOARCH="$arch" go build \
        -ldflags "$LDFLAGS" \
        -o "$output" \
        "$PROJECT_DIR/cmd/dcx"

    echo "  Output: $output"
}

build_current() {
    mkdir -p "$PROJECT_DIR/bin"
    build_one "$GOOS" "$GOARCH"

    # Create symlink for current platform
    local platform="${GOOS}-${GOARCH}"
    local symlink="$PROJECT_DIR/bin/dcx-go"

    rm -f "$symlink"
    ln -sf "dcx-${platform}" "$symlink"
    echo "  Symlink: $symlink -> dcx-${platform}"
}

build_all() {
    mkdir -p "$PROJECT_DIR/bin"

    local platforms=(
        "linux amd64"
        "linux arm64"
        "darwin amd64"
        "darwin arm64"
        "windows amd64"
    )

    for platform in "${platforms[@]}"; do
        read -r os arch <<< "$platform"
        build_one "$os" "$arch"
    done

    echo ""
    echo "All platforms built!"
}

install_local() {
    build_current

    local platform="${GOOS}-${GOARCH}"
    local src="$PROJECT_DIR/bin/dcx-${platform}"
    local dst="$PROJECT_DIR/bin/dcx-go"

    echo "Installed: $dst"
}

clean() {
    echo "Cleaning build artifacts..."
    rm -f "$PROJECT_DIR/bin/dcx-"*
    echo "Done."
}

# Main
case "${1:-build}" in
    build)
        build_current
        ;;
    all)
        build_all
        ;;
    install)
        install_local
        ;;
    clean)
        clean
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        echo "Unknown command: $1" >&2
        usage
        exit 1
        ;;
esac
