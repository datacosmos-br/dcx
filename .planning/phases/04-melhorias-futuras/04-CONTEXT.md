# Phase 4: Melhorias Futuras - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Non-critical enhancements: (1) Secure credential storage system replacing plain-text credentials, (2) Performance optimization for dtcosmos export/import operations.

</domain>

<decisions>
## Implementation Decisions

### Keyring Storage Backend
- Encrypted file storage at `$DCX_HOME/etc/credentials.enc`
- AES-256-GCM encryption
- Master password: prompt on first use per session, with DCX_KEYRING_PASSWORD env override for automation
- Auto-create credentials file on first credential save (no explicit init required)
- 3 retries on wrong password, then exit with clear error
- Recovery key generated on init - user must save securely
- Auto-detect existing plain-text credentials and offer migration

### Credential Organization
- Hierarchical naming: `service/environment/key` (e.g., `oracle/prod/password`, `oci/dev/api_key`)
- Explicit environment in path (dev/staging/prod as path component)
- CLI commands: `dcx cred get/set/list/delete`
- Access from scripts: `dcx cred export --env` exports to environment variables

### Progress Reporting (dtcosmos export)
- Progress bar with ETA using gum (bundled)
- Verbosity: `-v` for verbose details, `-q` for quiet (just progress bar)
- Non-TTY: suppress progress, just output data (clean for piping)

### Claude's Discretion
- Exact gum progress bar configuration
- Key derivation function for master password
- Recovery key format and length
- Export parallelization strategy details

</decisions>

<specifics>
## Specific Ideas

- Credentials file should work in CI pipelines (env var for password)
- Migration should be non-destructive (keep original files until confirmed)
- Progress should not interfere with data output when piped

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-melhorias-futuras*
*Context gathered: 2026-02-01*
