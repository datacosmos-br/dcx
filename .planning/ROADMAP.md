# DCX Roadmap - v0.2.0 Milestone

**Created:** 2026-02-01
**Target:** Refatoracao DRY, correcao de bugs, otimizacao

## Milestone v0.2.0: Qualidade e Performance

### Phase 1: Bug Fixes Criticos ✓
**Goal:** Corrigir bugs bloqueadores de producao
**Requirements:** dcx-6dl, dcx-5vo, dcx-cvz
**Completed:** 2026-02-01

| Task | Description | Status |
|------|-------------|--------|
| 1.1 | Fix oracle_rman.sh:324 unbound variable | ✓ |
| 1.2 | Fix RMAN catalog validation (linha 613) | ✓ |
| 1.3 | Fix --resume-from=restore skip validate | ✓ |

**Success Criteria:**
- [x] Todos os scripts passam com `set -u`
- [x] RMAN restore funciona sem erros
- [x] --resume-from respeita skip correto

---

### Phase 2: Consolidacao de Codigo ✓
**Goal:** Eliminar duplicacao em lib/*.sh - merge core.sh/runtime.sh com core_ prefix, verificar Oracle helpers
**Requirements:** dcx-uqy, dcx-rgt
**Completed:** 2026-02-01

Plans:
- [x] 02-01-PLAN.md — Merge runtime.sh into core.sh with core_ prefix (a0b35ae)
- [x] 02-02-PLAN.md — Update all callers to core_ prefix and delete runtime.sh (e7b6a76)
- [x] 02-03-PLAN.md — Verify oracle_sql.sh helpers and _dc_find_binary Oracle support (eaa2069)

| Task | Description | Status |
|------|-------------|--------|
| 2.1 | Consolidar core.sh/runtime.sh com core_ prefix | ✓ |
| 2.2 | Verificar helpers oracle_sql.sh (already optimized) | ✓ |
| 2.3 | Verificar _dc_find_binary() suporta Oracle binaries | ✓ |

**Success Criteria:**
- [x] core.sh e unico arquivo com core_ prefix (nao shim)
- [x] Todos os callers usam core_ prefix
- [x] oracle_sql.sh verificado (36% reduction already done per file header)
- [x] _dc_find_binary suporta ORACLE_HOME/bin para ferramentas Oracle

---

### Phase 3: Refatoracao de Testes ✓
**Goal:** Framework de testes unificado com describe blocks, auto-sourcing, e reducao ~38% em codigo
**Requirements:** dcx-zwp
**Completed:** 2026-02-01

Plans:
- [x] 03-01-PLAN.md — Enhance test_helpers.sh with describe blocks, assert_match, auto-sourcing, timing (14a0770)
- [x] 03-02-PLAN.md — Convert all test files to unified pattern and validate (e6276dc)

| Task | Description | Status |
|------|-------------|--------|
| 3.1 | Melhorar test_helpers.sh | ✓ |
| 3.2 | Converter todos test_*.sh | ✓ |
| 3.3 | Validar make test passa | ✓ |

**Success Criteria:**
- [x] test_helpers.sh e framework unico (describe blocks, assert_match, auto-source, timing)
- [x] Test count increased: 225 tests (up from 212 baseline)
- [x] 221/225 tests pass (4 failures are pre-existing tools.yaml bug)

---

### Phase 4: Melhorias Futuras (Backlog) ✓
**Goal:** Secure credential storage and Data Pump progress reporting
**Requirements:** dcx-bfo, dcx-ycf
**Completed:** 2026-02-01

Plans:
- [x] 04-01-PLAN.md — Core credential library (lib/cred.sh) with AES-256-CBC encryption (c4ee395)
- [x] 04-02-PLAN.md — Go CLI for credential management (dcx cred get/set/list/delete) (7529fc1)
- [x] 04-03-PLAN.md — Migration from plain-text and env export (a4ff77b)
- [x] 04-04-PLAN.md — Data Pump progress bar with gum (73e0e98)

| Task | Description | Status |
|------|-------------|--------|
| 4.1 | Sistema de Keyring | ✓ |
| 4.2 | Otimizacao dtcosmos export | ✓ |

**Success Criteria:**
- [x] Credenciais nao em texto plano
- [x] Progress bar with ETA for Data Pump operations

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| dcx-6dl | Phase 1 | Complete |
| dcx-5vo | Phase 1 | Complete |
| dcx-cvz | Phase 1 | Complete |
| dcx-uqy | Phase 2 | Complete |
| dcx-rgt | Phase 2 | Complete |
| dcx-zwp | Phase 3 | Complete |
| dcx-bfo | Phase 4 | Complete |
| dcx-ycf | Phase 4 | Complete |

**Coverage:** 8 requirements mapped to 4 phases

---
*Last updated: 2026-02-01 after Phase 4 execution complete*

---

## Milestone v0.2.x: Plugin Contract + Security + Data Pump Rescue (OC Workflow)

**Goal:** Make `dcx` + `dcx-oracle` scalable for more plugins by enforcing an explicit plugin contract, removing high-risk security surfaces, and completing Data Pump performance requirements with evidence.

**Tracking (Beads):**
- `dcx-ma6` (epic) contract + security + perf rescue
- `dcx-yh0` (P0) remove eval-based credential loading
- `dcx-9ie` (P1) define contract + enforce preflight
- `dcx-bg9` (P1) complete dcx-ycf remainder (skip-empty, precompute-subqueries decision, robust parsing)

### Phase 5: Plugin Contract (Architecture)
**Goal:** Define and approve a strict, testable contract between core and plugins.

Plans:
- [ ] 05-01-PLAN.md — Write contract doc + decision on no-fallback policy

**Success Criteria:**
- [ ] Contract doc exists and is approved
- [ ] Explicit policy: no-fallback for production paths (standalone explicit)
- [ ] Stdout/stderr discipline defined

---

### Phase 6: Security Hardening (Secrets as Data)
**Goal:** Remove code-execution surfaces (`eval`), enforce redaction, and lock down db-link identifiers.

Plans:
- [ ] 06-01-PLAN.md — Replace `eval` with allowlisted parsing / structured export
- [ ] 06-02-PLAN.md — Logging redaction and no-secret output policy

**Success Criteria:**
- [ ] No `eval`/`source` of credential material
- [ ] Secrets never appear in logs

---

### Phase 7: Config + Fallback Alignment
**Goal:** Make config precedence deterministic; ban silent fallbacks for production operations.

Plans:
- [ ] 07-01-PLAN.md — Preflight validation and explicit standalone mode

**Success Criteria:**
- [ ] Preflight fails fast before side effects
- [ ] Standalone requires explicit opt-in

---

### Phase 8: Data Pump Optimization Completion
**Goal:** Finish remaining `dcx-ycf` asks with correctness and evidence.

Plans:
- [ ] 08-01-PLAN.md — Robust parfile parsing (TABLES/SCHEMAS), schema derivation fix
- [ ] 08-02-PLAN.md — Implement skip-empty behavior
- [ ] 08-03-PLAN.md — Decide/implement precompute-subqueries (or formally de-scope)

**Success Criteria:**
- [ ] `--optimize` correct for wallet (`/@...`) connections
- [ ] skip-empty implemented and tested
- [ ] precompute-subqueries decision documented

---

### Phase 9: Versioning + Release Integrity
**Goal:** Make core releases reproducible against a pinned plugin version.

Plans:
- [ ] 09-01-PLAN.md — Choose pinning model (registry/pin recommended) and add CI gate

**Success Criteria:**
- [ ] Plugin version surfaced in `dcx version` or `dcx oracle version`
- [ ] CI rejects drift/unpinned plugin version

---

### Phase 10: Evidence-Based Audit & Close
**Goal:** Produce a single audit report mapping requirements to evidence.

Plans:
- [ ] 10-01-PLAN.md — Write audit report and verify all success criteria

**Success Criteria:**
- [ ] `docs/audits/v0.2.x-contract-security-perf.md` complete
- [ ] Beads issues closed with evidence
