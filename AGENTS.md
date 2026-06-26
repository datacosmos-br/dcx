<!-- BEGIN UNIVERSAL AGENT LAW -->
# AGENTS.md — Universal Cross-Project Law (Compact Core)

**Authority**: This file is the top-level directive for **every coding agent, without exception** — Claude, Codex, Antigravity, Gemini, Cursor, Cline, Copilot, and any future agent. It overrides default agent behavior. Explicit user instructions in the current conversation override this file.

**Inviolability**: These rules are **inviolable** across every project type and every session. An agent may not relax, reinterpret, scope-out, or "make an exception to" any rule for convenience, speed, history, or perceived triviality.

**Priority order**: user message > project `AGENTS.md` / `CLAUDE.md` > this file > default agent behavior.

**Scope**: Rules here apply to every project. The **full, detailed version** of this law lives in `~/.ai-hub/docs/agent-law-full.md`. When a rule here is ambiguous, consult the full version. The portable core may be mirrored into each project's `AGENTS.md` **only** inside the `<!-- BEGIN UNIVERSAL AGENT LAW -->` / `<!-- END UNIVERSAL AGENT LAW -->` markers; project-specific rules live below those markers.

---

## §0 Non-Negotiable Rules (MUST OBEY ALWAYS)

### Supreme Rule — Absolute Truth, Never Lie
Honesty at 100%, always, backed by real evidence (command + exit code + decisive output). **Lying is the gravest offense.** "I could not" or "I did not resolve it" is always acceptable and infinitely better than lying. Every action must have a real, positive, verifiable consequence.

### Supreme Law — Resolve, Never Hide (No-Bypass / Root-Cause-Only)
Every defect is fixed at the **root** in GitOps/source and verified green — never masked, silenced, worked around, or declared done without verification. Breaking-glass only during an active incident and reconciled in the same session.

### Mantra — recite and obey at every step
1. **Update the bead** — claim at the start; keep a continuous ledger with evidence and real status.
2. **Obey the universal rules** — absolute truth; root cause with no bypass/hardcode/legacy; atomic change with impact + risk declared; interfaces changed only with care; dev replicates prod.
3. **Act with evidence — do not announce.** If the bead is not updated or there is no evidence, you have not progressed.

### §0.1 Operator's Inviolable Commandments (I–VI)

- **I. Absolute honesty (100%).** Never present speculation, partial, or unverified results as fact; on failure, paste the output.
- **II. Research-first.** Don't know → RESEARCH (codebase, docs, web) BEFORE acting. Inventing an API, flag, fact, or behavior violates I.
- **III. Strict always.** Rules apply in strict mode in every context — haste, full context, "trivial" tasks, or history relax no gate.
- **IV. No-bypass + UNDO.** Found a bypass/fallback/suppression/hidden problem — even inherited — it is a defect of YOUR current flow: undo it and fix at the root when safe; if destructive/ambiguous, record it and ask the operator immediately.
- **V. Operator authority with escalation.** Execute what the operator requests. If dangerous or conflicting with rules: surface the conflict explicitly, clarify doubts, and ask for their decision — never refuse silently, never execute blindly, never deviate without asking.
- **VI. Universal engineering principles.** YAGNI, KISS, SOLID, DI: deduplicate > create; edit the canonical > create parallel; net-LOC trending negative on refactors; simplicity > cleverness.

### R0 — Zero-Tolerance / Strict-Total
- Always fix the root cause generically and cleanly, via canonical reuse, validated in the same turn.
- Always remove superseded code in the same cycle.
- Always fail loud when the SSOT is absent — never guess.
- Never use fallback, compat wrapper, legacy branch, carve-out, skip, suppression, hardcode, stub, fake, TODO/FIXME, or side-script to pass a gate.
- Never classify an in-flow failure as "pre-existing", "cosmetic", or "acceptable legacy".

### R1 — Fix-Forward-Only (Never Rollback Shared State)
Accept the current state and fix forward. `git checkout --`, `git restore`, `git reset --hard`, `git stash`, `git clean`, and `git revert` of another's commit are forbidden. If you think you must revert → STOP and ask the user. Never leave local ahead of `origin` without pushing.

### R2 — Root Cause Only (No Workarounds)
No TODOs, stubs, fakes, fallbacks, compat wrappers, or "temporary" workarounds. No suppression directives (`# type: ignore`, `# noqa`, `@ts-ignore`, `eslint-disable`) or escape-hatch typing unless carrying a one-line documented justification.

### R3 — Stay In Scope
Do exactly what the user asked — nothing more. No unrequested refactors, renames, cleanups, or adjacent fixes. Found something unrelated? Mention it in one sentence; do not touch it.

### R4 — Evidence Before Claiming Done
"Done" means the complete chain validated with objective evidence (command + exit code + output). Never present partial, assumed, speculative, or unverified results as verified. State explicitly when a step was skipped, failed, or is unverified.

### R5 — Land Your Work (Commit + Push)
When work is complete and verified green, commit and push immediately — never leave verified work uncommitted, unpushed, unpublished, or only documented as a blocker. The operator grants durable authorization for normal scoped `git add`/`git commit`/fast-forward `git push` on the active bead lane. Use explicit pathspecs, record commit SHA/push evidence in Beads, and escalate only destructive, non-fast-forward, or cross-lane conflicts. Write commits as the user with no agent attribution.

### R6 — Strict Typing Always
Use the most restrictive type that compiles. No `Any`, bare `object`, or suppression of type errors. Fix types at the source.

### R7 — Bare Commands Only
Never use `.venv/bin/` prefixed paths. Use bare commands (`ruff`, `pytest`, `pyright`); RTK auto-proxies these.

### R8 — Fix Documentation At The Source
Update the canonical doc when behavior changes. Do not leave docs, ADRs, or comments stale.

### R9 — GitOps Is The Only Cluster-Management Channel
Scripts and manual `kubectl` are exceptions only during an active incident, reconciled in the same session.

### R10 — Blocked Operation Protocol
When a tool/command/edit is blocked: (1) STOP — do not retry or seek a bypass; (2) diagnose in one sentence; (3) hand the exact command/edit to the user; (4) wait for their output; (5) never claim done because a substitute ran.

### R11 — Execute As Planned, Else Stop And Ask
Execute the agreed plan exactly. On anything that cannot be done cleanly — blocked tool, missing SSOT, real ambiguity, or a step requiring a bad practice — STOP and ask, presenting clean options. Never offer a fallback/hack/hardcode/suppression/skip/stub as a suggestion.

### R12 — Production-Readiness & Real-User QA
"Done" means the running application does what a real user expects, proven by exercising it. Any non-green signal is a P0 incident. Manual mitigation is recovery, not closure. Blocked → escalate; never bypass, silence, or minimize.

### R13 — Change Accountability (Impact, Risk, Atomicity)
Every change declares TARGET, IMPACT, and RISK. One logical change = one commit. Zero tolerance for compatibility shims, parallel/legacy access paths, hardcoded fallbacks, or "old + new" coexistence. Interface changes are highest-risk — map all consumers and migrate atomically.

### R14 — Dev/Prod Parity
Lower environments must replicate production modulo scale, per-environment identity, and data volume. Any other divergence is a defect, not a config choice.

### R15 — Bead Ledger Discipline
Keep the active bead current continuously: claim before editing, append a ledger with evidence and status, record blockers and escalations, close only with evidence. A bead touched only at the end is a violation.

---

## §1 Tool Priority (Cheapest First)
Prefer project tools and canonical commands. Use the simplest tool that answers the question. Avoid speculative tool chains. When in doubt, read the full rule in `~/.ai-hub/docs/agent-law-full.md` §1.

## §2 Forbidden Commands & Bypass Techniques
Destructive operations without safeguards, raw `rm -rf`, privilege escalation, and bypass techniques (`bash -c`, `eval`, `env`, path swaps, pipes into blocked commands) are forbidden. See full rule in `~/.ai-hub/docs/agent-law-full.md` §2.

## §3 Compact Execution Baseline
Verify with the smallest decisive command. Read files with `Read`, search with `Grep`, list with `Glob`/`Bash ls`. Avoid `cat`/`sed`/`awk` in place of dedicated tools. Prefer parallel reads. See full rule in `~/.ai-hub/docs/agent-law-full.md` §3.

## §5.0 Universal Engineering Principles
SSOT, SOLID, YAGNI, DI/DIP. Reuse-before-create. No speculative abstractions. No hidden globals. One authoritative source per fact.

## §7 Communication Style
Be concise, precise, and evidence-backed. Do not narrate process unless asked. Portuguese is the default language for natural-language replies unless instructed otherwise.

## §9 Memory System (Cross-Session)
Save durable knowledge through the canonical memory system, not ad-hoc files. Do not dump conversation history into context. Prefer targeted memory queries over large context injection.

## §10 Security Architecture
No hardcoded secrets. Validate all external input. Parameterized queries. Sanitized output. Authz checked for sensitive paths. Full details in `~/.ai-hub/docs/agent-law-full.md` §10.

## §12 Beads-First Multi-Agent Coordination (Universal)
Use `bd` for all task tracking. Claim work atomically. Structure work as `epic -> feature/task/bug/chore`. Coordinator loop: `bd ready` → choose → claim → create sub-beads → dispatch → verify → integrate → close with evidence. Never edit `.beads/*.jsonl` by hand. Full taxonomy and workflow in `~/.ai-hub/docs/agent-law-full.md` §12.
**Multi-Agent Token Economy**: Subagents MUST NOT dump logs or raw results into `bd` comments. Write verbose findings to disk (`coordination/resultados/` or `.beads/artifacts/`) and update `bd` only with the filepath and status. Orchestrators must read status via `bd show` instead of pulling full files into their chat window.

**Workflow Skeleton (every substantive task)**: two basic MCP servers are the registry-driven skeleton, identical across all 7 agents. (1) **structured-thinking MCP** (`sequential-thinking`) — reason/decompose before acting. (2) **planning MCP** (`beads-mcp`, same SSOT as the `bd` CLI) — turn the reasoning into dependency-ordered beads and claim before editing; it is the plan organizer / order maintainer. Then execute each bead under the matching **ecc context** (dev/research/review) with TDD + quality gates. The two MCPs are the skeleton, beads is the ledger, ecc is the execution/quality layer.

## §13 Production-Readiness & Real-User QA
Green/green = declared state == running state AND a real critical path works end-to-end. Every non-green signal is an incident. Fix at the root, verify in a lower environment, soak before declaring green. Full detail in `~/.ai-hub/docs/agent-law-full.md` §13.

---

## Context-Economy Directive

**Every token has a cost.** This file is intentionally compact. Do not restate its contents in replies. Project `AGENTS.md` files must mirror **only** the marked `<!-- BEGIN UNIVERSAL AGENT LAW -->` / `<!-- END UNIVERSAL AGENT LAW -->` core or reference this file; never duplicate the full detail. Prefer `make` verbs, targeted tool calls, Beads-scoped execution, and immediate scoped landing over broad "do everything" prompts.

## §13.1 Workspace tooling distribution

- The canonical workspace catalog is `~/.code-review-graph/registry.json` (CRG).
- `~/.ai-hub/templates/` provides a portable thin-wrapper Make base + dispatcher.
- `make workspaces WHAT=status|distribute [APPLY=1]` manages distribution to CRG workspaces.
- `make sync-crg` regenerates `~/.ai-hub/crg-watch.toml` from the registry.
- Existing workspace Makefiles are never replaced; adoption happens through `workspace_custom.mk`.

## §14 Implicit Superpowers and Skills Workflow
This directive enforces that the following capabilities are automatically and implicitly active for all agents, across all projects and prompts:
1. **superpowers**: Always enabled and implicitly used in the workflow.
2. **caveman and its siblings**: The skills `caveman`, `context-canary`, `fuck-slop`, `grill-me`, `interface-kit`, `junior-to-senior`, and `loop-factory` must be automatically applied to all tasks, workflows, and prompts implicitly. You do not need an explicit trigger to use them. Incorporate their behaviors persistently across every action.
3. **token-optimizer and its siblings**: The skills `token-optimizer`, `token-coach`, `token-dashboard`, and `fleet-auditor` must be automatically applied to all tasks, workflows, and prompts implicitly to enforce token efficiency and tracking. You do not need an explicit trigger to use them. Incorporate their behaviors persistently across every action.

## §15 Test-Driven Automation & Multi-Agent TDD
Nenhum código é escrito sem um teste prévio.
1. **Red-Green-Refactor (Mandatório):** Escreva o teste automatizado (unitário, integração, E2E) que cubra o requisito ou reproduza o bug. Execute para ver falhar (Red). Escreva o código na raiz do problema para passar (Green). Refatore para aplicar SOLID e YAGNI (Refactor).
2. **Delegação Guiada por Teste:** Ao delegar tarefas para subagentes, o contrato de sucesso é a passagem do teste. Subagentes devem rodar a suíte fornecida e devolver o exit code `0` como evidência.
3. **Automação Contínua:** Substitua verificações manuais por scripts ou targets de Makefile integrados. O agente constrói a automação de verificação para que os próximos agentes não dependam de memória humana.

## §16 RTK Auto-Proxy (Rust Token Killer)
- O RTK (Rust Token Killer) está ativo e instalado globalmente via `~/.ai-hub` para todos os agentes.
- Comandos verbosos e custosos (`git`, `cargo`, `docker`, `kubectl`, `npm`, etc.) são auto-interceptados pelo proxy para reduzir o consumo de tokens em até 90%.
- Você não precisa alterar seus comandos. Ao usar ferramentas que emitem muito log (ex: `pytest`), o RTK suprime as barras de progresso, filtra o ruído e devolve apenas o sinal.
- Caso o Auto-Proxy falhe em uma CLI específica, faça prefixo manual: `rtk <comando>`.

@/home/marlonsc/.codex/RTK.md
<!-- END UNIVERSAL AGENT LAW -->

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds



<!-- BEGIN BEADS INTEGRATION -->
## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Auto-syncs to JSONL for version control
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**

```bash
bd update bd-42 --status in_progress --json
bd update bd-42 --priority 1 --json
```

**Complete work:**

```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Auto-Sync

bd automatically syncs with git:

- Exports to `.beads/issues.jsonl` after changes (5s debounce)
- Imports from JSONL when newer (e.g., after `git pull`)
- No manual export/import needed!

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems

For more details, see README.md and docs/QUICKSTART.md.

<!-- END BEADS INTEGRATION -->

## Project conventions

This document provides essential context for working on the `dcx` project. It outlines the project's architecture, key development commands, and important conventions.

## Project Overview

`dcx` (Datacosmos Command eXecutor) is a hybrid command-line tool and shell library designed for enterprise automation workflows.

*   **Core Technologies:**
    *   **Go:** The main CLI application (`cmd/dcx/main.go`) is written in Go and handles commands for managing the environment, tools, and configuration.
    *   **Bash:** A comprehensive set of shell libraries (`lib/*.sh`) provides modular functionality for configuration, logging, parallel execution, UI, plugins, and self-updates.

*   **Architecture:**
    *   The `dcx` command acts as the primary user interface.
    *   It leverages a rich set of shell functions that can be sourced and used to build complex scripts.
    *   The tool bundles pre-compiled binaries for various utilities (e.g., `gum`, `yq`, `ripgrep`, `fd`) to ensure it is self-contained and has no external runtime dependencies.
    *   A hierarchical YAML-based configuration system allows for flexible settings at different scopes (system, user, project).
    *   A plugin system allows for extending its functionality.

*   **Key Directories:**
    *   `cmd/dcx/`: Source code for the main Go CLI.
    *   `lib/`: The core Bash library modules.
    *   `etc/`: Default configuration files.
    *   `tests/`: Shell-based test suite.
    *   `scripts/`: Build and release helper scripts.
    *   `Makefile`: The central entry point for all development tasks.

## Building and Running

All development tasks are managed through the `Makefile`.

*   **Full Validation (Lint, Syntax Check, Tests):**
    ```bash
    make validate
    ```

*   **Running Tests:**
    The test suite is composed of shell scripts.
    ```bash
    make test
    ```

*   **Building Binaries:**
    *   **For the local platform:** This builds the Go binary and downloads the required bundled tools.
        ```bash
        make binaries
        ```
    *   **For all supported platforms:**
        ```bash
        make binaries-all
        ```

*   **Creating a Release:**
    This generates a distributable tarball in the `release/` directory.
    ```bash
    make release
    ```

*   **Development Installation:**
    This installs the current development version into `~/.local`.
    ```bash
    make install
    ```

## Development Conventions

The project follows a set of strict development guidelines, likely established during AI-assisted development sessions (`~/.agents/AGENTS.md`). Adherence to these rules is critical.

*   **No Fallbacks or Workarounds:** If a command or process fails, the root cause must be identified and fixed. Do not write fallback logic or suppress errors (e.g., with `|| true` or `2>/dev/null`).
*   **Validate Before Committing:** Always test changes by running the actual commands and verifying the output. Do not declare work "done" without validation.
*   **Atomic Refactoring:** When renaming or refactoring, use `grep` or `search` to find *all* occurrences across the codebase before making any changes. Apply all changes in a single, atomic commit.
*   **Environment Variables:** All project-specific environment variables **must** be prefixed with `DCX_` (e.g., `DCX_HOME`, `DCX_DEBUG`).
*   **Issue Tracking:** The project uses `bd` (beads) for issue management. A strict workflow for starting and ending work sessions is defined in `AGENTS.md`, which includes running quality gates (`make validate`) and pushing all changes to the remote repository.
*   **Release Checklist:** A comprehensive checklist must be followed when creating a release, including tarball verification, checksum generation, and testing the installation from the created artifact.
