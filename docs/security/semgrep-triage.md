# Triagem Semgrep — datacosmos-br/dcx

Gerado do dump da plataforma Semgrep (deployment `datacosmos`, 2026-08-06).

Bead: `dcx-nes.2`

## Resumo

**15 findings** — high 12, medium 3, low 0
Confiança: high 0, medium 0, low 15

| regra | achados |
|---|---|
| `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command` | 12 |
| `go.lang.security.decompression_bomb.potential-dos-via-decompression-bomb` | 2 |
| `bash.curl.security.curl-pipe-bash.curl-pipe-bash` | 1 |

## Como usar

Cada finding traz a **mensagem completa da regra** (o Semgrep descreve o problema e frequentemente o fix), o **código real** (linha `>>>`), classe de vulnerabilidade, CWE/OWASP.
**Decisão**: `corrigir` / `falso-positivo` (`nosemgrep` ou `.semgrepignore` com justificativa) / `risco-aceito`. Priorizar high com confidence=high.

## Findings

### 1 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/cred.go:275`

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

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

### 2 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/lint.go:56`

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       52  
       53  		cmdArgs := []string{"scan", "--rule", ruleFile}
       54  		cmdArgs = append(cmdArgs, paths...)
       55  
>>>    56  		cmd := exec.Command(sg, cmdArgs...)
       57  		cmd.Stdout = os.Stdout
       58  		cmd.Stderr = os.Stderr
       59  		cmd.Dir = dcHome
       60  
```

**Decisão**: 

### 3 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:28`

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

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

### 4 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:44`

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       40  	fmt.Print("  yq:  ")
       41  	if yq, err := findBinary("yq"); err == nil {
       42  		testFile := filepath.Join(tmpDir, "test.yaml")
       43  		os.WriteFile(testFile, []byte("test: value"), 0644)
>>>    44  		out, err := exec.Command(yq, ".test", testFile).Output()
       45  		if err == nil && strings.TrimSpace(string(out)) == "value" {
       46  			verOut, _ := exec.Command(yq, "--version").Output()
       47  			fmt.Printf("OK (%s)\n", strings.TrimSpace(string(verOut)))
       48  		} else {
```

**Decisão**: 

### 5 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:46`

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       42  		testFile := filepath.Join(tmpDir, "test.yaml")
       43  		os.WriteFile(testFile, []byte("test: value"), 0644)
       44  		out, err := exec.Command(yq, ".test", testFile).Output()
       45  		if err == nil && strings.TrimSpace(string(out)) == "value" {
>>>    46  			verOut, _ := exec.Command(yq, "--version").Output()
       47  			fmt.Printf("OK (%s)\n", strings.TrimSpace(string(verOut)))
       48  		} else {
       49  			fmt.Println("FAIL (not working)")
       50  			failed++
```

**Decisão**: 

### 6 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:62`

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       58  	fmt.Print("  rg:  ")
       59  	if rg, err := findBinary("rg"); err == nil {
       60  		testFile := filepath.Join(tmpDir, "test.txt")
       61  		os.WriteFile(testFile, []byte("test pattern here"), 0644)
>>>    62  		if err := exec.Command(rg, "-q", "pattern", testFile).Run(); err == nil {
       63  			verOut, _ := exec.Command(rg, "--version").Output()
       64  			version := strings.Split(string(verOut), "\n")[0]
       65  			fmt.Printf("OK (%s)\n", strings.TrimSpace(version))
       66  		} else {
```

**Decisão**: 

### 7 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:63`

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       59  	if rg, err := findBinary("rg"); err == nil {
       60  		testFile := filepath.Join(tmpDir, "test.txt")
       61  		os.WriteFile(testFile, []byte("test pattern here"), 0644)
       62  		if err := exec.Command(rg, "-q", "pattern", testFile).Run(); err == nil {
>>>    63  			verOut, _ := exec.Command(rg, "--version").Output()
       64  			version := strings.Split(string(verOut), "\n")[0]
       65  			fmt.Printf("OK (%s)\n", strings.TrimSpace(version))
       66  		} else {
       67  			fmt.Println("FAIL (not working)")
```

**Decisão**: 

### 8 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:78`

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       74  	fmt.Print("  fd:  ")
       75  	if fd, err := findBinary("fd"); err == nil {
       76  		testFile := filepath.Join(tmpDir, "findme.txt")
       77  		os.WriteFile(testFile, []byte(""), 0644)
>>>    78  		if err := exec.Command(fd, "-q", "findme", tmpDir).Run(); err == nil {
       79  			verOut, _ := exec.Command(fd, "--version").Output()
       80  			fmt.Printf("OK (%s)\n", strings.TrimSpace(string(verOut)))
       81  		} else {
       82  			fmt.Println("FAIL (not working)")
```

**Decisão**: 

### 9 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:79`

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       75  	if fd, err := findBinary("fd"); err == nil {
       76  		testFile := filepath.Join(tmpDir, "findme.txt")
       77  		os.WriteFile(testFile, []byte(""), 0644)
       78  		if err := exec.Command(fd, "-q", "findme", tmpDir).Run(); err == nil {
>>>    79  			verOut, _ := exec.Command(fd, "--version").Output()
       80  			fmt.Printf("OK (%s)\n", strings.TrimSpace(string(verOut)))
       81  		} else {
       82  			fmt.Println("FAIL (not working)")
       83  		}
```

**Decisão**: 

### 10 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:93`

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       89  	fmt.Print("  sd:  ")
       90  	if sd, err := findBinary("sd"); err == nil {
       91  		testFile := filepath.Join(tmpDir, "replace.txt")
       92  		os.WriteFile(testFile, []byte("old text"), 0644)
>>>    93  		if err := exec.Command(sd, "old", "new", testFile).Run(); err == nil {
       94  			content, _ := os.ReadFile(testFile)
       95  			if strings.Contains(string(content), "new") {
       96  				verOut, _ := exec.Command(sd, "--version").Output()
       97  				fmt.Printf("OK (%s)\n", strings.TrimSpace(string(verOut)))
```

**Decisão**: 

### 11 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:96`

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       92  		os.WriteFile(testFile, []byte("old text"), 0644)
       93  		if err := exec.Command(sd, "old", "new", testFile).Run(); err == nil {
       94  			content, _ := os.ReadFile(testFile)
       95  			if strings.Contains(string(content), "new") {
>>>    96  				verOut, _ := exec.Command(sd, "--version").Output()
       97  				fmt.Printf("OK (%s)\n", strings.TrimSpace(string(verOut)))
       98  			} else {
       99  				fmt.Println("FAIL (replacement didn't work)")
      100  			}
```

**Decisão**: 

### 12 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:111`

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
      107  
      108  	// Test SG / ast-grep (optional)
      109  	fmt.Print("  sg:  ")
      110  	if sg, err := findBinary("sg"); err == nil {
>>>   111  		if out, err := exec.Command(sg, "--version").Output(); err == nil {
      112  			fmt.Printf("OK (%s)\n", strings.TrimSpace(string(out)))
      113  		} else {
      114  			fmt.Println("FAIL (not working)")
      115  		}
```

**Decisão**: 

### 13 · 🟡 MEDIUM · conf low · `go.lang.security.decompression_bomb.potential-dos-via-decompression-bomb`
**Classe**: Denial-of-Service (DoS) · **Local**: `cmd/dcx/tools.go:393`

> Detected a possible denial-of-service via a zip bomb attack. By limiting the max bytes read, you can mitigate this attack. `io.CopyN()` can specify a size.

```go
      389  			out, err := os.OpenFile(dest, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0755)
      390  			if err != nil {
      391  				return err
      392  			}
>>>   393  			if _, err := io.Copy(out, tr); err != nil {
      394  				out.Close()
      395  				return err
      396  			}
      397  			out.Close()
```

**Decisão**: 

### 14 · 🟡 MEDIUM · conf low · `go.lang.security.decompression_bomb.potential-dos-via-decompression-bomb`
**Classe**: Denial-of-Service (DoS) · **Local**: `cmd/dcx/tools.go:430`

> Detected a possible denial-of-service via a zip bomb attack. By limiting the max bytes read, you can mitigate this attack. `io.CopyN()` can specify a size.

```go
      426  				rc.Close()
      427  				return err
      428  			}
      429  
>>>   430  			_, err = io.Copy(out, rc)
      431  			rc.Close()
      432  			out.Close()
      433  
      434  			if err != nil {
```

**Decisão**: 

### 15 · 🟡 MEDIUM · conf low · `bash.curl.security.curl-pipe-bash.curl-pipe-bash`
**Classe**: Code Injection · **Local**: `install.sh:561`

> Data is being piped into `bash` from a `curl` command. An attacker with control of the server in the `curl` command could inject malicious code into the pipe, resulting in a system compromise. Avoid piping untrusted data into `bash` or any other shell if you can. If you must do this, consider checking the SHA sum of the content returned by the server to verify its integrity.

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

