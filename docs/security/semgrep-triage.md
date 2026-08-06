# Triagem Semgrep — datacosmos-br/dcx

Gerado do dump da plataforma Semgrep (deployment `datacosmos`, 2026-08-06).

Bead de rastreio: `dcx-nes.2`

## Resumo

**15 findings** — high 12, medium 3, low 0
Confiança: high 0, medium 0, low 15

| regra | achados |
|---|---|
| `go.lang.security.audit.dangerous-exec-command.dangerous-exec-command` | 12 |
| `go.lang.security.decompression_bomb.potential-dos-via-decompression-bomb` | 2 |
| `bash.curl.security.curl-pipe-bash.curl-pipe-bash` | 1 |

## Findings

Coluna **Decisão** a preencher: `corrigir` / `falso-positivo` / `risco-aceito`.

| # | sev | conf | regra | arquivo | linha | Decisão |
|---|---|---|---|---|---|---|
| 1 | high | low | `dangerous-exec-command` | `cmd/dcx/cred.go` | 275 | |
| 2 | high | low | `dangerous-exec-command` | `cmd/dcx/lint.go` | 56 | |
| 3 | high | low | `dangerous-exec-command` | `cmd/dcx/validate.go` | 28 | |
| 4 | high | low | `dangerous-exec-command` | `cmd/dcx/validate.go` | 44 | |
| 5 | high | low | `dangerous-exec-command` | `cmd/dcx/validate.go` | 46 | |
| 6 | high | low | `dangerous-exec-command` | `cmd/dcx/validate.go` | 62 | |
| 7 | high | low | `dangerous-exec-command` | `cmd/dcx/validate.go` | 63 | |
| 8 | high | low | `dangerous-exec-command` | `cmd/dcx/validate.go` | 78 | |
| 9 | high | low | `dangerous-exec-command` | `cmd/dcx/validate.go` | 79 | |
| 10 | high | low | `dangerous-exec-command` | `cmd/dcx/validate.go` | 93 | |
| 11 | high | low | `dangerous-exec-command` | `cmd/dcx/validate.go` | 96 | |
| 12 | high | low | `dangerous-exec-command` | `cmd/dcx/validate.go` | 111 | |
| 13 | medium | low | `potential-dos-via-decompression-bomb` | `cmd/dcx/tools.go` | 393 | |
| 14 | medium | low | `potential-dos-via-decompression-bomb` | `cmd/dcx/tools.go` | 430 | |
| 15 | medium | low | `curl-pipe-bash` | `install.sh` | 561 | |

## Como triar

1. Abrir `arquivo:linha` e seguir o fluxo até o sink.
2. Classificar: **corrigir** (entrada externa alcança o sink), **falso-positivo** (registrar via `nosemgrep` ou `.semgrepignore` com justificativa), **risco-aceito** (com prazo de revisão).
3. Priorizar findings high com confidence=high.

Dados brutos: `~/semgrep-violations/by-repo/datacosmos-br__dcx.json`

