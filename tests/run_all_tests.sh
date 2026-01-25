#!/usr/bin/env bash
#===============================================================================
# run_all_tests.sh - Test suite runner for dcx
#===============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
SUITES_RUN=0
SUITES_PASSED=0
SUITES_FAILED=0

echo ""
echo -e "${BOLD}dcx Test Suite${NC}"
echo "========================================"
echo ""

# Run each test file
for test_file in "${SCRIPT_DIR}"/test_*.sh; do
    [[ -f "$test_file" ]] || continue
    [[ "$(basename "$test_file")" == "test_helpers.sh" ]] && continue

    test_name=$(basename "$test_file" .sh)
    SUITES_RUN=$((SUITES_RUN + 1))

    echo -e "${CYAN}Running ${test_name}...${NC}"

    # Capture output and exit code
    set +e
    output=$("$test_file" 2>&1)
    exit_code=$?
    set -e

    # Display output
    echo "$output"

    # Extract test counts from output
    if [[ "$output" =~ Tests:\ ([0-9]+)\ \|\ Passed:\ ([0-9]+)\ \|\ Failed:\ ([0-9]+) ]]; then
        suite_tests="${BASH_REMATCH[1]}"
        suite_passed="${BASH_REMATCH[2]}"
        suite_failed="${BASH_REMATCH[3]}"

        TOTAL_TESTS=$((TOTAL_TESTS + suite_tests))
        TOTAL_PASSED=$((TOTAL_PASSED + suite_passed))
        TOTAL_FAILED=$((TOTAL_FAILED + suite_failed))
    fi

    if [[ $exit_code -eq 0 ]]; then
        SUITES_PASSED=$((SUITES_PASSED + 1))
    else
        SUITES_FAILED=$((SUITES_FAILED + 1))
    fi

    echo ""
done

# Summary
echo "========================================"
echo -e "${BOLD}Final Summary${NC}"
echo "========================================"
echo ""
echo -e "Test Suites: ${SUITES_RUN} | ${GREEN}Passed: ${SUITES_PASSED}${NC} | ${RED}Failed: ${SUITES_FAILED}${NC}"
echo -e "Total Tests: ${TOTAL_TESTS} | ${GREEN}Passed: ${TOTAL_PASSED}${NC} | ${RED}Failed: ${TOTAL_FAILED}${NC}"
echo ""

if [[ $SUITES_FAILED -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All test suites passed!${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}Some test suites failed.${NC}"
    exit 1
fi
