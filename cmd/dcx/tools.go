package main

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// ToolConfig represents a single tool configuration
type ToolConfig struct {
	Version     string            `yaml:"version"`
	Required    bool              `yaml:"required"`
	Description string            `yaml:"description"`
	URLs        map[string]string `yaml:"urls"`
	Binary      string            `yaml:"binary"`
	Extract     string            `yaml:"extract"`
}

// ToolsConfig represents the full tools.yaml configuration
type ToolsConfig struct {
	Settings struct {
		AutoDownload   bool   `yaml:"auto_download"`
		VerifyChecksum bool   `yaml:"verify_checksum"`
		CacheDir       string `yaml:"cache_dir"`
	} `yaml:"settings"`
	Tools map[string]ToolConfig `yaml:"tools"`
}

// loadToolsConfig reads and parses etc/tools.yaml
func loadToolsConfig() (*ToolsConfig, error) {
	configPath := filepath.Join(getEtcDir(), "tools.yaml")

	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read tools.yaml: %w", err)
	}

	var config ToolsConfig
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse tools.yaml: %w", err)
	}

	return &config, nil
}

// handleTools handles the "dcx tools" subcommand
func handleTools(args []string) {
	if len(args) == 0 {
		toolsList("table")
		return
	}

	switch args[0] {
	case "list", "ls":
		format := "table"
		if len(args) > 1 {
			format = args[1]
		}
		toolsList(format)

	case "install", "add":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "Usage: dcx tools install <tool-name>")
			fmt.Fprintln(os.Stderr, "       dcx tools install --all")
			os.Exit(1)
		}
		force := len(args) > 2 && (args[2] == "--force" || args[2] == "-f")
		if args[1] == "--all" || args[1] == "all" {
			toolsInstallAll(force)
		} else {
			if err := toolsInstall(args[1], force); err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				os.Exit(1)
			}
		}

	case "check":
		autoInstall := len(args) > 1 && args[1] == "--auto"
		if err := toolsCheck(autoInstall); err != nil {
			os.Exit(1)
		}

	case "help", "-h", "--help":
		printToolsHelp()

	default:
		fmt.Fprintf(os.Stderr, "Unknown tools command: %s\n", args[0])
		printToolsHelp()
		os.Exit(1)
	}
}

func toolsList(format string) {
	config, err := loadToolsConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	binDir := getBinDir()

	switch format {
	case "json":
		fmt.Println("[")
		first := true
		for name, tool := range config.Tools {
			if !first {
				fmt.Println(",")
			}
			first = false

			status := "missing"
			if _, err := findBinary(name); err == nil {
				status = "installed"
			}

			fmt.Printf(`  {"name": "%s", "version": "%s", "required": %t, "status": "%s"}`,
				name, tool.Version, tool.Required, status)
		}
		fmt.Println()
		fmt.Println("]")

	case "simple":
		for name := range config.Tools {
			status := "[ ]"
			if _, err := findBinary(name); err == nil {
				status = "[x]"
			}
			fmt.Printf("%s %s\n", status, name)
		}

	case "table":
		fallthrough
	default:
		fmt.Printf("%-12s %-10s %-10s %-10s %s\n", "Tool", "Version", "Required", "Status", "Path")
		fmt.Printf("%-12s %-10s %-10s %-10s %s\n", "----", "-------", "--------", "------", "----")

		for name, tool := range config.Tools {
			required := "no"
			if tool.Required {
				required = "yes"
			}

			status := "Missing"
			path := "-"

			foundPath, err := findBinary(name)
			if err == nil {
				path = foundPath
				if filepath.HasPrefix(foundPath, binDir) {
					status = "OK"
				} else {
					status = "System"
				}
			}

			fmt.Printf("%-12s %-10s %-10s %-10s %s\n", name, tool.Version, required, status, path)
		}
	}
}

func toolsInstall(name string, force bool) error {
	config, err := loadToolsConfig()
	if err != nil {
		return err
	}

	tool, ok := config.Tools[name]
	if !ok {
		return fmt.Errorf("unknown tool: %s", name)
	}

	binDir := getBinDir()
	destPath := filepath.Join(binDir, name)

	// Check if already installed
	if !force && isExecutable(destPath) {
		fmt.Printf("%s is already installed at %s\n", name, destPath)
		return nil
	}

	platform := detectPlatform()
	url, ok := tool.URLs[platform]
	if !ok {
		return fmt.Errorf("no download URL for %s on platform %s", name, platform)
	}

	// Replace version placeholder
	url = strings.ReplaceAll(url, "{version}", tool.Version)

	fmt.Printf("Installing %s v%s...\n", name, tool.Version)
	fmt.Printf("  URL: %s\n", url)

	// Download
	cacheDir := getCacheDir()
	os.MkdirAll(cacheDir, 0755)
	os.MkdirAll(binDir, 0755)

	ext := ".tar.gz"
	if tool.Extract == "zip" || strings.HasSuffix(url, ".zip") {
		ext = ".zip"
	}
	archivePath := filepath.Join(cacheDir, fmt.Sprintf("%s-%s%s", name, tool.Version, ext))

	fmt.Println("  Downloading...")
	if err := downloadFile(url, archivePath); err != nil {
		return fmt.Errorf("download failed: %w", err)
	}

	// Extract
	fmt.Println("  Extracting...")
	if ext == ".zip" {
		if err := extractFromZip(archivePath, name, destPath); err != nil {
			os.Remove(archivePath)
			return fmt.Errorf("extraction failed: %w", err)
		}
	} else {
		if err := extractFromTarGz(archivePath, name, destPath); err != nil {
			os.Remove(archivePath)
			return fmt.Errorf("extraction failed: %w", err)
		}
	}

	// Cleanup
	os.Remove(archivePath)

	fmt.Printf("  Installed: %s\n", destPath)
	return nil
}

func toolsInstallAll(force bool) {
	config, err := loadToolsConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	failed := 0
	for name := range config.Tools {
		if err := toolsInstall(name, force); err != nil {
			fmt.Fprintf(os.Stderr, "Failed to install %s: %v\n", name, err)
			failed++
		}
	}

	if failed == 0 {
		fmt.Println("All tools installed!")
	} else {
		fmt.Printf("%d tool(s) failed to install\n", failed)
		os.Exit(1)
	}
}

func toolsCheck(autoInstall bool) error {
	config, err := loadToolsConfig()
	if err != nil {
		return err
	}

	var missing []string
	for name, tool := range config.Tools {
		if !tool.Required {
			continue
		}
		if _, err := findBinary(name); err != nil {
			missing = append(missing, name)
		}
	}

	if len(missing) == 0 {
		fmt.Println("All required tools are available.")
		return nil
	}

	fmt.Printf("Missing required tools: %s\n", strings.Join(missing, ", "))

	if autoInstall {
		fmt.Println("Auto-installing missing tools...")
		for _, name := range missing {
			if err := toolsInstall(name, false); err != nil {
				fmt.Fprintf(os.Stderr, "Failed to install %s: %v\n", name, err)
			}
		}
	} else {
		fmt.Println("Run 'dcx tools install --all' to install them.")
		return fmt.Errorf("missing required tools")
	}

	return nil
}

func downloadFile(url, dest string) error {
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("HTTP %d: %s", resp.StatusCode, resp.Status)
	}

	out, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	return err
}

func extractFromTarGz(archive, binaryName, dest string) error {
	f, err := os.Open(archive)
	if err != nil {
		return err
	}
	defer f.Close()

	gzr, err := gzip.NewReader(f)
	if err != nil {
		return err
	}
	defer gzr.Close()

	tr := tar.NewReader(gzr)

	for {
		header, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}

		// Skip directories
		if header.Typeflag != tar.TypeReg {
			continue
		}

		// Find the binary - check various naming patterns
		baseName := filepath.Base(header.Name)
		if matchesBinaryName(baseName, binaryName) {
			out, err := os.OpenFile(dest, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0755)
			if err != nil {
				return err
			}
			if _, err := io.Copy(out, tr); err != nil {
				out.Close()
				return err
			}
			out.Close()
			return nil
		}
	}

	return fmt.Errorf("binary %s not found in archive", binaryName)
}

func extractFromZip(archive, binaryName, dest string) error {
	r, err := zip.OpenReader(archive)
	if err != nil {
		return err
	}
	defer r.Close()

	for _, f := range r.File {
		if f.FileInfo().IsDir() {
			continue
		}

		baseName := filepath.Base(f.Name)
		if matchesBinaryName(baseName, binaryName) {
			rc, err := f.Open()
			if err != nil {
				return err
			}

			out, err := os.OpenFile(dest, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0755)
			if err != nil {
				rc.Close()
				return err
			}

			_, err = io.Copy(out, rc)
			rc.Close()
			out.Close()

			if err != nil {
				return err
			}
			return nil
		}
	}

	return fmt.Errorf("binary %s not found in archive", binaryName)
}

// matchesBinaryName checks if a filename matches the expected binary name
// Handles patterns like: gum, gum_0.14.5, yq_linux_amd64, sg, etc.
func matchesBinaryName(filename, binaryName string) bool {
	// Exact match
	if filename == binaryName {
		return true
	}

	// Starts with binary name followed by underscore or hyphen
	if strings.HasPrefix(filename, binaryName+"_") || strings.HasPrefix(filename, binaryName+"-") {
		return true
	}

	// For yq specifically, handle yq_os_arch pattern
	if binaryName == "yq" && strings.HasPrefix(filename, "yq_") {
		return true
	}

	return false
}

func printToolsHelp() {
	fmt.Println(`Usage: dcx tools <command> [options]

Commands:
  list [format]      List tools (table, json, simple)
  install <tool>     Install a specific tool
  install --all      Install all configured tools
  check              Check if required tools are available
  check --auto       Check and auto-install missing tools
  help               Show this help

Examples:
  dcx tools list
  dcx tools install gum
  dcx tools install --all
  dcx tools check --auto`)
}
