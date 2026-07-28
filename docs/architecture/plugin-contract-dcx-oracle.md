# DCX Plugin Contract: dcx-oracle

**Version:** 1.0.0
**Status:** Draft (Pending Approval)
**Created:** 2026-02-02
**Tracking:** dcx-9ie

---

## Purpose

This document defines the **strict, testable contract** between `dcx` (core CLI) and `dcx-oracle` (plugin). All future plugins MUST follow this contract to ensure security, maintainability, and scalability.

---

## 1. Invocation Model

### 1.1 Entry Point
- Core invokes plugin commands via: `dcx oracle <command> [args...]`
- Plugin commands are executable scripts in `dcx-oracle/commands/`.
- Core is responsible for plugin discovery, version validation, and config/credential injection.

### 1.2 Execution Context
- Core sets up the execution environment BEFORE calling the plugin.
- Plugin receives a validated, deterministic context (see Section 2).
- Plugin MUST NOT re-discover or re-parse configuration independently.

---

## 2. Configuration Contract

### 2.1 Precedence (Strict Order)
```
CLI flags > Environment variables > Config files > Defaults
```

### 2.2 Core Responsibility
- Core computes the "effective config" and passes it to the plugin.
- Core validates required keys BEFORE invoking the plugin.
- Core logs the effective config (non-secret fields only) for reproducibility.

### 2.3 Plugin Responsibility
- Plugin MUST NOT source config files as shell code (`source config.sh` is BANNED).
- Plugin MUST NOT implement its own config precedence logic.
- Plugin reads config from environment variables set by core.

### 2.4 Required Config Keys (dcx-oracle)
| Key | Required | Description |
|-----|----------|-------------|
| `DCX_ORACLE_CONNECTION` | Yes | Target connection string (may be `/@TNS` for wallet) |
| `DCX_ORACLE_NETWORK_LINK` | Conditional | Required for network-link operations |
| `DCX_ORACLE_DIRECTORY` | Conditional | Data Pump directory object |
| `DCX_ORACLE_SCHEMA` | Conditional | Schema for operations |

---

## 3. Credential Contract (Secrets as Data)

### 3.1 Core Rules
- **Secrets are DATA, never CODE.**
- No `eval`, `source`, or command substitution on credential material.
- Credentials are passed via environment variables with short lifetime.

### 3.2 Credential Providers (Priority Order)
1. **Oracle Wallet** (`/@TNS_ALIAS`) — preferred, no password needed
2. **DCX Keyring** (`dcx cred get`) — encrypted storage
3. **Environment Variable** — fallback for CI/automation

### 3.3 Plugin Responsibility
- Plugin MUST accept wallet connections (empty password).
- Plugin MUST NOT log, echo, or persist credentials.
- Plugin MUST use redaction helpers for any output that might contain secrets.

### 3.4 Banned Patterns
```bash
# BANNED: Code execution on credential output
eval "$(dcx cred export ...)"
source <(dcx cred export ...)

# ALLOWED: Data-only parsing
while IFS='=' read -r key value; do
  case "$key" in
    DB_ADMIN_USER|DB_ADMIN_PASSWORD|DB_CONNECTION_STRING)
      export "$key=$value"
      ;;
  esac
done < <(dcx cred export --format=env 2>/dev/null)
```

---

## 4. Output Contract (Stdout/Stderr Discipline)

### 4.1 Rules
| Stream | Content | Machine Parseable |
|--------|---------|-------------------|
| stdout | Data/results only | Yes (JSON preferred) |
| stderr | Logs, progress, errors | No (human-readable) |

### 4.2 Implications
- `dcx oracle migrate ... | jq .` MUST work.
- Progress bars, spinners, and status messages go to stderr.
- Errors go to stderr with structured prefix (e.g., `[ERROR]`).

### 4.3 Logging Levels
- `DEBUG`: Verbose internal state (only with `--debug`)
- `INFO`: Normal operation milestones
- `WARN`: Recoverable issues
- `ERROR`: Failures requiring attention

---

## 5. Error Handling Contract

### 5.1 Exit Codes
| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments / usage |
| 3 | Preflight validation failed |
| 4 | Partial success (some operations failed) |
| 5 | External dependency failure (Oracle, network) |

### 5.2 Preflight Validation (Fail-Fast)
- Plugin MUST validate ALL requirements BEFORE any side effects.
- Preflight checks:
  - Required binaries exist and are executable
  - Required config keys are set
  - Permissions are sufficient
  - Network/DB connectivity (optional, can be deferred)

### 5.3 No-Fallback Policy
**Production paths have NO silent fallbacks.**

- If a required capability is missing, FAIL with clear error.
- If config is ambiguous, FAIL with options listed.
- Standalone mode requires explicit opt-in: `--standalone` or `DCX_STANDALONE=1`.

---

## 6. Versioning Contract

### 6.1 Plugin Version
- Plugin declares version in `plugin.yaml`.
- Core checks compatibility: `requires: dcx: ">=0.2.0"`.

### 6.2 Surfacing
- `dcx version` includes plugin versions.
- `dcx oracle version` shows plugin-specific version.

### 6.3 CI Gate
- Release builds FAIL if plugin version is unpinned or incompatible.
- Contract tests run on every PR.

---

## 7. Testing Contract

### 7.1 Contract Tests (Required)
Every plugin MUST pass:
- [ ] Stdout/stderr discipline test
- [ ] Config precedence test
- [ ] No-fallback enforcement test
- [ ] Secret redaction test
- [ ] Exit code correctness test

### 7.2 Integration Tests (Gated)
- Run only when credentials/environment available.
- Gated by: `DCX_INTEGRATION_TESTS=1`

---

## 8. Migration Path (Existing Code)

### Phase 1: Contract Adoption
1. Write this contract doc ✓
2. Add preflight validation to `migrate.sh`
3. Remove `eval` from credential loading

### Phase 2: Config Bundle
1. Core produces config bundle (env vars)
2. Plugin consumes only the bundle
3. Remove `source migration.conf` patterns

### Phase 3: Enforcement
1. Add contract tests to CI
2. Block PRs that violate contract
3. Document exceptions (if any)

---

## Approval

| Role | Name | Date | Decision |
|------|------|------|----------|
| Maintainer | | | Pending |

---

*This contract applies to dcx-oracle and serves as the template for all future dcx plugins.*
