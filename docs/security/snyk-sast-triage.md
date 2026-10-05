# Triagem Snyk Code (SAST) — datacosmos-br/dcx

Gerado do scan Snyk da org Datacosmos (dump 2026-08-06).

**4 achados** — critical 0, high 1, medium 1, low 2

| categoria | achados |
|---|---|
| Path Traversal | 2 |
| Command Injection | 1 |
| Server-Side Request Forgery (SSRF) | 1 |

## Achados

Coluna **Decisão**: `corrigir` / `falso-positivo` / `risco-aceito`.

| # | sev | categoria | arquivo | linha | CWE | Decisão |
|---|---|---|---|---|---|---|
| 1 | high | Command Injection | `cmd/dcx/main.go` | 31 | - | |
| 2 | medium | Server-Side Request Forgery (SSRF) | `cmd/dcx/main.go` | 27 | - | |
| 3 | low | Path Traversal | `cmd/dcx/main.go` | 27 | - | |
| 4 | low | Path Traversal | `cmd/dcx/main.go` | 29 | - | |

## Como triar

1. Abrir `arquivo:linha` e seguir o fluxo de dados até o sink.
2. Classificar: **corrigir** (entrada externa alcança o sink sem sanitização), **falso-positivo** (credencial de fixture, path de constante — registrar em `.snyk` com justificativa), **risco-aceito** (com prazo de revisão).

Dados brutos: `~/snyk-violations/sast/datacosmos-br__dcx.sast.json`

