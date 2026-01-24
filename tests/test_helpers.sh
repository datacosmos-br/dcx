#!/usr/bin/env bash
#===============================================================================
# test_helpers.sh - Framework de testes unificado
#===============================================================================
# Source este arquivo no início de cada teste:
#   source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"
#===============================================================================

# Paths (disponíveis para todos os testes)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Contadores globais
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors (if terminal supports)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

#-------------------------------------------------------------------------------
# Test assertion functions
#-------------------------------------------------------------------------------

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} $1"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} $1"
}

run_test() {
    local name="$1"
    local cmd="$2"
    TESTS_RUN=$((TESTS_RUN + 1))

    if eval "$cmd" &>/dev/null; then
        test_pass "$name"
    else
        test_fail "$name"
    fi
}

#-------------------------------------------------------------------------------
# Assertion helpers
#-------------------------------------------------------------------------------

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-values should be equal}"

    if [[ "$expected" == "$actual" ]]; then
        test_pass "$msg"
    else
        test_fail "$msg (expected: '$expected', got: '$actual')"
    fi
}

assert_ne() {
    local not_expected="$1"
    local actual="$2"
    local msg="${3:-values should not be equal}"

    if [[ "$not_expected" != "$actual" ]]; then
        test_pass "$msg"
    else
        test_fail "$msg (got: '$actual')"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-should contain substring}"

    if [[ "$haystack" == *"$needle"* ]]; then
        test_pass "$msg"
    else
        test_fail "$msg ('$needle' not found)"
    fi
}

assert_true() {
    local cmd="$1"
    local msg="${2:-should succeed}"

    if eval "$cmd" &>/dev/null; then
        test_pass "$msg"
    else
        test_fail "$msg"
    fi
}

assert_false() {
    local cmd="$1"
    local msg="${2:-should fail}"

    if ! eval "$cmd" &>/dev/null; then
        test_pass "$msg"
    else
        test_fail "$msg"
    fi
}

#-------------------------------------------------------------------------------
# Test lifecycle
#-------------------------------------------------------------------------------

# Setup temp dir com cleanup automático
test_setup() {
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT
}

# Assertions de arquivo
assert_file() {
    local file="$1"
    local msg="${2:-File exists: $file}"
    [[ -f "$file" ]] && test_pass "$msg" || test_fail "$msg"
}

assert_dir() {
    local dir="$1"
    local msg="${2:-Dir exists: $dir}"
    [[ -d "$dir" ]] && test_pass "$msg" || test_fail "$msg"
}

test_summary() {
    echo ""
    echo "----------------------------------------"
    echo -e "Tests: ${TESTS_RUN} | ${GREEN}Passed: ${TESTS_PASSED}${NC} | ${RED}Failed: ${TESTS_FAILED}${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}
