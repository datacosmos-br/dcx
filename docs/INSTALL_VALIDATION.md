# DCX + Oracle Plugin - Installation Validation Guide

## Quick Install (Linux)

### 1. Install DCX

```bash
# Option A: Direct install from GitHub
curl -fsSL https://raw.githubusercontent.com/datacosmos-br/dcx/main/install.sh | bash

# Option B: Clone and install manually
git clone https://github.com/datacosmos-br/dcx.git
cd dcx
./install.sh
```

### 2. Verify DCX Installation

```bash
# Check dcx is in PATH
which dcx

# Check version
dcx --version
# Expected: dcx v0.0.1

# Check help
dcx --help

# Run self-test
dcx test
```

### 3. Install Oracle Plugin

```bash
# Option A: Via dcx plugin manager
dcx plugin install oracle

# Option B: Direct install from GitHub
curl -fsSL https://raw.githubusercontent.com/datacosmos-br/dcx-oracle/main/install.sh | bash

# Option C: Clone and install manually
git clone https://github.com/datacosmos-br/dcx-oracle.git
cd dcx-oracle
./install.sh
```

### 4. Verify Oracle Plugin Installation

```bash
# Check plugin is installed
dcx plugin list
# Expected: oracle 0.0.1

# Check oracle commands available
dcx oracle --help

# Validate Oracle environment (requires ORACLE_HOME)
dcx oracle validate
```

---

## Full Validation Script

Copy and run this script on your Linux host:

```bash
#!/bin/bash
#===============================================================================
# DCX + Oracle Plugin Validation Script
# Run on a fresh Linux host to validate installation
#===============================================================================

set -e

echo "=============================================="
echo "  DCX + Oracle Plugin Validation"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "[INFO] $1"; }

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" &>/dev/null; then
        pass "$name"
        ((TESTS_PASSED++))
    else
        fail "$name"
        ((TESTS_FAILED++))
    fi
}

#----------------------------------------------
# Phase 1: DCX Core Validation
#----------------------------------------------
echo ""
echo "=== Phase 1: DCX Core ==="

# 1.1 Check dcx binary exists
run_test "dcx binary exists" "command -v dcx"

# 1.2 Check version
run_test "dcx version is 0.0.1" "dcx --version | grep -q 'v0.0.1'"

# 1.3 Check help works
run_test "dcx help works" "dcx --help"

# 1.4 Check config directory
run_test "dcx config dir exists" "test -d ~/.config/dcx || test -d ~/.local/share/dcx"

# 1.5 Check required tools (gum, yq)
run_test "gum is available" "command -v gum || dcx tool check gum"
run_test "yq is available" "command -v yq || dcx tool check yq"

#----------------------------------------------
# Phase 2: Oracle Plugin Validation
#----------------------------------------------
echo ""
echo "=== Phase 2: Oracle Plugin ==="

# 2.1 Check plugin installed
run_test "oracle plugin installed" "dcx plugin list | grep -q oracle"

# 2.2 Check plugin version
run_test "oracle plugin version 0.0.1" "dcx plugin list | grep oracle | grep -q 0.0.1"

# 2.3 Check oracle help
run_test "dcx oracle help works" "dcx oracle --help"

#----------------------------------------------
# Phase 3: Oracle Environment (Optional)
#----------------------------------------------
echo ""
echo "=== Phase 3: Oracle Environment (Optional) ==="

if [[ -n "${ORACLE_HOME:-}" ]]; then
    info "ORACLE_HOME=$ORACLE_HOME"

    # 3.1 Validate ORACLE_HOME
    run_test "ORACLE_HOME exists" "test -d $ORACLE_HOME"

    # 3.2 Check sqlplus
    run_test "sqlplus available" "test -x $ORACLE_HOME/bin/sqlplus"

    # 3.3 Check rman
    run_test "rman available" "test -x $ORACLE_HOME/bin/rman"

    # 3.4 Run oracle validate
    run_test "dcx oracle validate" "dcx oracle validate"
else
    warn "ORACLE_HOME not set - skipping Oracle environment tests"
    warn "Set ORACLE_HOME and ORACLE_SID to enable Oracle tests"
fi

#----------------------------------------------
# Summary
#----------------------------------------------
echo ""
echo "=============================================="
echo "  Validation Summary"
echo "=============================================="
echo ""
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
```

---

## Quick Test Commands (One-Liners)

```bash
# Quick sanity check
dcx --version && dcx plugin list && echo "DCX OK"

# Full validation (no Oracle env needed)
dcx --version && dcx plugin list | grep oracle && dcx oracle --help && echo "All OK"

# With Oracle environment
export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
export ORACLE_SID=ORCL
dcx oracle validate
```

---

## Troubleshooting

### DCX not found

```bash
# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
# Or add to ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Plugin not found

```bash
# Check plugin directory
ls -la ~/.config/dcx/plugins/
ls -la ~/.local/share/dcx/plugins/

# Reinstall plugin
dcx plugin install oracle --force
```

### Oracle validation fails

```bash
# Check Oracle environment
echo "ORACLE_HOME=$ORACLE_HOME"
echo "ORACLE_SID=$ORACLE_SID"
ls -la $ORACLE_HOME/bin/sqlplus

# Source Oracle environment
source /home/oracle/.bash_profile
# Or
. oraenv
```

---

## GitHub Repositories

- **DCX**: https://github.com/datacosmos-br/dcx
- **DCX Oracle Plugin**: https://github.com/datacosmos-br/dcx-oracle
