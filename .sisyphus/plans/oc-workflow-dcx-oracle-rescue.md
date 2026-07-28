# OC Workflow Project Plan: DCX + DCX-Oracle Contract/Security/Performance Rescue

Created: 2026-02-02
Owner: marlon.costa@datacosmos.com.br

## Objective
Re-establish a strict, testable contract between `dcx` (core) and `dcx-oracle` (plugin) and close the historical gaps that caused:
- insecure credential flows (plaintext, env leakage, `eval` risks)
- inconsistent enforcement of conventions ("no fallbacks", module loading rules)
- incomplete/incorrect Data Pump performance behavior (dtcosmos optimizations)

## Scope
In scope:
- Plugin contract + enforcement (inputs/outputs, config precedence, error handling, stdout/stderr discipline)
- Secret handling hardening (remove code-exec surfaces, redaction, least privilege)
- Data Pump optimization completion (size categorization correctness, skip-empty, precompute-subqueries decision)
- Versioning/release integrity between core repo and plugin repo
- Evidence-based milestone audit workflow

Out of scope (unless explicitly approved):
- Large rewrite of bash modules to Go
- Broad refactor unrelated to contract/security/perf gaps

## Sources of Truth (Requirements)
- `.beads/issues.jsonl`:
  - `dcx-bfo` "Sistema de Keyring + Oracle Wallets" (eliminar senhas em texto plano de migration.conf)
  - `dcx-ycf` "Otimização Export/Import dtcosmos" (categorização por tamanho, eliminar queries 0 rows, pre-computar subqueries)
- `.planning/ROADMAP.md` and `.planning/STATE.md` (milestone traceability, but contains "complete" claims that require re-validation)
- `dcx-oracle/CLAUDE.md` (plugin architecture & conventions)
- `dcx/CLAUDE.md` and `.planning/codebase/CONVENTIONS.md` (core conventions)

## Current State (Evidence)
- `dcx` and `dcx-oracle` are separate git repos; `dcx` ignores `dcx-oracle/`.
- `dcx-oracle/commands/migrate.sh` now loads credentials via `dcx cred export` and supports wallet auth, but uses `eval` (RCE risk).
- `dcx-oracle/lib/oracle_datapump.sh` implements `dp_execute_batch_optimized` using size categorization but:
  - relies on a heuristic (parfile filename == table name)
  - derives schema from connection string (breaks on wallet `/@...`)

## Guiding Principles (Enforcement)
- Contract-first: plugin must declare required inputs and produce deterministic outputs.
- No silent fallbacks for production operations; any "standalone" mode must be explicit.
- Secrets are data, never code: no `eval`, no `source` of credential output.
- Stdout is data, stderr is logs/progress.
- Evidence-based completion: every requirement must have a verification step.

---

## Phase 0: Contract Definition (Architecture)

Deliverables:
- `docs/architecture/plugin-contract-dcx-oracle.md` (or equivalent) defining:
  - Invocation model: `dcx oracle <cmd>` entrypoint
  - Config precedence: CLI flags > environment > config files > defaults
  - Required capabilities: credential provider (wallet/cred), binaries, permissions
  - Output rules: stdout vs stderr
  - Error handling: exit codes, fail-fast preflight
  - Security rules: no secrets in logs, no code-exec surfaces

Acceptance:
- Contract reviewed and explicitly approved (one decision: does "no fallbacks" apply to plugin runtime? default: yes for production paths).

---

## Phase 1: Security Hardening (Close the RCE/Leak Surfaces)

Tasks:
1) Remove `eval` from credential loading in `dcx-oracle/commands/migrate.sh`.
   - Implement an allowlisted parser for exported credentials (data-only):
     - allow keys: `DB_ADMIN_USER`, `DB_ADMIN_PASSWORD`, `DB_CONNECTION_STRING`, and explicit `ORACLE_*` keys
     - reject any non `KEY=VALUE` line or keys outside allowlist
   - Alternative: extend `dcx cred export` to support `--json`, then parse JSON safely.

2) Add deterministic redaction points for logs:
   - redact patterns: `*_PASSWORD`, connection strings containing `/` and `@`.
   - ensure no printing of `CONNECTION`.

3) Lock down DB link usage:
   - allowlist/regex validate `NETWORK_LINK` and any link used in `@link` contexts.

Acceptance:
- "Credential load" code path contains no `eval`/`source` on dynamic content.
- A grep-based check for obvious secret patterns in logs output points is clean.

---

## Phase 2: Config + Fallback Policy Alignment (Restore Conventions)

Tasks:
1) Preflight validator in plugin commands touching Oracle:
   - verify required vars, binaries, and permissions before side effects.
2) Standalone mode:
   - either remove, or require explicit `--standalone` (or `DCX_STANDALONE=1`)
   - prevent production command paths from silently downgrading behavior.

Acceptance:
- Production commands fail fast without required DCX infrastructure unless explicitly in standalone mode.

---

## Phase 3: Data Pump Optimization Completion (Close `dcx-ycf` Fully)

Tasks:
1) Replace filename heuristic with parfile parsing:
   - parse `TABLES=` and/or `SCHEMAS=` from each parfile to map object -> size bucket.
2) Fix schema determination for wallet connections:
   - do not derive schema from connection string; use config/schema from parfiles.
3) Implement "skip-empty" requirement:
   - decide approach (stats-based vs probe query), document tradeoffs.
4) Decide/implement "pre-computar subqueries":
   - either implement materialization step (with explicit user-controlled SQL) or formally de-scope with rationale.

Acceptance:
- `--optimize` behavior is deterministic and correct for wallet (`/@...`) connections.
- `skip-empty` is implemented and tested.

---

## Phase 4: Versioning and Release Integrity (Core vs Plugin)

Tasks:
1) Decide ownership model:
   - submodule pin, subtree vendor, or install-time pin (recommended: pin + version check).
2) Surface plugin version in `dcx version` (or `dcx oracle version`).
3) CI gate:
   - fails if plugin version drift is detected or if contract tests fail.

Acceptance:
- A release of `dcx` can be reproduced with a known plugin version.

---

## Phase 5: Verification (Evidence-Based Close)

Deliverables:
- `docs/audits/v0.2.x-contract-security-perf.md` containing:
  - requirement -> evidence -> command output snippets (non-secret)
  - known limitations and de-scoped items

Verification checklist:
- tests: plugin test suite + any core tests
- config precedence: explicitly validated
- security: no `eval`, redaction in place, no plaintext requirement
- performance: skip-empty + optimization correctness tested
