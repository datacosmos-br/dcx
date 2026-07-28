package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// getLibDir returns the lib directory path for shell libraries
// Checks: 1) DCX_HOME/lib (development), 2) DCX_HOME/share/DCX/lib (installed)
func getLibDir() string {
	dcHome := getDCHome()

	// 1. Development: lib/ in DCX_HOME
	devPath := filepath.Join(dcHome, "lib")
	if _, err := os.Stat(filepath.Join(devPath, "cred.sh")); err == nil {
		return devPath
	}

	// 2. Installed: share/DCX/lib/
	installPath := filepath.Join(dcHome, "share", "DCX", "lib")
	if _, err := os.Stat(filepath.Join(installPath, "cred.sh")); err == nil {
		return installPath
	}

	// Fallback to development path
	return devPath
}

// handleCred handles the "dcx cred" subcommand
func handleCred(args []string) {
	if len(args) == 0 {
		printCredHelp()
		return
	}

	switch args[0] {
	case "set":
		credSet(args[1:])
	case "get":
		credGet(args[1:])
	case "list":
		credList(args[1:])
	case "delete":
		credDelete(args[1:])
	case "export":
		credExport(args[1:])
	case "help", "-h", "--help":
		printCredHelp()
	default:
		fmt.Fprintf(os.Stderr, "Unknown cred command: %s\n", args[0])
		fmt.Fprintln(os.Stderr, "Run 'dcx cred help' for usage")
		os.Exit(1)
	}
}

// printCredHelp prints credential management help
func printCredHelp() {
	fmt.Println(`Usage: dcx cred <command> [options]

Commands:
  set <key> <value>    Store a credential
  get <key>            Retrieve a credential
  list [--json]        List all credential keys
  delete <key> [-y]    Remove a credential
  export [--prefix X]  Export credentials as environment variables

Key Format:
  Keys must use the format: service/environment/name
  Examples: oracle/prod/password, aws/staging/secret_key

Examples:
  dcx cred set oracle/prod/password mySecretPass
  dcx cred get oracle/prod/password
  dcx cred list
  dcx cred list --json
  dcx cred delete oracle/prod/password
  dcx cred delete oracle/prod/password -y
  dcx cred export --prefix oracle/prod
  eval "$(dcx cred export --prefix oracle/prod)"

Environment:
  DCX_KEYRING_PASSWORD  Master password for automation (optional)`)
}

// credSet stores a credential
func credSet(args []string) {
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: dcx cred set <key> <value>")
		fmt.Fprintln(os.Stderr, "Key format: service/environment/name")
		os.Exit(1)
	}

	key := args[0]
	value := args[1]

	// Validate key format (must contain at least 2 slashes)
	parts := strings.Split(key, "/")
	if len(parts) < 3 {
		fmt.Fprintln(os.Stderr, "Error: Invalid key format. Use: service/environment/name")
		fmt.Fprintln(os.Stderr, "Example: oracle/prod/password")
		os.Exit(1)
	}

	// Execute shell command
	output, err := runCredCommand(fmt.Sprintf("cred_set %q %q", key, value))
	if err != nil {
		fmt.Fprintln(os.Stderr, output)
		os.Exit(1)
	}

	fmt.Print(output)
}

// credGet retrieves a credential
func credGet(args []string) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "Usage: dcx cred get <key>")
		os.Exit(1)
	}

	key := args[0]

	// Execute shell command
	output, err := runCredCommand(fmt.Sprintf("cred_get %q", key))
	if err != nil {
		// Don't output the error message, just exit with status 1
		// The shell function already printed the error
		os.Exit(1)
	}

	// Output the clean value (for scripting)
	fmt.Print(output)
}

// credList lists all credential keys
func credList(args []string) {
	jsonOutput := false

	for _, arg := range args {
		if arg == "--json" {
			jsonOutput = true
		}
	}

	// Execute shell command
	output, err := runCredCommand("cred_list")
	if err != nil {
		fmt.Fprintln(os.Stderr, output)
		os.Exit(1)
	}

	if jsonOutput {
		// Parse output into JSON array
		lines := strings.Split(strings.TrimSpace(output), "\n")
		var keys []string
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if line != "" {
				keys = append(keys, line)
			}
		}

		jsonBytes, err := json.Marshal(keys)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error encoding JSON: %v\n", err)
			os.Exit(1)
		}
		fmt.Println(string(jsonBytes))
	} else {
		fmt.Print(output)
	}
}

// credDelete removes a credential
func credDelete(args []string) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "Usage: dcx cred delete <key> [-y]")
		os.Exit(1)
	}

	key := args[0]
	autoConfirm := false

	for _, arg := range args[1:] {
		if arg == "-y" || arg == "--yes" {
			autoConfirm = true
		}
	}

	// Confirm deletion unless -y flag
	if !autoConfirm {
		fmt.Printf("Delete credential '%s'? [y/N] ", key)
		reader := bufio.NewReader(os.Stdin)
		response, _ := reader.ReadString('\n')
		response = strings.TrimSpace(strings.ToLower(response))

		if response != "y" && response != "yes" {
			fmt.Println("Cancelled")
			os.Exit(0)
		}
	}

	// Execute shell command
	output, err := runCredCommand(fmt.Sprintf("cred_delete %q", key))
	if err != nil {
		fmt.Fprintln(os.Stderr, output)
		os.Exit(1)
	}

	fmt.Print(output)
}

// credExport exports credentials as environment variables
func credExport(args []string) {
	prefix := ""
	showEnv := false

	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--prefix":
			if i+1 < len(args) {
				prefix = args[i+1]
				i++
			} else {
				fmt.Fprintln(os.Stderr, "Error: --prefix requires a value")
				os.Exit(1)
			}
		case "--env":
			showEnv = true
		}
	}

	// Build command
	var cmd string
	if prefix != "" {
		cmd = fmt.Sprintf("cred_export %q", prefix)
	} else {
		cmd = "cred_export"
	}

	// Execute shell command
	output, err := runCredCommand(cmd)
	if err != nil {
		fmt.Fprintln(os.Stderr, output)
		os.Exit(1)
	}

	if showEnv {
		// Already in export format
		fmt.Print(output)
	} else {
		fmt.Print(output)
	}
}

// runCredCommand executes a cred.sh function and returns output
func runCredCommand(funcCall string) (string, error) {
	libDir := getLibDir()
	credShPath := filepath.Join(libDir, "cred.sh")

	// Check if cred.sh exists
	if _, err := os.Stat(credShPath); os.IsNotExist(err) {
		return "", fmt.Errorf("credential library not found: %s\nEnsure DCX_HOME is set correctly", credShPath)
	}

	// Build bash command that sources cred.sh and calls the function
	bashCmd := fmt.Sprintf("source %q && %s", credShPath, funcCall)

	// Execute with bash
	cmd := exec.Command("bash", "-c", bashCmd)

	// Set DCX_HOME in environment
	cmd.Env = append(os.Environ(), fmt.Sprintf("DCX_HOME=%s", getDCHome()))

	// Inherit stdin for password prompts
	cmd.Stdin = os.Stdin

	// Capture output
	output, err := cmd.CombinedOutput()

	return string(output), err
}
