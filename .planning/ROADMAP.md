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

### Phase 4: Melhorias Futuras (Backlog)
**Goal:** Features nao criticas
**Requirements:** dcx-bfo, dcx-ycf

| Task | Description | Status |
|------|-------------|--------|
| 4.1 | Sistema de Keyring | ○ |
| 4.2 | Otimizacao dtcosmos export | ○ |

**Success Criteria:**
- [ ] Credenciais nao em texto plano
- [ ] Export/import 2x mais rapido

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
| dcx-bfo | Phase 4 | Pending |
| dcx-ycf | Phase 4 | Pending |

**Coverage:** 8 requirements mapped to 4 phases

---
*Last updated: 2026-02-01 after Phase 3 execution complete*
