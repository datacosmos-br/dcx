# Triagem SonarCloud — datacosmos-br/dcx

Gerado do dump da plataforma SonarCloud (2026-08-06).

Bead de rastreio: `dcx-1v9.1`

## Resumo

**131 issues** — BLOCKER 0, CRITICAL 12, MAJOR 110, MINOR 9
Tipos: VULNERABILITY 8, BUG 1, CODE_SMELL 122

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

## Issues

Coluna **Decisão**: `corrigir` / `falso-positivo` / `risco-aceito`.

| # | sev | tipo | regra | componente | linha | Decisão |
|---|---|---|---|---|---|---|
| 1 | CRITICAL | CODE_SMELL | `go:S3776` | `cmd/dcx/config.go` | 50 | |
| 2 | CRITICAL | CODE_SMELL | `go:S1192` | `cmd/dcx/cred.go` | 20 | |
| 3 | CRITICAL | CODE_SMELL | `go:S1192` | `cmd/dcx/platform.go` | 21 | |
| 4 | CRITICAL | CODE_SMELL | `go:S3776` | `cmd/dcx/tools.go` | 87 | |
| 5 | CRITICAL | CODE_SMELL | `go:S3776` | `cmd/dcx/tools.go` | 133 | |
| 6 | CRITICAL | CODE_SMELL | `go:S3776` | `cmd/dcx/tools.go` | 357 | |
| 7 | CRITICAL | CODE_SMELL | `go:S3776` | `cmd/dcx/validate.go` | 12 | |
| 8 | CRITICAL | CODE_SMELL | `go:S1192` | `cmd/dcx/validate.go` | 28 | |
| 9 | CRITICAL | CODE_SMELL | `go:S1192` | `cmd/dcx/validate.go` | 31 | |
| 10 | CRITICAL | CODE_SMELL | `go:S1192` | `cmd/dcx/validate.go` | 70 | |
| 11 | CRITICAL | CODE_SMELL | `shelldre:S131` | `scripts/build-binaries.sh` | 63 | |
| 12 | CRITICAL | CODE_SMELL | `shelldre:S131` | `scripts/build-binaries.sh` | 264 | |
| 13 | MAJOR | BUG | `go:S3923` | `cmd/dcx/cred.go` | 253 | |
| 14 | MAJOR | VULNERABILITY | `shell:S6506` | `install.sh` | 156 | |
| 15 | MAJOR | VULNERABILITY | `shell:S6506` | `install.sh` | 158 | |
| 16 | MAJOR | VULNERABILITY | `shell:S6506` | `install.sh` | 484 | |
| 17 | MAJOR | VULNERABILITY | `shell:S6506` | `install.sh` | 561 | |
| 18 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/config.sh` | 22 | |
| 19 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/config.sh` | 36 | |
| 20 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/config.sh` | 50 | |
| 21 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/config.sh` | 63 | |
| 22 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 41 | |
| 23 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 50 | |
| 24 | MAJOR | CODE_SMELL | `shelldre:S7679` | `lib/core.sh` | 51 | |
| 25 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 65 | |
| 26 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 85 | |
| 27 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 112 | |
| 28 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 113 | |
| 29 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 114 | |
| 30 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 120 | |
| 31 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 137 | |
| 32 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 139 | |
| 33 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 242 | |
| 34 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 294 | |
| 35 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 306 | |
| 36 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/core.sh` | 318 | |
| 37 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/cred.sh` | 132 | |
| 38 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/cred.sh` | 143 | |
| 39 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/cred.sh` | 180 | |
| 40 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/cred.sh` | 190 | |
| 41 | MAJOR | CODE_SMELL | `shelldre:S1066` | `lib/cred.sh` | 281 | |
| 42 | MAJOR | CODE_SMELL | `shelldre:S1066` | `lib/cred.sh` | 288 | |
| 43 | MAJOR | CODE_SMELL | `shelldre:S1066` | `lib/cred.sh` | 324 | |
| 44 | MAJOR | CODE_SMELL | `shelldre:S1066` | `lib/cred.sh` | 521 | |
| 45 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 72 | |
| 46 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 92 | |
| 47 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 111 | |
| 48 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 123 | |
| 49 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 136 | |
| 50 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 137 | |
| 51 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 138 | |
| 52 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 139 | |
| 53 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 140 | |
| 54 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 141 | |
| 55 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 144 | |
| 56 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 145 | |
| 57 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 182 | |
| 58 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 211 | |
| 59 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 228 | |
| 60 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 236 | |
| 61 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 244 | |
| 62 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 285 | |
| 63 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 293 | |
| 64 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 311 | |
| 65 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 320 | |
| 66 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/logging.sh` | 331 | |
| 67 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/parallel.sh` | 74 | |
| 68 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/parallel.sh` | 96 | |
| 69 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/parallel.sh` | 164 | |
| 70 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/parallel.sh` | 173 | |
| 71 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/parallel.sh` | 191 | |
| 72 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/plugin.sh` | 60 | |
| 73 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/plugin.sh` | 179 | |
| 74 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/plugin.sh` | 227 | |
| 75 | MAJOR | VULNERABILITY | `shell:S6506` | `lib/plugin.sh` | 335 | |
| 76 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/shared.sh` | 21 | |
| 77 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/shared.sh` | 25 | |
| 78 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/shared.sh` | 29 | |
| 79 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/shared.sh` | 38 | |
| 80 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/shared.sh` | 43 | |
| 81 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/shared.sh` | 67 | |
| 82 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/shared.sh` | 90 | |
| 83 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/shared.sh` | 103 | |
| 84 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/shared.sh` | 115 | |
| 85 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/shared.sh` | 146 | |
| 86 | MAJOR | VULNERABILITY | `shell:S6506` | `lib/shared.sh` | 169 | |
| 87 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/update.sh` | 24 | |
| 88 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/update.sh` | 28 | |
| 89 | MAJOR | CODE_SMELL | `shelldre:S7682` | `lib/update.sh` | 110 | |
| 90 | MAJOR | CODE_SMELL | `shelldre:S7679` | `scripts/build-binaries.sh` | 239 | |
| 91 | MAJOR | CODE_SMELL | `shelldre:S7679` | `scripts/build-binaries.sh` | 257 | |
| 92 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 31 | |
| 93 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 62 | |
| 94 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 74 | |
| 95 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 79 | |
| 96 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 119 | |
| 97 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 131 | |
| 98 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 154 | |
| 99 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 168 | |
| 100 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 191 | |
| 101 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 214 | |
| 102 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 240 | |
| 103 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 265 | |
| 104 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 283 | |
| 105 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 317 | |
| 106 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_cred.sh` | 356 | |
| 107 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_helpers.sh` | 51 | |
| 108 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_helpers.sh` | 63 | |
| 109 | MAJOR | CODE_SMELL | `shelldre:S7679` | `tests/test_helpers.sh` | 65 | |
| 110 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_helpers.sh` | 68 | |
| 111 | MAJOR | CODE_SMELL | `shelldre:S7679` | `tests/test_helpers.sh` | 70 | |
| 112 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_helpers.sh` | 73 | |
| 113 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_helpers.sh` | 89 | |
| 114 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_helpers.sh` | 101 | |
| 115 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_helpers.sh` | 113 | |
| 116 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_helpers.sh` | 125 | |
| 117 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_helpers.sh` | 137 | |
| 118 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_helpers.sh` | 148 | |
| 119 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_helpers.sh` | 164 | |
| 120 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_helpers.sh` | 170 | |
| 121 | MAJOR | CODE_SMELL | `shelldre:S7682` | `tests/test_helpers.sh` | 176 | |
| 122 | MAJOR | VULNERABILITY | `shell:S6506` | `tests/test_update.sh` | 95 | |
| 123 | MINOR | VULNERABILITY | `go:S4036` | `cmd/dcx/cred.go` | 275 | |
| 124 | MINOR | CODE_SMELL | `shelldre:S1192` | `lib/cred.sh` | 505 | |
| 125 | MINOR | CODE_SMELL | `shelldre:S1481` | `lib/logging.sh` | 93 | |
| 126 | MINOR | CODE_SMELL | `shelldre:S1481` | `lib/logging.sh` | 93 | |
| 127 | MINOR | CODE_SMELL | `shelldre:S1481` | `lib/logging.sh` | 93 | |
| 128 | MINOR | CODE_SMELL | `shelldre:S1481` | `scripts/build.sh` | 100 | |
| 129 | MINOR | CODE_SMELL | `shelldre:S1481` | `tests/test_cred.sh` | 32 | |
| 130 | MINOR | CODE_SMELL | `shelldre:S1192` | `tests/test_cred.sh` | 322 | |
| 131 | MINOR | CODE_SMELL | `shelldre:S1192` | `tests/test_cred.sh` | 324 | |

## Como triar

1. **BLOCKER e CRITICAL primeiro**, e todo VULNERABILITY independente de severidade.
2. Classificar: **corrigir**, **falso-positivo** (marcar na plataforma SonarCloud com justificativa), **risco-aceito** (com prazo).
3. CODE_SMELL em volume alto sugere padrão — corrigir a causa raiz, não issue a issue.

Dados brutos: `~/sonarqube-violations/by-repo/datacosmos-br__dcx.json`

