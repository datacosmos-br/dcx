package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// handleValidate runs validation tests on all bundled tools
func handleValidate() {
	tmpDir, err := os.MkdirTemp("", "dcx-validate-*")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create temp dir: %v\n", err)
		os.Exit(1)
	}
	defer os.RemoveAll(tmpDir)

	fmt.Println("Validating bundled tools...")
	fmt.Println()

	failed := 0

	// Test GUM (required)
	fmt.Print("  gum: ")
	if gum, err := findBinary("gum"); err == nil {
		if out, err := exec.Command(gum, "--version").Output(); err == nil {
			fmt.Printf("OK (%s)\n", strings.TrimSpace(string(out)))
		} else {
			fmt.Println("FAIL (not working)")
			failed++
		}
	} else {
		fmt.Println("MISSING (required)")
		failed++
	}

	// Test YQ (required)
	fmt.Print("  yq:  ")
	if yq, err := findBinary("yq"); err == nil {
		testFile := filepath.Join(tmpDir, "test.yaml")
		os.WriteFile(testFile, []byte("test: value"), 0644)
		out, err := exec.Command(yq, ".test", testFile).Output()
		if err == nil && strings.TrimSpace(string(out)) == "value" {
			verOut, _ := exec.Command(yq, "--version").Output()
			fmt.Printf("OK (%s)\n", strings.TrimSpace(string(verOut)))
		} else {
			fmt.Println("FAIL (not working)")
			failed++
		}
	} else {
		fmt.Println("MISSING (required)")
		failed++
	}

	// Test RG (optional)
	fmt.Print("  rg:  ")
	if rg, err := findBinary("rg"); err == nil {
		testFile := filepath.Join(tmpDir, "test.txt")
		os.WriteFile(testFile, []byte("test pattern here"), 0644)
		if err := exec.Command(rg, "-q", "pattern", testFile).Run(); err == nil {
			verOut, _ := exec.Command(rg, "--version").Output()
			version := strings.Split(string(verOut), "\n")[0]
			fmt.Printf("OK (%s)\n", strings.TrimSpace(version))
		} else {
			fmt.Println("FAIL (not working)")
		}
	} else {
		fmt.Println("SKIP (optional)")
	}

	// Test FD (optional)
	fmt.Print("  fd:  ")
	if fd, err := findBinary("fd"); err == nil {
		testFile := filepath.Join(tmpDir, "findme.txt")
		os.WriteFile(testFile, []byte(""), 0644)
		if err := exec.Command(fd, "-q", "findme", tmpDir).Run(); err == nil {
			verOut, _ := exec.Command(fd, "--version").Output()
			fmt.Printf("OK (%s)\n", strings.TrimSpace(string(verOut)))
		} else {
			fmt.Println("FAIL (not working)")
		}
	} else {
		fmt.Println("SKIP (optional)")
	}

	// Test SD (optional)
	fmt.Print("  sd:  ")
	if sd, err := findBinary("sd"); err == nil {
		testFile := filepath.Join(tmpDir, "replace.txt")
		os.WriteFile(testFile, []byte("old text"), 0644)
		if err := exec.Command(sd, "old", "new", testFile).Run(); err == nil {
			content, _ := os.ReadFile(testFile)
			if strings.Contains(string(content), "new") {
				verOut, _ := exec.Command(sd, "--version").Output()
				fmt.Printf("OK (%s)\n", strings.TrimSpace(string(verOut)))
			} else {
				fmt.Println("FAIL (replacement didn't work)")
			}
		} else {
			fmt.Println("FAIL (not working)")
		}
	} else {
		fmt.Println("SKIP (optional)")
	}

	// Test SG / ast-grep (optional)
	fmt.Print("  sg:  ")
	if sg, err := findBinary("sg"); err == nil {
		if out, err := exec.Command(sg, "--version").Output(); err == nil {
			fmt.Printf("OK (%s)\n", strings.TrimSpace(string(out)))
		} else {
			fmt.Println("FAIL (not working)")
		}
	} else {
		fmt.Println("SKIP (optional)")
	}

	fmt.Println()

	if failed == 0 {
		fmt.Println("All required tools validated.")
	} else {
		fmt.Println("Some required tools are missing or broken.")
		fmt.Println("Run 'dcx tools install --all' to install them.")
		os.Exit(1)
	}
}
