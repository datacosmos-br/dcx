# External Integrations

**Analysis Date:** 2026-01-31

## APIs & External Services

**GitHub:**
- Source repository: `github.com/datacosmos-br/dcx`
- Release distribution: GitHub Releases API
- SDK/Client: curl/wget for GitHub API queries
- Auth: None required (public API)
- Purpose: Version checks, release downloads, binary distribution

**GitHub CLI (gh):**
- Used in: `scripts/build-binaries.sh`, `Makefile` (publish targets)
- Purpose: Create releases, upload assets to GitHub Releases
- Integration points: `make publish`, `make publish-platforms`

## Data Storage

**Databases:**
- None - dcx is stateless CLI tool

**File Storage:**
- Local filesystem only - Configuration and plugin data stored in `$DCX_HOME` and `$DCX_CONFIG_DIR`
- Release artifacts: `release/` directory (local)
- Installation path: `$HOME/.local/share/dcx` (Unix standard)

**Caching:**
- None - All artifacts downloaded fresh on demand

## Authentication & Identity

**Auth Provider:**
- None required for core dcx functionality
- Plugins (e.g., dcx-oracle) may require credentials via environment variables

**Oracle Plugin Integration:**
- ORACLE_HOME environment variable - Required, points to Oracle installation
- TNS_ADMIN - Optional, TNS configuration directory
- ORACLE_SID - Optional, default database SID
- No built-in auth; relies on OS-level Oracle authentication and RMAN/SQL*Plus

**OCI Object Storage (dcx-oracle plugin):**
- Connection: OCI_BASE_URL, OCI_NAMESPACE, OCI_BUCKET_NAME environment variables
- Auth: OCI_EXPORT_CREDENTIAL environment variable for programmatic access
- Purpose: Data Pump dumpfile storage for Oracle migrations
- Implementation: URL construction and path management in `dcx-oracle/lib/oracle_oci.sh`

## Monitoring & Observability

**Error Tracking:**
- None - Errors logged to stdout/stderr

**Logs:**
- File-based: Optional file logging configured via `log.file` in `etc/defaults.yaml`
- Format: Text (default) or JSON
- Color output: Auto-detected or configurable via `log.color`
- Levels: debug, info, warn, error, fatal
- Implementation: `lib/logging.sh` provides structured logging functions

## CI/CD & Deployment

**Hosting:**
- GitHub - Source repository and release hosting
- Release distribution: GitHub Releases with platform-specific tarballs
- Self-update mechanism: Downloads from GitHub Releases API

**CI Pipeline:**
- None detected - Manual release workflow via `make deploy`
- Makefile targets: `make validate` (lint + syntax + test), `make release`, `make publish`

## Environment Configuration

**Required env vars:**
- `DCX_HOME` - Installation directory (optional, defaults to `$HOME/.local/share/dcx`)
- No other required variables for core functionality

**Plugin-Specific Required vars (dcx-oracle):**
- `ORACLE_HOME` - Oracle installation directory

**Optional Plugin vars (dcx-oracle):**
- `ORACLE_SID` - Target database SID
- `ORACLE_BASE` - Oracle base directory
- `TNS_ADMIN` - TNS configuration directory
- `OCI_BASE_URL` - OCI Object Storage endpoint
- `OCI_NAMESPACE` - OCI namespace
- `OCI_BUCKET_NAME` - OCI bucket for dumpfiles
- `OCI_EXPORT_CREDENTIAL` - OCI credential string

**Secrets location:**
- Environment variables only - No credential storage mechanism
- Users provide credentials via shell environment

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## External Service Dependencies (by Purpose)

**Binary Distribution:**
```
GitHub Releases API
  ↓
dcx installer (install.sh) downloads release tarball
  ↓
Extracts to $HOME/.local/share/dcx
```

**Update Checking:**
```
curl/wget → GitHub API /repos/datacosmos-br/dcx/releases/latest
  ↓
Parse version from tag_name
  ↓
Compare with $DCX_VERSION
```

**Bundled Tool Downloads:**
```
scripts/build-binaries.sh
  ↓
  ├─ charmbracelet/gum/releases (GitHub)
  ├─ mikefarah/yq/releases (GitHub)
  ├─ BurntSushi/ripgrep/releases (GitHub)
  ├─ sharkdp/fd/releases (GitHub)
  └─ chmln/sd/releases (GitHub)
  ↓
curl/wget → Download platform-specific binaries
```

**Oracle Plugin Integration Points:**
```
dcx oracle <command>
  ↓
Executes local Oracle tools:
  ├─ sqlplus - Oracle SQL execution
  ├─ rman - RMAN backup/restore
  ├─ expdp/impdp - Data Pump utilities
  └─ srvctl - RAC cluster management (optional)
  ↓
Credentials via $ORACLE_HOME, $TNS_ADMIN, $OCI_* vars
```

## API Rate Limiting & Quotas

**GitHub API:**
- Public API: 60 requests/hour per IP
- Authenticated: 5000 requests/hour per user
- dcx uses: Minimal API calls (one per version check)
- Rate limit impact: Very low

**Release Download Limits:**
- GitHub Releases: No bandwidth limit
- Binary URLs: Standard GitHub CDN caching

## Network Communication

**Protocols:**
- HTTPS only - All GitHub API and release downloads
- curl/wget options: `--connect-timeout 10 --max-time 120` (installer)

**Fallback Behavior:**
- curl → wget (automatic fallback if curl not available)
- No hardcoded fallback services - All downloads from GitHub only

---

*Integration audit: 2026-01-31*
