package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// ProjectConfig represents etc/project.yaml
type ProjectConfig struct {
	Project struct {
		Name     string `yaml:"name"`
		FullName string `yaml:"full_name"`
		Repo     string `yaml:"repo"`
	} `yaml:"project"`
}

// loadProjectConfig reads and parses etc/project.yaml
func loadProjectConfig() (*ProjectConfig, error) {
	configPath := filepath.Join(getEtcDir(), "project.yaml")

	data, err := os.ReadFile(configPath)
	if err != nil {
		// Return defaults if file doesn't exist
		return &ProjectConfig{
			Project: struct {
				Name     string `yaml:"name"`
				FullName string `yaml:"full_name"`
				Repo     string `yaml:"repo"`
			}{
				Name:     "DCX",
				FullName: "Datacosmos Command eXecutor",
				Repo:     "datacosmos-br/dcx",
			},
		}, nil
	}

	var config ProjectConfig
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse project.yaml: %w", err)
	}

	return &config, nil
}

// handleConfig handles the "dcx config" subcommand
func handleConfig(args []string) {
	if len(args) == 0 {
		configShow()
		return
	}

	switch args[0] {
	case "show":
		configShow()

	case "get":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "Usage: dcx config get <key>")
			os.Exit(1)
		}
		configGet(args[1])

	case "paths":
		configPaths()

	case "yaml-get":
		// dcx config yaml-get <file> <key> [default]
		if len(args) < 3 {
			fmt.Fprintln(os.Stderr, "Usage: dcx config yaml-get <file> <key> [default]")
			os.Exit(1)
		}
		defaultVal := ""
		if len(args) >= 4 {
			defaultVal = args[3]
		}
		yamlGet(args[1], args[2], defaultVal)

	case "yaml-set":
		// dcx config yaml-set <file> <key> <value>
		if len(args) < 4 {
			fmt.Fprintln(os.Stderr, "Usage: dcx config yaml-set <file> <key> <value>")
			os.Exit(1)
		}
		yamlSet(args[1], args[2], args[3])

	case "yaml-has":
		// dcx config yaml-has <file> <key>
		if len(args) < 3 {
			fmt.Fprintln(os.Stderr, "Usage: dcx config yaml-has <file> <key>")
			os.Exit(1)
		}
		yamlHas(args[1], args[2])

	case "yaml-keys":
		// dcx config yaml-keys <file> [path]
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "Usage: dcx config yaml-keys <file> [path]")
			os.Exit(1)
		}
		path := ""
		if len(args) >= 3 {
			path = args[2]
		}
		yamlKeys(args[1], path)

	case "help", "-h", "--help":
		printConfigHelp()

	default:
		// Treat as key to get
		configGet(args[0])
	}
}

func configShow() {
	config, err := loadProjectConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Project Configuration:")
	fmt.Printf("  name: %s\n", config.Project.Name)
	fmt.Printf("  full_name: %s\n", config.Project.FullName)
	fmt.Printf("  repo: %s\n", config.Project.Repo)
	fmt.Println()
	fmt.Println("Paths:")
	fmt.Printf("  DC_HOME: %s\n", getDCHome())
	fmt.Printf("  bin: %s\n", getBinDir())
	fmt.Printf("  etc: %s\n", getEtcDir())
	fmt.Printf("  cache: %s\n", getCacheDir())
}

func configGet(key string) {
	config, err := loadProjectConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	switch key {
	case "name", "project.name":
		fmt.Println(config.Project.Name)
	case "full_name", "project.full_name":
		fmt.Println(config.Project.FullName)
	case "repo", "project.repo":
		fmt.Println(config.Project.Repo)
	case "home", "DC_HOME":
		fmt.Println(getDCHome())
	case "bin", "bin_dir":
		fmt.Println(getBinDir())
	case "etc", "etc_dir":
		fmt.Println(getEtcDir())
	case "cache", "cache_dir":
		fmt.Println(getCacheDir())
	case "platform":
		fmt.Println(detectPlatform())
	default:
		fmt.Fprintf(os.Stderr, "Unknown config key: %s\n", key)
		os.Exit(1)
	}
}

func configPaths() {
	fmt.Printf("DC_HOME=%s\n", getDCHome())
	fmt.Printf("DC_BIN_DIR=%s\n", getBinDir())
	fmt.Printf("DC_ETC_DIR=%s\n", getEtcDir())
	fmt.Printf("DC_CACHE_DIR=%s\n", getCacheDir())
	fmt.Printf("DC_PLATFORM=%s\n", detectPlatform())
}

func printConfigHelp() {
	fmt.Println(`Usage: dcx config <command> [options]

Commands:
  show                         Show all configuration
  get <key>                    Get a specific config value
  paths                        Print paths as shell variables
  yaml-get <file> <key> [def]  Get value from YAML file
  yaml-set <file> <key> <val>  Set value in YAML file
  yaml-has <file> <key>        Check if key exists (exit 0/1)
  yaml-keys <file> [path]      List keys at path

Available Keys:
  name           Project short name (DCX)
  full_name      Project full name
  repo           GitHub repository
  home           DC_HOME path
  bin            bin directory path
  etc            etc directory path
  cache          cache directory path
  platform       Current platform

Examples:
  dcx config show
  dcx config get repo
  dcx config paths
  dcx config yaml-get config.yaml database.host localhost
  dcx config yaml-set config.yaml log.level debug
  eval "$(dcx config paths)"  # Export paths to shell`)
}

// yamlGet gets a value from a YAML file using dot-notation key
func yamlGet(file, key, defaultVal string) {
	data, err := os.ReadFile(file)
	if err != nil {
		fmt.Println(defaultVal)
		return
	}

	var root map[string]interface{}
	if err := yaml.Unmarshal(data, &root); err != nil {
		fmt.Println(defaultVal)
		return
	}

	value := getNestedValue(root, key)
	if value == nil {
		fmt.Println(defaultVal)
		return
	}

	fmt.Println(value)
}

// yamlSet sets a value in a YAML file using dot-notation key
func yamlSet(file, key, value string) {
	var root map[string]interface{}

	data, err := os.ReadFile(file)
	if err == nil {
		yaml.Unmarshal(data, &root)
	}
	if root == nil {
		root = make(map[string]interface{})
	}

	setNestedValue(root, key, value)

	output, err := yaml.Marshal(root)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	// Create directory if needed
	dir := filepath.Dir(file)
	if dir != "" && dir != "." {
		os.MkdirAll(dir, 0755)
	}

	if err := os.WriteFile(file, output, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

// yamlHas checks if a key exists in YAML file
func yamlHas(file, key string) {
	data, err := os.ReadFile(file)
	if err != nil {
		os.Exit(1)
	}

	var root map[string]interface{}
	if err := yaml.Unmarshal(data, &root); err != nil {
		os.Exit(1)
	}

	if getNestedValue(root, key) == nil {
		os.Exit(1)
	}
	os.Exit(0)
}

// yamlKeys lists keys at a path in YAML file
func yamlKeys(file, path string) {
	data, err := os.ReadFile(file)
	if err != nil {
		return
	}

	var root map[string]interface{}
	if err := yaml.Unmarshal(data, &root); err != nil {
		return
	}

	var target map[string]interface{}
	if path == "" || path == "." {
		target = root
	} else {
		val := getNestedValue(root, path)
		if m, ok := val.(map[string]interface{}); ok {
			target = m
		} else {
			return
		}
	}

	for k := range target {
		fmt.Println(k)
	}
}

// getNestedValue gets a value from a nested map using dot notation
func getNestedValue(m map[string]interface{}, key string) interface{} {
	parts := strings.Split(key, ".")
	var current interface{} = m

	for _, part := range parts {
		if cm, ok := current.(map[string]interface{}); ok {
			current = cm[part]
		} else {
			return nil
		}
	}

	return current
}

// setNestedValue sets a value in a nested map using dot notation
func setNestedValue(m map[string]interface{}, key string, value string) {
	parts := strings.Split(key, ".")

	for i := 0; i < len(parts)-1; i++ {
		part := parts[i]
		if _, ok := m[part]; !ok {
			m[part] = make(map[string]interface{})
		}
		if next, ok := m[part].(map[string]interface{}); ok {
			m = next
		} else {
			m[part] = make(map[string]interface{})
			m = m[part].(map[string]interface{})
		}
	}

	m[parts[len(parts)-1]] = value
}
