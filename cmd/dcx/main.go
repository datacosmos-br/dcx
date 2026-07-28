// DCX - Datacosmos Command eXecutor
// Go CLI for tool management and platform utilities
package main

import (
	"fmt"
	"os"
)

// Version is set at build time
var Version = "dev"

func main() {
	if len(os.Args) < 2 {
		printHelp()
		os.Exit(0)
	}

	switch os.Args[1] {
	case "version", "-v", "--version":
		printVersion()
	case "platform":
		fmt.Println(detectPlatform())
	case "binary":
		handleBinary(os.Args[2:])
	case "tools":
		handleTools(os.Args[2:])
	case "config":
		handleConfig(os.Args[2:])
	case "cred":
		handleCred(os.Args[2:])
	case "validate":
		handleValidate()
	case "lint":
		handleLint(os.Args[2:])
	case "help", "-h", "--help":
		printHelp()
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", os.Args[1])
		fmt.Fprintln(os.Stderr, "Run 'dcx help' for usage")
		os.Exit(1)
	}
}

func printVersion() {
	dcHome := getDCHome()
	platform := detectPlatform()

	fmt.Printf("DCX v%s - Datacosmos Command eXecutor\n", Version)
	fmt.Printf("Platform: %s\n", platform)
	fmt.Printf("DCX_HOME: %s\n", dcHome)
	fmt.Println()

	// List bundled tools
	fmt.Println("Bundled tools:")
	tools := []string{"gum", "yq", "rg", "fd", "sd", "sg"}
	for _, tool := range tools {
		path, err := findBinary(tool)
		if err != nil {
			if tool == "gum" || tool == "yq" {
				fmt.Printf("  %s: (not found - required)\n", tool)
			} else {
				fmt.Printf("  %s: (optional)\n", tool)
			}
		} else {
			fmt.Printf("  %s: %s\n", tool, path)
		}
	}
}

func printHelp() {
	fmt.Printf(`DCX v%s - Datacosmos Command eXecutor

Usage: dcx <command> [options]

Commands:
  version     Show version and bundled tools status
  platform    Print current platform (e.g., linux-amd64)
  binary      Find bundled or system binary
  tools       Manage bundled tools (list, install, check)
  config      Manage configuration
  validate    Test all bundled tools work correctly
  lint        Lint shell scripts with ast-grep
  help        Show this help message

Binary Commands:
  dcx binary find <name>    Find path to binary (bundled or system)
  dcx binary list           List all known binaries

Tools Commands:
  dcx tools list            List all configured tools
  dcx tools install <name>  Install a specific tool
  dcx tools install --all   Install all configured tools
  dcx tools check           Check if required tools are available

Environment:
  DCX_HOME     Installation directory

For more information: https://github.com/datacosmos-br/dcx
`, Version)
}
