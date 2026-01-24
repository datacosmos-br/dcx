package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// findBinary locates a binary, checking bundled binaries first, then system PATH
// Returns the full path to the binary or an error if not found
func findBinary(name string) (string, error) {
	binDir := getBinDir()
	platform := detectPlatform()

	// 1. Platform-specific bundled binary (e.g., gum-linux-amd64)
	platformBin := filepath.Join(binDir, fmt.Sprintf("%s-%s", name, platform))
	if isExecutable(platformBin) {
		return platformBin, nil
	}

	// 2. Generic bundled binary (e.g., gum symlink)
	genericBin := filepath.Join(binDir, name)
	if isExecutable(genericBin) {
		return genericBin, nil
	}

	// 3. System binary in PATH
	if path, err := exec.LookPath(name); err == nil {
		return path, nil
	}

	return "", fmt.Errorf("binary not found: %s", name)
}

// isExecutable checks if a file exists and is executable
func isExecutable(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	// Check if it's a regular file and has execute permission
	return info.Mode().IsRegular() && info.Mode()&0111 != 0
}

// handleBinary handles the "dcx binary" subcommand
func handleBinary(args []string) {
	if len(args) == 0 {
		printBinaryHelp()
		return
	}

	switch args[0] {
	case "find":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "Usage: dcx binary find <name>")
			os.Exit(1)
		}
		path, err := findBinary(args[1])
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Println(path)

	case "list":
		listBinaries()

	case "help", "-h", "--help":
		printBinaryHelp()

	default:
		// Assume it's a binary name to find
		path, err := findBinary(args[0])
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Println(path)
	}
}

func listBinaries() {
	binDir := getBinDir()

	binaries := []struct {
		name     string
		required bool
	}{
		{"gum", true},
		{"yq", true},
		{"rg", false},
		{"fd", false},
		{"sd", false},
		{"sg", false},
	}

	fmt.Printf("%-10s %-10s %-8s %s\n", "Name", "Required", "Status", "Path")
	fmt.Printf("%-10s %-10s %-8s %s\n", "----", "--------", "------", "----")

	for _, b := range binaries {
		required := "no"
		if b.required {
			required = "yes"
		}

		path, err := findBinary(b.name)
		status := "missing"
		pathDisplay := "-"

		if err == nil {
			pathDisplay = path
			// Check if it's bundled or system
			if filepath.HasPrefix(path, binDir) {
				status = "bundled"
			} else {
				status = "system"
			}
		}

		fmt.Printf("%-10s %-10s %-8s %s\n", b.name, required, status, pathDisplay)
	}
}

func printBinaryHelp() {
	fmt.Println(`Usage: dcx binary <command>

Commands:
  find <name>    Find path to binary (bundled or system)
  list           List all known binaries and their status
  help           Show this help

Examples:
  dcx binary find gum    # Returns path to gum binary
  dcx binary list        # List all binaries`)
}
