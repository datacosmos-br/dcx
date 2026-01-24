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

// getDCHome returns the DC_HOME directory
// Priority: DC_HOME env var > executable location > default
func getDCHome() string {
	// 1. Use DC_HOME if set
	if dcHome := os.Getenv("DC_HOME"); dcHome != "" {
		return dcHome
	}

	// 2. Try to detect from executable location
	exe, err := os.Executable()
	if err == nil {
		exe, err = filepath.EvalSymlinks(exe)
		if err == nil {
			// If we're in bin/, go up one level
			binDir := filepath.Dir(exe)
			if filepath.Base(binDir) == "bin" {
				return filepath.Dir(binDir)
			}
			// If we're in cmd/dcx/ during development, go up two levels
			if filepath.Base(binDir) == "dcx" {
				return filepath.Dir(filepath.Dir(binDir))
			}
		}
	}

	// 3. Default fallback
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "share", "dcx")
}

// getBinDir returns the bin directory path
// Checks: 1) DC_HOME/bin (development), 2) DC_HOME/share/DCX/bin (installed)
func getBinDir() string {
	dcHome := getDCHome()

	// 1. Development: bin/ in DC_HOME
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
// Checks: 1) DC_HOME/etc (development), 2) DC_HOME/share/DCX/etc (installed)
func getEtcDir() string {
	dcHome := getDCHome()

	// 1. Development: etc/ in DC_HOME
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
