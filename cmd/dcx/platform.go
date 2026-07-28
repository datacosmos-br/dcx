package main

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
)

// detectPlatform returns the current platform in the format os-arch
// e.g., "linux-amd64", "darwin-arm64"
func detectPlatform() string {
	return fmt.Sprintf("%s-%s", runtime.GOOS, runtime.GOARCH)
}

// findDCHomeFrom walks upward from start and returns the first directory that
// has the DCX project/install layout.
func findDCHomeFrom(start string) (string, bool) {
	dir := start
	for i := 0; i < 6; i++ {
		if _, err := os.Stat(filepath.Join(dir, "etc", "tools.yaml")); err == nil {
			return dir, true
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}

	return "", false
}

// getDCHome returns the DCX_HOME directory.
// Priority: DCX_HOME env var > executable layout > working directory > default.
func getDCHome() string {
	// 1. Use DCX_HOME if set
	if dcHome := os.Getenv("DCX_HOME"); dcHome != "" {
		return dcHome
	}

	// 2. Try to detect from executable location
	exe, err := os.Executable()
	if err == nil {
		exe, err = filepath.EvalSymlinks(exe)
		if err == nil {
			if dcHome, ok := findDCHomeFrom(filepath.Dir(exe)); ok {
				return dcHome
			}
		}
	}

	// 3. Development runs can execute a temporary binary outside the repo.
	if cwd, err := os.Getwd(); err == nil {
		if dcHome, ok := findDCHomeFrom(cwd); ok {
			return dcHome
		}
	}

	// 4. Default installation path
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "share", "dcx")
}

// getBinDir returns the bin directory path
// Checks: 1) DCX_HOME/bin (development), 2) DCX_HOME/share/DCX/bin (installed)
func getBinDir() string {
	dcHome := getDCHome()

	// 1. Development: bin/ in DCX_HOME
	devPath := filepath.Join(dcHome, "bin")
	if _, err := os.Stat(devPath); err == nil {
		// Check if Go binary exists there
		platform := detectPlatform()
		if _, err := os.Stat(filepath.Join(devPath, "dcx-"+platform)); err == nil {
			return devPath
		}
	}

	// 2. Installed: share/DCX/bin/
	installPath := filepath.Join(dcHome, "share", "DCX", "bin")
	if _, err := os.Stat(installPath); err == nil {
		return installPath
	}

	// Fallback to development path
	return devPath
}

// getEtcDir returns the etc directory path
// Checks: 1) DCX_HOME/etc (development), 2) DCX_HOME/share/DCX/etc (installed)
func getEtcDir() string {
	dcHome := getDCHome()

	// 1. Development: etc/ in DCX_HOME
	devPath := filepath.Join(dcHome, "etc")
	if _, err := os.Stat(filepath.Join(devPath, "tools.yaml")); err == nil {
		return devPath
	}

	// 2. Installed: share/DCX/etc/
	installPath := filepath.Join(dcHome, "share", "DCX", "etc")
	if _, err := os.Stat(filepath.Join(installPath, "tools.yaml")); err == nil {
		return installPath
	}

	// Fallback to development path
	return devPath
}

// getCacheDir returns the cache directory path
func getCacheDir() string {
	return filepath.Join(getDCHome(), "cache")
}
