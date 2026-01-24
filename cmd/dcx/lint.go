package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// handleLint runs ast-grep on shell scripts
func handleLint(args []string) {
	sg, err := findBinary("sg")
	if err != nil {
		fmt.Println("ast-grep (sg) not installed.")
		fmt.Println("Run: dcx tools install sg")
		os.Exit(1)
	}

	dcHome := getDCHome()
	rulesDir := filepath.Join(dcHome, "etc", "rules")

	// Check if rules directory exists
	if _, err := os.Stat(rulesDir); os.IsNotExist(err) {
		fmt.Printf("No rules directory found at %s\n", rulesDir)
		fmt.Println("Create YAML rule files in etc/rules/ to enable linting.")
		os.Exit(0)
	}

	// Find all rule files
	ruleFiles, err := filepath.Glob(filepath.Join(rulesDir, "*.yml"))
	if err != nil || len(ruleFiles) == 0 {
		fmt.Println("No rule files (*.yml) found in", rulesDir)
		os.Exit(0)
	}

	// Default paths to lint
	paths := []string{
		filepath.Join(dcHome, "lib"),
		filepath.Join(dcHome, "bin"),
	}

	// Allow custom paths
	if len(args) > 0 {
		paths = args
	}

	// Run ast-grep for each rule file
	hasIssues := false
	for _, ruleFile := range ruleFiles {
		ruleName := filepath.Base(ruleFile)
		fmt.Printf("=== Checking: %s ===\n", ruleName)

		cmdArgs := []string{"scan", "--rule", ruleFile}
		cmdArgs = append(cmdArgs, paths...)

		cmd := exec.Command(sg, cmdArgs...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Dir = dcHome

		if err := cmd.Run(); err != nil {
			if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() != 0 {
				hasIssues = true
			}
		}
		fmt.Println()
	}

	if hasIssues {
		os.Exit(1)
	}
}
