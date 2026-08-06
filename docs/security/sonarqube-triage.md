# Triagem SonarCloud — datacosmos-br/dcx

Gerado do dump da plataforma SonarCloud (2026-08-06).

Bead: `dcx-1v9.1`

## Resumo

**131 issues** — BLOCKER 0, CRITICAL 12, MAJOR 110, MINOR 9
Tipos: VULNERABILITY 8, BUG 1, CODE_SMELL 122 · **Debt total: 629min**

| regra | issues |
|---|---|
| `shelldre:S7682` | 93 |
| `shell:S6506` | 7 |
| `go:S3776` | 5 |
| `go:S1192` | 5 |
| `shelldre:S7679` | 5 |
| `shelldre:S1481` | 5 |
| `shelldre:S1066` | 4 |
| `shelldre:S1192` | 3 |
| `shelldre:S131` | 2 |
| `go:S3923` | 1 |

## Como usar

Cada issue traz a **mensagem do SonarQube** (descreve o problema e o impacto), o **código real** (linha `>>>`), o tipo e o effort estimado.
**Decisão**: `corrigir` / `falso-positivo` (marcar na plataforma com justificativa) / `risco-aceito`. Ordem: BLOCKER → CRITICAL → VULNERABILITY → MAJOR. CODE_SMELL em volume pede correção de padrão.

## Issues

### 1 · 🟠 CRITICAL · CODE_SMELL · `go:S3776`
**Local**: `cmd/dcx/config.go:50` · **Effort**: 6min

> Refactor this method to reduce its Cognitive Complexity from 16 to the 15 allowed.

```go
       46  	return &config, nil
       47  }
       48  
       49  // handleConfig handles the "dcx config" subcommand
>>>    50  func handleConfig(args []string) {
       51  	if len(args) == 0 {
       52  		configShow()
       53  		return
       54  	}
```

**Decisão**: 

### 2 · 🟠 CRITICAL · CODE_SMELL · `go:S1192`
**Local**: `cmd/dcx/cred.go:20` · **Effort**: 6min

> Define a constant instead of duplicating this literal "cred.sh" 3 times.

```go
       16  	dcHome := getDCHome()
       17  
       18  	// 1. Development: lib/ in DCX_HOME
       19  	devPath := filepath.Join(dcHome, "lib")
>>>    20  	if _, err := os.Stat(filepath.Join(devPath, "cred.sh")); err == nil {
       21  		return devPath
       22  	}
       23  
       24  	// 2. Installed: share/DCX/lib/
```

**Decisão**: 

### 3 · 🟠 CRITICAL · CODE_SMELL · `go:S1192`
**Local**: `cmd/dcx/platform.go:21` · **Effort**: 6min

> Define a constant instead of duplicating this literal "tools.yaml" 3 times.

```go
       17  // has the DCX project/install layout.
       18  func findDCHomeFrom(start string) (string, bool) {
       19  	dir := start
       20  	for i := 0; i < 6; i++ {
>>>    21  		if _, err := os.Stat(filepath.Join(dir, "etc", "tools.yaml")); err == nil {
       22  			return dir, true
       23  		}
       24  
       25  		parent := filepath.Dir(dir)
```

**Decisão**: 

### 4 · 🟠 CRITICAL · CODE_SMELL · `go:S3776`
**Local**: `cmd/dcx/tools.go:87` · **Effort**: 8min

> Refactor this method to reduce its Cognitive Complexity from 18 to the 15 allowed.

```go
       83  	return &config, nil
       84  }
       85  
       86  // handleTools handles the "dcx tools" subcommand
>>>    87  func handleTools(args []string) {
       88  	if len(args) == 0 {
       89  		toolsList("table")
       90  		return
       91  	}
```

**Decisão**: 

### 5 · 🟠 CRITICAL · CODE_SMELL · `go:S3776`
**Local**: `cmd/dcx/tools.go:133` · **Effort**: 18min

> Refactor this method to reduce its Cognitive Complexity from 28 to the 15 allowed.

```go
      129  		os.Exit(1)
      130  	}
      131  }
      132  
>>>   133  func toolsList(format string) {
      134  	config, err := loadToolsConfig()
      135  	if err != nil {
      136  		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
      137  		os.Exit(1)
```

**Decisão**: 

### 6 · 🟠 CRITICAL · CODE_SMELL · `go:S3776`
**Local**: `cmd/dcx/tools.go:357` · **Effort**: 7min

> Refactor this method to reduce its Cognitive Complexity from 17 to the 15 allowed.

```go
      353  	_, err = io.Copy(out, resp.Body)
      354  	return err
      355  }
      356  
>>>   357  func extractFromTarGz(archive, binaryName, dest string) error {
      358  	f, err := os.Open(archive)
      359  	if err != nil {
      360  		return err
      361  	}
```

**Decisão**: 

### 7 · 🟠 CRITICAL · CODE_SMELL · `go:S3776`
**Local**: `cmd/dcx/validate.go:12` · **Effort**: 28min

> Refactor this method to reduce its Cognitive Complexity from 38 to the 15 allowed.

```go
        8  	"strings"
        9  )
       10  
       11  // handleValidate runs validation tests on all bundled tools
>>>    12  func handleValidate() {
       13  	tmpDir, err := os.MkdirTemp("", "dcx-validate-*")
       14  	if err != nil {
       15  		fmt.Fprintf(os.Stderr, "Failed to create temp dir: %v\n", err)
       16  		os.Exit(1)
```

**Decisão**: 

### 8 · 🟠 CRITICAL · CODE_SMELL · `go:S1192`
**Local**: `cmd/dcx/validate.go:28` · **Effort**: 12min

> Define a constant instead of duplicating this literal "--version" 6 times.

```go
       24  
       25  	// Test GUM (required)
       26  	fmt.Print("  gum: ")
       27  	if gum, err := findBinary("gum"); err == nil {
>>>    28  		if out, err := exec.Command(gum, "--version").Output(); err == nil {
       29  			fmt.Printf("OK (%s)\n", strings.TrimSpace(string(out)))
       30  		} else {
       31  			fmt.Println("FAIL (not working)")
       32  			failed++
```

**Decisão**: 

### 9 · 🟠 CRITICAL · CODE_SMELL · `go:S1192`
**Local**: `cmd/dcx/validate.go:31` · **Effort**: 12min

> Define a constant instead of duplicating this literal "FAIL (not working)" 6 times.

```go
       27  	if gum, err := findBinary("gum"); err == nil {
       28  		if out, err := exec.Command(gum, "--version").Output(); err == nil {
       29  			fmt.Printf("OK (%s)\n", strings.TrimSpace(string(out)))
       30  		} else {
>>>    31  			fmt.Println("FAIL (not working)")
       32  			failed++
       33  		}
       34  	} else {
       35  		fmt.Println("MISSING (required)")
```

**Decisão**: 

### 10 · 🟠 CRITICAL · CODE_SMELL · `go:S1192`
**Local**: `cmd/dcx/validate.go:70` · **Effort**: 8min

> Define a constant instead of duplicating this literal "SKIP (optional)" 4 times.

```go
       66  		} else {
       67  			fmt.Println("FAIL (not working)")
       68  		}
       69  	} else {
>>>    70  		fmt.Println("SKIP (optional)")
       71  	}
       72  
       73  	// Test FD (optional)
       74  	fmt.Print("  fd:  ")
```

**Decisão**: 

### 11 · 🟠 CRITICAL · CODE_SMELL · `shelldre:S131`
**Local**: `scripts/build-binaries.sh:63` · **Effort**: 5min

> Add a default case (*) to handle unexpected values.

```bash
       59      os="${platform%-*}"
       60      arch="${platform#*-}"
       61  
       62      # Map arch names
>>>    63      case "$arch" in
       64          amd64) arch="x86_64" ;;
       65          arm64) arch="arm64" ;;
       66      esac
       67  
```

**Decisão**: 

### 12 · 🟠 CRITICAL · CODE_SMELL · `shelldre:S131`
**Local**: `scripts/build-binaries.sh:264` · **Effort**: 5min

> Add a default case (*) to handle unexpected values.

```bash
      260      done
      261  
      262      mkdir -p "$BIN_DIR"
      263  
>>>   264      case "$cmd" in
      265          list)
      266              echo "Tool Versions:"
      267              echo "  gum: $GUM_VERSION"
      268              echo "  yq:  $YQ_VERSION"
```

**Decisão**: 

### 13 · 🟡 MAJOR · BUG · `go:S3923`
**Local**: `cmd/dcx/cred.go:253` · **Effort**: 15min

> Remove this conditional structure or edit its code blocks so that they're not all the same.

```go
      249  		fmt.Fprintln(os.Stderr, output)
      250  		os.Exit(1)
      251  	}
      252  
>>>   253  	if showEnv {
      254  		// Already in export format
      255  		fmt.Print(output)
      256  	} else {
      257  		fmt.Print(output)
```

**Decisão**: 

### 14 · 🟡 MAJOR · VULNERABILITY · `shell:S6506`
**Local**: `install.sh:156` · **Effort**: 30min

> Not enforcing HTTPS here might allow for redirections to insecure websites. Make sure it is safe here.

```bash
      152      local api_url="${GITHUB_API}/releases/latest"
      153      local response version
      154  
      155      if _command_exists curl; then
>>>   156          response=$(curl -fsSL --connect-timeout 5 "$api_url" 2>/dev/null) || return 1
      157      elif _command_exists wget; then
      158          response=$(wget -qO- --timeout=5 "$api_url" 2>/dev/null) || return 1
      159      fi
      160  
```

**Decisão**: 

### 15 · 🟡 MAJOR · VULNERABILITY · `shell:S6506`
**Local**: `install.sh:158` · **Effort**: 30min

> Not disabling redirects might allow for redirections to insecure websites. Make sure it is safe here.

```bash
      154  
      155      if _command_exists curl; then
      156          response=$(curl -fsSL --connect-timeout 5 "$api_url" 2>/dev/null) || return 1
      157      elif _command_exists wget; then
>>>   158          response=$(wget -qO- --timeout=5 "$api_url" 2>/dev/null) || return 1
      159      fi
      160  
      161      # Extract version from tag_name
      162      version=$(echo "$response" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name"[^"]*"\([^"]*\)".*/\1/' | sed 's/^v//')
```

**Decisão**: 

### 16 · 🟡 MAJOR · VULNERABILITY · `shell:S6506`
**Local**: `install.sh:484` · **Effort**: 30min

> Not enforcing HTTPS here might allow for redirections to insecure websites. Make sure it is safe here.

```bash
      480                  ;;
      481              --update|-u)
      482                  # Self-update: download and run latest installer
      483                  _info "Updating installer..."
>>>   484                  exec bash <(curl -fsSL "${GITHUB_RAW}/install.sh") "$@"
      485                  ;;
      486              *)
      487                  _warn "Unknown option: $1"
      488                  shift
```

**Decisão**: 

### 17 · 🟡 MAJOR · VULNERABILITY · `shell:S6506`
**Local**: `install.sh:561` · **Effort**: 30min

> Not enforcing HTTPS here might allow for redirections to insecure websites. Make sure it is safe here.

```bash
      557      local plugin_install_url="https://raw.githubusercontent.com/${plugin_repo}/main/install.sh"
      558  
      559      _step "Installing plugin: ${plugin_name}..."
      560  
>>>   561      if curl -fsSL "$plugin_install_url" 2>/dev/null | bash -s -- --skip-dcx; then
      562          _log "Plugin '${plugin_name}' installed"
      563          return 0
      564      else
      565          _warn "Failed to install plugin '${plugin_name}' from ${plugin_repo}"
```

**Decisão**: 

### 18 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/config.sh:22` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       18  #   $1 - Config file path
       19  #   $2 - Key path (dot notation, e.g., "database.host")
       20  #   $3 - Default value (optional)
       21  #-------------------------------------------------------------------------------
>>>    22  config_get() {
       23      local file="$1"
       24      local key="$2"
       25      local default="${3:-}"
       26  
```

**Decisão**: 

### 19 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/config.sh:36` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       32  #-------------------------------------------------------------------------------
       33  # Usage: config_set config.yaml "database.host" "newhost"
       34  # Creates the file if it doesn't exist.
       35  #-------------------------------------------------------------------------------
>>>    36  config_set() {
       37      local file="$1"
       38      local key="$2"
       39      local value="$3"
       40  
```

**Decisão**: 

### 20 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/config.sh:50` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       46  #-------------------------------------------------------------------------------
       47  # Usage: config_has config.yaml "database.host"
       48  # Returns 0 if key exists, 1 otherwise.
       49  #-------------------------------------------------------------------------------
>>>    50  config_has() {
       51      local file="$1"
       52      local key="$2"
       53  
       54      "$DCX_GO" config yaml-has "$file" "$key"
```

**Decisão**: 

### 21 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/config.sh:63` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       59  #-------------------------------------------------------------------------------
       60  # Usage: config_keys config.yaml "database"
       61  # Returns keys as newline-separated list.
       62  #-------------------------------------------------------------------------------
>>>    63  config_keys() {
       64      local file="$1"
       65      local path="${2:-.}"
       66  
       67      "$DCX_GO" config yaml-keys "$file" "$path"
```

**Decisão**: 

### 22 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:41` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       37      return 1
       38  }
       39  
       40  # Platform detection via Go
>>>    41  dc_detect_platform() {
       42      "$DCX_GO" config get platform
       43  }
       44  
       45  # Set platform variable (used by other modules)
```

**Decisão**: 

### 23 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:50` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       46  DCX_PLATFORM=$(dc_detect_platform)
       47  export DCX_PLATFORM
       48  
       49  # Binary discovery via Go
>>>    50  _dc_find_binary() {
       51      "$DCX_GO" binary find "$1" 2>/dev/null
       52  }
       53  
       54  # Binary check with error message
```

**Decisão**: 

### 24 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7679`
**Local**: `lib/core.sh:51` · **Effort**: 5min

> Assign this positional parameter to a local variable.

```bash
       47  export DCX_PLATFORM
       48  
       49  # Binary discovery via Go
       50  _dc_find_binary() {
>>>    51      "$DCX_GO" binary find "$1" 2>/dev/null
       52  }
       53  
       54  # Binary check with error message
       55  _dc_check_binary() {
```

**Decisão**: 

### 25 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:65` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       61      return 1
       62  }
       63  
       64  # Confirmation with gum
>>>    65  dc_confirm() {
       66      local prompt="$1"
       67      local gum_bin
       68      gum_bin=$(_dc_find_binary gum) || gum_bin=""
       69      if [[ -n "$gum_bin" && -t 0 && -t 1 ]]; then
```

**Decisão**: 

### 26 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:85` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       81  declare -gA _DCX_MODULE_FILES=()
       82  declare -gA _DCX_MODULE_DEPS=()
       83  declare -gA _DCX_MODULE_LOADED=()
       84  
>>>    85  core_register_module() {
       86      local name="$1" file="$2" deps="${3:-}"
       87      _DCX_MODULE_FILES[$name]="$file"
       88      _DCX_MODULE_DEPS[$name]="$deps"
       89  }
```

**Decisão**: 

### 27 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:112` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      108      source "$file" || { echo "ERROR: Failed to load: $module" >&2; return 1; }
      109      _DCX_MODULE_LOADED[$module]=1
      110  }
      111  
>>>   112  core_require() { dc_init; core_load "$@"; }
      113  dc_require() { dc_init; }
      114  dc_source() { core_load "$@"; }
      115  
      116  #===============================================================================
```

**Decisão**: 

### 28 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:113` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      109      _DCX_MODULE_LOADED[$module]=1
      110  }
      111  
      112  core_require() { dc_init; core_load "$@"; }
>>>   113  dc_require() { dc_init; }
      114  dc_source() { core_load "$@"; }
      115  
      116  #===============================================================================
      117  # INITIALIZATION
```

**Decisão**: 

### 29 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:114` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      110  }
      111  
      112  core_require() { dc_init; core_load "$@"; }
      113  dc_require() { dc_init; }
>>>   114  dc_source() { core_load "$@"; }
      115  
      116  #===============================================================================
      117  # INITIALIZATION
      118  #===============================================================================
```

**Decisão**: 

### 30 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:120` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      116  #===============================================================================
      117  # INITIALIZATION
      118  #===============================================================================
      119  
>>>   120  _dc_register_builtin_modules() {
      121      core_register_module "logging" "$DCX_LIB_DIR/logging.sh" ""
      122      # runtime.sh merged into core.sh - all functions available via core.sh with core_ prefix
      123      core_register_module "config" "$DCX_LIB_DIR/config.sh" "logging"
      124      core_register_module "parallel" "$DCX_LIB_DIR/parallel.sh" "logging"
```

**Decisão**: 

### 31 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:137` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      133      DCX_VERSION=$(cat "$DCX_HOME/VERSION" 2>/dev/null || echo "0.0.0")
      134      export DCX_VERSION DCX_INITIALIZED=1
      135  }
      136  
>>>   137  dc_version() { echo "dcx v${DCX_VERSION}"; }
      138  
      139  dc_load() {
      140      dc_init
      141      core_load logging config parallel
```

**Decisão**: 

### 32 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:139` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      135  }
      136  
      137  dc_version() { echo "dcx v${DCX_VERSION}"; }
      138  
>>>   139  dc_load() {
      140      dc_init
      141      core_load logging config parallel
      142  }
      143  
```

**Decisão**: 

### 33 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:242` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      238  # Arguments:
      239  #   $1 - Spinner title
      240  #   $@ - Command to execute
      241  #-------------------------------------------------------------------------------
>>>   242  core_spin() {
      243      local title="$1"
      244      shift
      245      local gum_bin
      246      gum_bin=$(_dc_find_binary gum) || gum_bin=""
```

**Decisão**: 

### 34 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:294` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      290  # Arguments:
      291  #   $1 - Timeout in seconds
      292  #   $@ - Command to execute
      293  #-------------------------------------------------------------------------------
>>>   294  core_timeout_cmd() {
      295      local timeout_secs="$1"
      296      shift
      297      timeout "$timeout_secs" "$@"
      298  }
```

**Decisão**: 

### 35 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:306` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      302  #-------------------------------------------------------------------------------
      303  # Usage: core_run_silent some_command
      304  # Returns exit code of command.
      305  #-------------------------------------------------------------------------------
>>>   306  core_run_silent() {
      307      "$@" &>/dev/null
      308  }
      309  
      310  #-------------------------------------------------------------------------------
```

**Decisão**: 

### 36 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/core.sh:318` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      314  # Arguments:
      315  #   $1 - Error message if command fails
      316  #   $@ - Command to execute
      317  #-------------------------------------------------------------------------------
>>>   318  core_run_or_die() {
      319      local error_msg="$1"
      320      shift
      321  
      322      if ! "$@"; then
```

**Decisão**: 

### 37 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/cred.sh:132` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      128  
      129  # _cred_derive_key - Derive encryption key from password using PBKDF2
      130  # Usage: _cred_derive_key "password" "salt"
      131  # Returns: Base64 encoded key (32 bytes)
>>>   132  _cred_derive_key() {
      133      local password="$1"
      134      local salt="$2"
      135  
      136      # Use OpenSSL PBKDF2 with 100k iterations
```

**Decisão**: 

### 38 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/cred.sh:143` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      139  
      140  # _cred_prompt_password - Secure password prompt with retry logic
      141  # Usage: _cred_prompt_password "varname" "prompt"
      142  # Sets variable with name $varname
>>>   143  _cred_prompt_password() {
      144      local varname="$1"
      145      local prompt="$2"
      146  
      147      echo -n "$prompt: " >&2
```

**Decisão**: 

### 39 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/cred.sh:180` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      176  
      177  # _cred_encrypt_value - Encrypt a value with AES-256-CBC
      178  # Usage: _cred_encrypt_value "value"
      179  # Returns: base64 encoded encrypted value
>>>   180  _cred_encrypt_value() {
      181      local value="$1"
      182  
      183      # Encrypt with AES-256-CBC using PBKDF2
      184      printf '%s' "$value" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -base64 -A -pass "pass:${_CRED_MASTER_KEY}" 2>/dev/null
```

**Decisão**: 

### 40 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/cred.sh:190` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      186  
      187  # _cred_decrypt_value - Decrypt a value
      188  # Usage: _cred_decrypt_value "encrypted_base64"
      189  # Returns: Decrypted value
>>>   190  _cred_decrypt_value() {
      191      local encrypted="$1"
      192  
      193      # Decrypt with AES-256-CBC using PBKDF2
      194      printf '%s' "$encrypted" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d -base64 -A -pass "pass:${_CRED_MASTER_KEY}" 2>/dev/null
```

**Decisão**: 

### 41 · 🟡 MAJOR · CODE_SMELL · `shelldre:S1066`
**Local**: `lib/cred.sh:281` · **Effort**: 5min

> Merge this if statement with the enclosing one.

```bash
      277      fi
      278  
      279      # Auto-create on first use
      280      if [[ ! -f "$CRED_FILE" ]]; then
>>>   281          if ! _cred_init_internal; then
      282              return 1
      283          fi
      284      fi
      285  
```

**Decisão**: 

### 42 · 🟡 MAJOR · CODE_SMELL · `shelldre:S1066`
**Local**: `lib/cred.sh:288` · **Effort**: 5min

> Merge this if statement with the enclosing one.

```bash
      284      fi
      285  
      286      # Unlock if needed
      287      if [[ $_CRED_UNLOCKED -ne 1 ]]; then
>>>   288          if ! cred_open; then
      289              return 1
      290          fi
      291      fi
      292  
```

**Decisão**: 

### 43 · 🟡 MAJOR · CODE_SMELL · `shelldre:S1066`
**Local**: `lib/cred.sh:324` · **Effort**: 5min

> Merge this if statement with the enclosing one.

```bash
      320      fi
      321  
      322      # Unlock if needed
      323      if [[ $_CRED_UNLOCKED -ne 1 ]]; then
>>>   324          if ! cred_open; then
      325              return 1
      326          fi
      327      fi
      328  
```

**Decisão**: 

### 44 · 🟡 MAJOR · CODE_SMELL · `shelldre:S1066`
**Local**: `lib/cred.sh:521` · **Effort**: 5min

> Merge this if statement with the enclosing one.

```bash
      517      local prefix="${1:-}"
      518  
      519      # Unlock if needed
      520      if [[ $_CRED_UNLOCKED -ne 1 ]]; then
>>>   521          if ! cred_open; then
      522              return 1
      523          fi
      524      fi
      525  
```

**Decisão**: 

### 45 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:72` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       68  
       69  #-------------------------------------------------------------------------------
       70  # _dc_should_log - Check if message should be logged
       71  #-------------------------------------------------------------------------------
>>>    72  _dc_should_log() {
       73      local level="$1"
       74      local module="$2"
       75  
       76      local current_level="$DCX_LOG_LEVEL"
```

**Decisão**: 

### 46 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:92` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       88  
       89  #-------------------------------------------------------------------------------
       90  # _dc_log_text - Format log as text
       91  #-------------------------------------------------------------------------------
>>>    92  _dc_log_text() {
       93      local level="$1" message="$2" func="$3" file="$4" line="$5"
       94  
       95      # Use gum if available for better formatting
       96      local gum_bin="${GUM:-gum}"
```

**Decisão**: 

### 47 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:111` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      107  
      108  #-------------------------------------------------------------------------------
      109  # _dc_log_json - Format log as JSON
      110  #-------------------------------------------------------------------------------
>>>   111  _dc_log_json() {
      112      local level="$1" message="$2" func="$3" file="$4" line="$5"
      113      local timestamp
      114      timestamp=$(date -Iseconds)
      115  
```

**Decisão**: 

### 48 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:123` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      119  
      120  #-------------------------------------------------------------------------------
      121  # _dc_log_to_file - Append log to file
      122  #-------------------------------------------------------------------------------
>>>   123  _dc_log_to_file() {
      124      local level="$1" message="$2" func="$3" file="$4" line="$5"
      125      local timestamp
      126      timestamp=$(date -Iseconds)
      127  
```

**Decisão**: 

### 49 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:136` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      132  #===============================================================================
      133  # CONVENIENCE LOG FUNCTIONS
      134  #===============================================================================
      135  
>>>   136  log_debug()   { log debug "$@"; }
      137  log_info()    { log info "$@"; }
      138  log_success() { log success "$@"; }
      139  log_warn()    { log warn "$@"; }
      140  log_error()   { log error "$@"; }
```

**Decisão**: 

### 50 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:137` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      133  # CONVENIENCE LOG FUNCTIONS
      134  #===============================================================================
      135  
      136  log_debug()   { log debug "$@"; }
>>>   137  log_info()    { log info "$@"; }
      138  log_success() { log success "$@"; }
      139  log_warn()    { log warn "$@"; }
      140  log_error()   { log error "$@"; }
      141  log_fatal()   { log fatal "$@"; exit 1; }
```

**Decisão**: 

### 51 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:138` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      134  #===============================================================================
      135  
      136  log_debug()   { log debug "$@"; }
      137  log_info()    { log info "$@"; }
>>>   138  log_success() { log success "$@"; }
      139  log_warn()    { log warn "$@"; }
      140  log_error()   { log error "$@"; }
      141  log_fatal()   { log fatal "$@"; exit 1; }
      142  
```

**Decisão**: 

### 52 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:139` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      135  
      136  log_debug()   { log debug "$@"; }
      137  log_info()    { log info "$@"; }
      138  log_success() { log success "$@"; }
>>>   139  log_warn()    { log warn "$@"; }
      140  log_error()   { log error "$@"; }
      141  log_fatal()   { log fatal "$@"; exit 1; }
      142  
      143  # Aliases (for compatibility)
```

**Decisão**: 

### 53 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:140` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      136  log_debug()   { log debug "$@"; }
      137  log_info()    { log info "$@"; }
      138  log_success() { log success "$@"; }
      139  log_warn()    { log warn "$@"; }
>>>   140  log_error()   { log error "$@"; }
      141  log_fatal()   { log fatal "$@"; exit 1; }
      142  
      143  # Aliases (for compatibility)
      144  warn() { log warn "$@"; }
```

**Decisão**: 

### 54 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:141` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      137  log_info()    { log info "$@"; }
      138  log_success() { log success "$@"; }
      139  log_warn()    { log warn "$@"; }
      140  log_error()   { log error "$@"; }
>>>   141  log_fatal()   { log fatal "$@"; exit 1; }
      142  
      143  # Aliases (for compatibility)
      144  warn() { log warn "$@"; }
      145  die()  { log fatal "$@"; exit 1; }
```

**Decisão**: 

### 55 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:144` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      140  log_error()   { log error "$@"; }
      141  log_fatal()   { log fatal "$@"; exit 1; }
      142  
      143  # Aliases (for compatibility)
>>>   144  warn() { log warn "$@"; }
      145  die()  { log fatal "$@"; exit 1; }
      146  
      147  #===============================================================================
      148  # LOG CONFIGURATION
```

**Decisão**: 

### 56 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:145` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      141  log_fatal()   { log fatal "$@"; exit 1; }
      142  
      143  # Aliases (for compatibility)
      144  warn() { log warn "$@"; }
>>>   145  die()  { log fatal "$@"; exit 1; }
      146  
      147  #===============================================================================
      148  # LOG CONFIGURATION
      149  #===============================================================================
```

**Decisão**: 

### 57 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:182` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      178  
      179  #-------------------------------------------------------------------------------
      180  # log_get_module_level - Get log level for module
      181  #-------------------------------------------------------------------------------
>>>   182  log_get_module_level() {
      183      local module="$1"
      184      echo "${_DCX_MODULE_LOG_LEVELS[$module]:-$DCX_LOG_LEVEL}"
      185  }
      186  
```

**Decisão**: 

### 58 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:211` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      207  
      208  #-------------------------------------------------------------------------------
      209  # log_phase - Log start of a phase
      210  #-------------------------------------------------------------------------------
>>>   211  log_phase() {
      212      local phase="$1"
      213      local description="${2:-}"
      214      local gum_bin="${GUM:-gum}"
      215  
```

**Decisão**: 

### 59 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:228` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      224  
      225  #-------------------------------------------------------------------------------
      226  # log_step - Log a step
      227  #-------------------------------------------------------------------------------
>>>   228  log_step() {
      229      local step="$1"
      230      log_info "→ $step"
      231  }
      232  
```

**Decisão**: 

### 60 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:236` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      232  
      233  #-------------------------------------------------------------------------------
      234  # log_step_done - Log step completion
      235  #-------------------------------------------------------------------------------
>>>   236  log_step_done() {
      237      local step="$1"
      238      log_success "✓ $step"
      239  }
      240  
```

**Decisão**: 

### 61 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:244` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      240  
      241  #-------------------------------------------------------------------------------
      242  # log_progress - Log progress (n of total)
      243  #-------------------------------------------------------------------------------
>>>   244  log_progress() {
      245      local current="$1"
      246      local total="$2"
      247      local message="${3:-Processing}"
      248  
```

**Decisão**: 

### 62 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:285` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      281  
      282  #-------------------------------------------------------------------------------
      283  # log_cmd_start - Log start of a long-running command
      284  #-------------------------------------------------------------------------------
>>>   285  log_cmd_start() {
      286      local description="$1"
      287      log_info "Starting: $description"
      288  }
      289  
```

**Decisão**: 

### 63 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:293` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      289  
      290  #-------------------------------------------------------------------------------
      291  # log_cmd_end - Log end of a long-running command
      292  #-------------------------------------------------------------------------------
>>>   293  log_cmd_end() {
      294      local description="$1"
      295      local status="${2:-success}"
      296  
      297      if [[ "$status" == "success" ]]; then
```

**Decisão**: 

### 64 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:311` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      307  
      308  #-------------------------------------------------------------------------------
      309  # log_separator - Print a separator line
      310  #-------------------------------------------------------------------------------
>>>   311  log_separator() {
      312      local char="${1:--}"
      313      local width="${2:-60}"
      314      printf '%*s\n' "$width" '' | tr ' ' "$char"
      315  }
```

**Decisão**: 

### 65 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:320` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      316  
      317  #-------------------------------------------------------------------------------
      318  # log_kv - Log key-value pair
      319  #-------------------------------------------------------------------------------
>>>   320  log_kv() {
      321      local key="$1"
      322      local value="$2"
      323      local width="${3:-20}"
      324  
```

**Decisão**: 

### 66 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/logging.sh:331` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      327  
      328  #-------------------------------------------------------------------------------
      329  # log_section - Log a section header
      330  #-------------------------------------------------------------------------------
>>>   331  log_section() {
      332      local title="$1"
      333      echo ""
      334      log_separator "="
      335      echo " $title"
```

**Decisão**: 

### 67 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/parallel.sh:74` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       70  #   $1 - Max concurrent jobs
       71  #   $2 - Function name to call for each item
       72  #   $@ - Items to process
       73  #-------------------------------------------------------------------------------
>>>    74  parallel_map() {
       75      local max_jobs="$1"
       76      local func="$2"
       77      shift 2
       78  
```

**Decisão**: 

### 68 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/parallel.sh:96` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       92  #   $1 - Max concurrent jobs
       93  #   $2 - Command/function to run for each line
       94  # Reads lines from stdin and executes command with line as argument.
       95  #-------------------------------------------------------------------------------
>>>    96  parallel_pipe() {
       97      local max_jobs="$1"
       98      local cmd="$2"
       99  
      100      local -a items=()
```

**Decisão**: 

### 69 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/parallel.sh:164` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      160  # parallel_limit - Set default max concurrent jobs
      161  #-------------------------------------------------------------------------------
      162  # Usage: parallel_limit 8
      163  #-------------------------------------------------------------------------------
>>>   164  parallel_limit() {
      165      DCX_PARALLEL_MAX_JOBS="$1"
      166  }
      167  
      168  #-------------------------------------------------------------------------------
```

**Decisão**: 

### 70 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/parallel.sh:173` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      169  # parallel_cpu_count - Get number of CPU cores
      170  #-------------------------------------------------------------------------------
      171  # Usage: cores=$(parallel_cpu_count)
      172  #-------------------------------------------------------------------------------
>>>   173  parallel_cpu_count() {
      174      if [[ -f /proc/cpuinfo ]]; then
      175          grep -c ^processor /proc/cpuinfo
      176      elif command -v nproc &>/dev/null; then
      177          nproc
```

**Decisão**: 

### 71 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/parallel.sh:191` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      187  #-------------------------------------------------------------------------------
      188  # Usage: parallel_auto "cmd1" "cmd2" "cmd3"
      189  # Automatically uses number of CPU cores as max jobs.
      190  #-------------------------------------------------------------------------------
>>>   191  parallel_auto() {
      192      local max_jobs
      193      max_jobs=$(parallel_cpu_count)
      194      parallel_run "$max_jobs" "$@"
      195  }
```

**Decisão**: 

### 72 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/plugin.sh:60` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       56  # dc_discover_plugins - Discover all available plugins
       57  #-------------------------------------------------------------------------------
       58  # Returns: List of plugin directories (one per line)
       59  #-------------------------------------------------------------------------------
>>>    60  dc_discover_plugins() {
       61      # Initialize dirs if not done
       62      [[ ${#DCX_PLUGIN_DIRS[@]} -eq 0 ]] && dc_init_plugin_dirs
       63  
       64      for dir in "${DCX_PLUGIN_DIRS[@]}"; do
```

**Decisão**: 

### 73 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/plugin.sh:179` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      175  
      176  #-------------------------------------------------------------------------------
      177  # dc_load_all_plugins - Load all discovered plugins
      178  #-------------------------------------------------------------------------------
>>>   179  dc_load_all_plugins() {
      180      local plugins
      181      plugins=$(dc_discover_plugins)
      182  
      183      while IFS= read -r plugin_dir; do
```

**Decisão**: 

### 74 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/plugin.sh:227` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      223  
      224  #-------------------------------------------------------------------------------
      225  # dc_plugin_list - List plugins
      226  #-------------------------------------------------------------------------------
>>>   227  dc_plugin_list() {
      228      local format="${1:-table}"  # table, json, simple
      229  
      230      local plugins
      231      plugins=$(dc_discover_plugins)
```

**Decisão**: 

### 75 · 🟡 MAJOR · VULNERABILITY · `shell:S6506`
**Local**: `lib/plugin.sh:335` · **Effort**: 30min

> Not enforcing HTTPS here might allow for redirections to insecure websites. Make sure it is safe here.

```bash
      331      # Try install.sh first (preferred method)
      332      local install_url="https://raw.githubusercontent.com/${repo}/main/install.sh"
      333      local tmp_installer="/tmp/dcx-plugin-install-$$.sh"
      334  
>>>   335      if curl -fsSL "$install_url" -o "$tmp_installer" 2>/dev/null; then
      336          echo "Using install.sh from $repo..."
      337          local gum_bin="${GUM:-gum}"
      338          if command -v "$gum_bin" &>/dev/null; then
      339              "$gum_bin" spin --title "Installing $plugin_name..." -- \
```

**Decisão**: 

### 76 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/shared.sh:21` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       17  #===============================================================================
       18  # LOGGING
       19  #===============================================================================
       20  
>>>    21  dc_log() {
       22      echo "[INFO] $*"
       23  }
       24  
       25  dc_warn() {
```

**Decisão**: 

### 77 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/shared.sh:25` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       21  dc_log() {
       22      echo "[INFO] $*"
       23  }
       24  
>>>    25  dc_warn() {
       26      echo "[WARN] $*" >&2
       27  }
       28  
       29  dc_error() {
```

**Decisão**: 

### 78 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/shared.sh:29` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       25  dc_warn() {
       26      echo "[WARN] $*" >&2
       27  }
       28  
>>>    29  dc_error() {
       30      echo "[ERROR] $*" >&2
       31      exit 1
       32  }
       33  
```

**Decisão**: 

### 79 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/shared.sh:38` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       34  #===============================================================================
       35  # DIRECTORY MANAGEMENT
       36  #===============================================================================
       37  
>>>    38  dc_create_install_dirs() {
       39      local install_dir="$1"
       40      mkdir -p "$install_dir"/{bin,lib,etc,plugins,share/completions}
       41  }
       42  
```

**Decisão**: 

### 80 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/shared.sh:43` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       39      local install_dir="$1"
       40      mkdir -p "$install_dir"/{bin,lib,etc,plugins,share/completions}
       41  }
       42  
>>>    43  dc_copy_install_files() {
       44      local source_dir="$1"
       45      local install_dir="$2"
       46  
       47      # Ensure directories exist
```

**Decisão**: 

### 81 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/shared.sh:67` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       63  #===============================================================================
       64  # BINARY MANAGEMENT
       65  #===============================================================================
       66  
>>>    67  dc_setup_binary_symlinks() {
       68      local install_dir="$1"
       69      local platform="${2:-$DCX_PLATFORM}"
       70  
       71      # Go tools
```

**Decisão**: 

### 82 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/shared.sh:90` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       86  #===============================================================================
       87  # DOWNLOAD AND EXTRACTION
       88  #===============================================================================
       89  
>>>    90  dc_download_file() {
       91      local url="$1"
       92      local output="$2"
       93  
       94      if command -v curl &>/dev/null; then
```

**Decisão**: 

### 83 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/shared.sh:103` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       99          dc_error "Neither curl nor wget found"
      100      fi
      101  }
      102  
>>>   103  dc_extract_tarball() {
      104      local tarball="$1"
      105      local dest_dir="$2"
      106  
      107      tar -xzf "$tarball" -C "$dest_dir"
```

**Decisão**: 

### 84 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/shared.sh:115` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      111  # INSTALLATION
      112  #===============================================================================
      113  
      114  # Install from local source directory
>>>   115  dc_install_local() {
      116      local source_dir="$1"
      117      local prefix="${2:-$HOME/.local}"
      118      local install_dir="${prefix}/share/${DCX_PROJECT_NAME}"
      119  
```

**Decisão**: 

### 85 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/shared.sh:146` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      142      echo "  export PATH=\"${prefix}/bin:\$PATH\""
      143  }
      144  
      145  # Install specific version from GitHub
>>>   146  dc_install_version() {
      147      local version="$1"
      148      local target_dir="$2"
      149      local repo="${3:-$DCX_GITHUB_REPO}"
      150      local platform="${DCX_PLATFORM}"
```

**Decisão**: 

### 86 · 🟡 MAJOR · VULNERABILITY · `shell:S6506`
**Local**: `lib/shared.sh:169` · **Effort**: 30min

> Not enforcing HTTPS here might allow for redirections to insecure websites. Make sure it is safe here.

```bash
      165      dc_log "Detecting best download for v${version}..."
      166  
      167      # Check if platform-specific release exists
      168      if command -v curl &>/dev/null; then
>>>   169          if curl -fsSL --head "$platform_url" &>/dev/null 2>&1; then
      170              download_url="$platform_url"
      171              download_name="${name}-${version}-${platform}.tar.gz"
      172          else
      173              download_url="$full_url"
```

**Decisão**: 

### 87 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/update.sh:24` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       20  #===============================================================================
       21  # VERSION FUNCTIONS
       22  #===============================================================================
       23  
>>>    24  dc_current_version() {
       25      echo "$DCX_VERSION"
       26  }
       27  
       28  dc_get_latest_version() {
```

**Decisão**: 

### 88 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/update.sh:28` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       24  dc_current_version() {
       25      echo "$DCX_VERSION"
       26  }
       27  
>>>    28  dc_get_latest_version() {
       29      local api_url="${DCX_GITHUB_RELEASES}/latest"
       30      local version=""
       31  
       32      if command -v curl &>/dev/null; then
```

**Decisão**: 

### 89 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `lib/update.sh:110` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      106      # Perform update
      107      _dc_perform_update "$target_version"
      108  }
      109  
>>>   110  _dc_perform_update() {
      111      local version="$1"
      112      local dc_home="${DCX_HOME}"
      113  
      114      echo ""
```

**Decisão**: 

### 90 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7679`
**Local**: `scripts/build-binaries.sh:239` · **Effort**: 5min

> Assign this positional parameter to a local variable.

```bash
      235      local platform="$DCX_PLATFORM"
      236      local all_platforms=false
      237  
      238      while [[ $# -gt 0 ]]; do
>>>   239          case $1 in
      240              --platform)
      241                  platform="$2"
      242                  shift 2
      243                  ;;
```

**Decisão**: 

### 91 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7679`
**Local**: `scripts/build-binaries.sh:257` · **Effort**: 5min

> Assign this positional parameter to a local variable.

```bash
      253                  cmd="$1"
      254                  shift
      255                  ;;
      256              *)
>>>   257                  error "Unknown option: $1"
      258                  ;;
      259          esac
      260      done
      261  
```

**Decisão**: 

### 92 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:31` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       27  # Helper Functions
       28  #===============================================================================
       29  
       30  # Create a test credentials file without interactive prompts
>>>    31  create_test_cred_file() {
       32  	local password="${1:-$TEST_PASSWORD}"
       33  
       34  	mkdir -p "$(dirname "$CRED_FILE")"
       35  
```

**Decisão**: 

### 93 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:62` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       58  	chmod 600 "$CRED_FILE"
       59  }
       60  
       61  # Clean test credentials file
>>>    62  clean_test_cred() {
       63  	rm -f "$CRED_FILE"
       64  	# Reset state
       65  	_CRED_UNLOCKED=0
       66  	_CRED_MASTER_KEY=""
```

**Decisão**: 

### 94 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:74` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       70  #===============================================================================
       71  # Test Groups
       72  #===============================================================================
       73  
>>>    74  test_module_loading() {
       75  	run_test "cred.sh loads" "true"
       76  	run_test "_DCX_CRED_LOADED set" "[[ -n \"\${_DCX_CRED_LOADED:-}\" ]]"
       77  }
       78  
```

**Decisão**: 

### 95 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:79` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       75  	run_test "cred.sh loads" "true"
       76  	run_test "_DCX_CRED_LOADED set" "[[ -n \"\${_DCX_CRED_LOADED:-}\" ]]"
       77  }
       78  
>>>    79  test_core_functions() {
       80  	run_test "cred_open exists" "type cred_open &>/dev/null"
       81  	run_test "cred_set exists" "type cred_set &>/dev/null"
       82  	run_test "cred_get exists" "type cred_get &>/dev/null"
       83  	run_test "cred_list exists" "type cred_list &>/dev/null"
```

**Decisão**: 

### 96 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:119` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      115  	run_test "credentials file created" "[[ -f \"$CRED_FILE\" ]]"
      116  	run_test "correct permissions" "[[ \$(stat -c %a \"$CRED_FILE\" 2>/dev/null || stat -f %A \"$CRED_FILE\") == \"600\" ]]"
      117  }
      118  
>>>   119  test_open() {
      120  	create_test_cred_file
      121  
      122  	# Test opening with env var password
      123  	export DCX_KEYRING_PASSWORD="$TEST_PASSWORD"
```

**Decisão**: 

### 97 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:131` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      127  	# Test idempotency (opening again)
      128  	run_test "cred_open idempotent" "cred_open"
      129  }
      130  
>>>   131  test_set_and_get() {
      132  	create_test_cred_file
      133  	cred_open &>/dev/null
      134  
      135  	# Test storing a credential
```

**Decisão**: 

### 98 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:154` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      150  	retrieved=$(cred_get 'oracle/prod/password' 2>/dev/null)
      151  	run_test "cred_set updates existing" "[[ \"$retrieved\" == \"newsecret\" ]]"
      152  }
      153  
>>>   154  test_key_format_validation() {
      155  	create_test_cred_file
      156  	cred_open &>/dev/null
      157  
      158  	# Valid format
```

**Decisão**: 

### 99 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:168` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      164  	run_test "invalid format rejected (too many slashes)" "! cred_set 'a/b/c/d' 'value' 2>/dev/null"
      165  	run_test "invalid format rejected (spaces)" "! cred_set 'service/my env/name' 'value' 2>/dev/null"
      166  }
      167  
>>>   168  test_list() {
      169  	create_test_cred_file
      170  	cred_open &>/dev/null
      171  
      172  	# Add multiple credentials
```

**Decisão**: 

### 100 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:191` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      187  	count=$(echo "$list" | wc -l | tr -d ' ')
      188  	run_test "cred_list returns 3 keys" "[[ $count -eq 3 ]]"
      189  }
      190  
>>>   191  test_delete() {
      192  	create_test_cred_file
      193  	cred_open &>/dev/null
      194  
      195  	# Add credentials
```

**Decisão**: 

### 101 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:214` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      210  	# Test deleting non-existent key
      211  	run_test "delete non-existent fails" "! cred_delete 'nonexistent/key/name' 2>/dev/null"
      212  }
      213  
>>>   214  test_password_handling() {
      215  	create_test_cred_file
      216  
      217  	# Test with env var (already tested above)
      218  	export DCX_KEYRING_PASSWORD="$TEST_PASSWORD"
```

**Decisão**: 

### 102 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:240` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      236  	# Restore env var for cleanup
      237  	export DCX_KEYRING_PASSWORD="$TEST_PASSWORD"
      238  }
      239  
>>>   240  test_encryption_roundtrip() {
      241  	create_test_cred_file
      242  	cred_open &>/dev/null
      243  
      244  	# Test various special characters and lengths
```

**Decisão**: 

### 103 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:265` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      261  		i=$((i + 1))
      262  	done
      263  }
      264  
>>>   265  test_error_handling() {
      266  	create_test_cred_file
      267  	cred_open &>/dev/null
      268  
      269  	# Test missing arguments
```

**Decisão**: 

### 104 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:283` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      279  	run_test "cred_list fails without file" "! cred_list 2>/dev/null"
      280  	run_test "cred_delete fails without file" "! cred_delete 'key/key/key' 2>/dev/null"
      281  }
      282  
>>>   283  test_migration() {
      284  	create_test_cred_file
      285  	cred_open &>/dev/null
      286  
      287  	# Set up plain-text credentials in environment
```

**Decisão**: 

### 105 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:317` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      313  	# Cleanup env vars
      314  	unset DB_ADMIN_PASSWORD SOURCE_DB_PASSWORD
      315  }
      316  
>>>   317  test_export() {
      318  	create_test_cred_file
      319  	cred_open &>/dev/null
      320  
      321  	# Set up test credentials
```

**Decisão**: 

### 106 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_cred.sh:356` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      352  	run_test "export all includes oracle" "[[ \"$export_output\" == *\"ORACLE_PROD_PASSWORD\"* ]]"
      353  	run_test "export all includes mysql" "[[ \"$export_output\" == *\"MYSQL_DEV_PASSWORD\"* ]]"
      354  }
      355  
>>>   356  test_security_injection() {
      357  	create_test_cred_file
      358  	cred_open &>/dev/null
      359  
      360  	run_test "injection: command substitution escaped" "
```

**Decisão**: 

### 107 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_helpers.sh:51` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       47  #-------------------------------------------------------------------------------
       48  # Test grouping (describe blocks)
       49  #-------------------------------------------------------------------------------
       50  
>>>    51  describe() {
       52      local name="$1"
       53      shift
       54      echo ""
       55      echo -e "${BOLD}$name${NC}"
```

**Decisão**: 

### 108 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_helpers.sh:63` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       59  #-------------------------------------------------------------------------------
       60  # Test assertion functions
       61  #-------------------------------------------------------------------------------
       62  
>>>    63  test_pass() {
       64      TESTS_PASSED=$((TESTS_PASSED + 1))
       65      echo -e "  ${GREEN}✓${NC} $1"
       66  }
       67  
```

**Decisão**: 

### 109 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7679`
**Local**: `tests/test_helpers.sh:65` · **Effort**: 5min

> Assign this positional parameter to a local variable.

```bash
       61  #-------------------------------------------------------------------------------
       62  
       63  test_pass() {
       64      TESTS_PASSED=$((TESTS_PASSED + 1))
>>>    65      echo -e "  ${GREEN}✓${NC} $1"
       66  }
       67  
       68  test_fail() {
       69      TESTS_FAILED=$((TESTS_FAILED + 1))
```

**Decisão**: 

### 110 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_helpers.sh:68` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       64      TESTS_PASSED=$((TESTS_PASSED + 1))
       65      echo -e "  ${GREEN}✓${NC} $1"
       66  }
       67  
>>>    68  test_fail() {
       69      TESTS_FAILED=$((TESTS_FAILED + 1))
       70      echo -e "  ${RED}✗${NC} $1"
       71  }
       72  
```

**Decisão**: 

### 111 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7679`
**Local**: `tests/test_helpers.sh:70` · **Effort**: 5min

> Assign this positional parameter to a local variable.

```bash
       66  }
       67  
       68  test_fail() {
       69      TESTS_FAILED=$((TESTS_FAILED + 1))
>>>    70      echo -e "  ${RED}✗${NC} $1"
       71  }
       72  
       73  run_test() {
       74      local name="$1"
```

**Decisão**: 

### 112 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_helpers.sh:73` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       69      TESTS_FAILED=$((TESTS_FAILED + 1))
       70      echo -e "  ${RED}✗${NC} $1"
       71  }
       72  
>>>    73  run_test() {
       74      local name="$1"
       75      local cmd="$2"
       76      TESTS_RUN=$((TESTS_RUN + 1))
       77  
```

**Decisão**: 

### 113 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_helpers.sh:89` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       85  #-------------------------------------------------------------------------------
       86  # Assertion helpers
       87  #-------------------------------------------------------------------------------
       88  
>>>    89  assert_eq() {
       90      local expected="$1"
       91      local actual="$2"
       92      local msg="${3:-values should be equal}"
       93  
```

**Decisão**: 

### 114 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_helpers.sh:101` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
       97          test_fail "$msg (expected: '$expected', got: '$actual')"
       98      fi
       99  }
      100  
>>>   101  assert_ne() {
      102      local not_expected="$1"
      103      local actual="$2"
      104      local msg="${3:-values should not be equal}"
      105  
```

**Decisão**: 

### 115 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_helpers.sh:113` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      109          test_fail "$msg (got: '$actual')"
      110      fi
      111  }
      112  
>>>   113  assert_contains() {
      114      local haystack="$1"
      115      local needle="$2"
      116      local msg="${3:-should contain substring}"
      117  
```

**Decisão**: 

### 116 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_helpers.sh:125` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      121          test_fail "$msg ('$needle' not found)"
      122      fi
      123  }
      124  
>>>   125  assert_match() {
      126      local pattern="$1"
      127      local actual="$2"
      128      local msg="${3:-should match pattern}"
      129      TESTS_RUN=$((TESTS_RUN + 1))
```

**Decisão**: 

### 117 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_helpers.sh:137` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      133          test_fail "$msg (pattern: '$pattern', got: '$actual')"
      134      fi
      135  }
      136  
>>>   137  assert_true() {
      138      local cmd="$1"
      139      local msg="${2:-should succeed}"
      140  
      141      if eval "$cmd" &>/dev/null; then
```

**Decisão**: 

### 118 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_helpers.sh:148` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      144          test_fail "$msg"
      145      fi
      146  }
      147  
>>>   148  assert_false() {
      149      local cmd="$1"
      150      local msg="${2:-should fail}"
      151  
      152      if ! eval "$cmd" &>/dev/null; then
```

**Decisão**: 

### 119 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_helpers.sh:164` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      160  # Test lifecycle
      161  #-------------------------------------------------------------------------------
      162  
      163  # Setup temp dir com cleanup automático
>>>   164  test_setup() {
      165      TMP_DIR=$(mktemp -d)
      166      trap 'rm -rf "$TMP_DIR"' EXIT
      167  }
      168  
```

**Decisão**: 

### 120 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_helpers.sh:170` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      166      trap 'rm -rf "$TMP_DIR"' EXIT
      167  }
      168  
      169  # Assertions de arquivo
>>>   170  assert_file() {
      171      local file="$1"
      172      local msg="${2:-File exists: $file}"
      173      [[ -f "$file" ]] && test_pass "$msg" || test_fail "$msg"
      174  }
```

**Decisão**: 

### 121 · 🟡 MAJOR · CODE_SMELL · `shelldre:S7682`
**Local**: `tests/test_helpers.sh:176` · **Effort**: 2min

> Add an explicit return statement at the end of the function.

```bash
      172      local msg="${2:-File exists: $file}"
      173      [[ -f "$file" ]] && test_pass "$msg" || test_fail "$msg"
      174  }
      175  
>>>   176  assert_dir() {
      177      local dir="$1"
      178      local msg="${2:-Dir exists: $dir}"
      179      [[ -d "$dir" ]] && test_pass "$msg" || test_fail "$msg"
      180  }
```

**Decisão**: 

### 122 · 🟡 MAJOR · VULNERABILITY · `shell:S6506`
**Local**: `tests/test_update.sh:95` · **Effort**: 30min

> Not enforcing HTTPS here might allow for redirections to insecure websites. Make sure it is safe here.

```bash
       91  test_network() {
       92      echo ""
       93      echo "Network tests (may be skipped if offline):"
       94  
>>>    95      if curl -fsSL --max-time 5 "https://api.github.com/rate_limit" &>/dev/null; then
       96          latest=$(dc_get_latest_version 2>/dev/null || echo "")
       97          if [[ -n "$latest" ]]; then
       98              run_test "dc_get_latest_version returns version" "[[ \"\$latest\" =~ ^[0-9]+\\.[0-9]+ ]]"
       99          else
```

**Decisão**: 

### 123 · ⚪ MINOR · VULNERABILITY · `go:S4036`
**Local**: `cmd/dcx/cred.go:275` · **Effort**: 15min

> Make sure the "PATH" variable only contains fixed, unwriteable directories.

```go
      271  	// Build bash command that sources cred.sh and calls the function
      272  	bashCmd := fmt.Sprintf("source %q && %s", credShPath, funcCall)
      273  
      274  	// Execute with bash
>>>   275  	cmd := exec.Command("bash", "-c", bashCmd)
      276  
      277  	// Set DCX_HOME in environment
      278  	cmd.Env = append(os.Environ(), fmt.Sprintf("DCX_HOME=%s", getDCHome()))
      279  
```

**Decisão**: 

### 124 · ⚪ MINOR · CODE_SMELL · `shelldre:S1192`
**Local**: `lib/cred.sh:505` · **Effort**: 4min

> Define a constant instead of using the literal '===================================================================' 6 times.

```bash
      501          echo ""
      502          echo "Add these to your ~/.bashrc or ~/.profile to make permanent."
      503      fi
      504  
>>>   505      echo "==================================================================="
      506      echo ""
      507  
      508      return 0
      509  }
```

**Decisão**: 

### 125 · ⚪ MINOR · CODE_SMELL · `shelldre:S1481`
**Local**: `lib/logging.sh:93` · **Effort**: 5min

> Remove the unused local variable 'func'.

```bash
       89  #-------------------------------------------------------------------------------
       90  # _dc_log_text - Format log as text
       91  #-------------------------------------------------------------------------------
       92  _dc_log_text() {
>>>    93      local level="$1" message="$2" func="$3" file="$4" line="$5"
       94  
       95      # Use gum if available for better formatting
       96      local gum_bin="${GUM:-gum}"
       97      if command -v "$gum_bin" &>/dev/null && [[ "$DCX_LOG_COLOR" != "never" ]]; then
```

**Decisão**: 

### 126 · ⚪ MINOR · CODE_SMELL · `shelldre:S1481`
**Local**: `lib/logging.sh:93` · **Effort**: 5min

> Remove the unused local variable 'file'.

```bash
       89  #-------------------------------------------------------------------------------
       90  # _dc_log_text - Format log as text
       91  #-------------------------------------------------------------------------------
       92  _dc_log_text() {
>>>    93      local level="$1" message="$2" func="$3" file="$4" line="$5"
       94  
       95      # Use gum if available for better formatting
       96      local gum_bin="${GUM:-gum}"
       97      if command -v "$gum_bin" &>/dev/null && [[ "$DCX_LOG_COLOR" != "never" ]]; then
```

**Decisão**: 

### 127 · ⚪ MINOR · CODE_SMELL · `shelldre:S1481`
**Local**: `lib/logging.sh:93` · **Effort**: 5min

> Remove the unused local variable 'line'.

```bash
       89  #-------------------------------------------------------------------------------
       90  # _dc_log_text - Format log as text
       91  #-------------------------------------------------------------------------------
       92  _dc_log_text() {
>>>    93      local level="$1" message="$2" func="$3" file="$4" line="$5"
       94  
       95      # Use gum if available for better formatting
       96      local gum_bin="${GUM:-gum}"
       97      if command -v "$gum_bin" &>/dev/null && [[ "$DCX_LOG_COLOR" != "never" ]]; then
```

**Decisão**: 

### 128 · ⚪ MINOR · CODE_SMELL · `shelldre:S1481`
**Local**: `scripts/build.sh:100` · **Effort**: 5min

> Remove the unused local variable 'src'.

```bash
       96  install_local() {
       97      build_current
       98  
       99      local platform="${GOOS}-${GOARCH}"
>>>   100      local src="$PROJECT_DIR/bin/dcx-${platform}"
      101      local dst="$PROJECT_DIR/bin/dcx-go"
      102  
      103      echo "Installed: $dst"
      104  }
```

**Decisão**: 

### 129 · ⚪ MINOR · CODE_SMELL · `shelldre:S1481`
**Local**: `tests/test_cred.sh:32` · **Effort**: 5min

> Remove the unused local variable 'password'.

```bash
       28  #===============================================================================
       29  
       30  # Create a test credentials file without interactive prompts
       31  create_test_cred_file() {
>>>    32  	local password="${1:-$TEST_PASSWORD}"
       33  
       34  	mkdir -p "$(dirname "$CRED_FILE")"
       35  
       36  	# Generate salt
```

**Decisão**: 

### 130 · ⚪ MINOR · CODE_SMELL · `shelldre:S1192`
**Local**: `tests/test_cred.sh:322` · **Effort**: 4min

> Define a constant instead of using the literal 'oracle/prod/password' 6 times.

```bash
      318  	create_test_cred_file
      319  	cred_open &>/dev/null
      320  
      321  	# Set up test credentials
>>>   322  	cred_set 'oracle/prod/password' 'prod_secret' &>/dev/null
      323  	cred_set 'oracle/prod/username' 'prod_user' &>/dev/null
      324  	cred_set 'mysql/dev/password' 'dev_secret' &>/dev/null
      325  
      326  	# Test export function exists
```

**Decisão**: 

### 131 · ⚪ MINOR · CODE_SMELL · `shelldre:S1192`
**Local**: `tests/test_cred.sh:324` · **Effort**: 4min

> Define a constant instead of using the literal 'mysql/dev/password' 6 times.

```bash
      320  
      321  	# Set up test credentials
      322  	cred_set 'oracle/prod/password' 'prod_secret' &>/dev/null
      323  	cred_set 'oracle/prod/username' 'prod_user' &>/dev/null
>>>   324  	cred_set 'mysql/dev/password' 'dev_secret' &>/dev/null
      325  
      326  	# Test export function exists
      327  	run_test "cred_export exists" "type cred_export &>/dev/null"
      328  
```

**Decisão**: 

