#!/usr/bin/env bash
#===============================================================================
# example_workflow.sh - Example dc-scripts usage
#===============================================================================
# Demonstrates:
#   - Loading the library
#   - Configuration management
#   - Interactive prompts
#   - Spinners and logging
#   - Parallel execution
#===============================================================================

set -euo pipefail

# Get script directory and load dc-scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/core.sh"
dc_load

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    log info "dc-scripts Example Workflow"
    echo ""

    # Check dependencies
    log info "Checking dependencies..."
    need_cmds curl grep sed

    # Interactive selection
    log info "Select environment:"
    local env
    env=$(choose "development" "staging" "production")
    log info "Selected: $env"

    # Confirmation
    if ! confirm "Proceed with $env environment?"; then
        log warn "Aborted by user"
        exit 0
    fi

    # Simulated work with spinner
    spin "Preparing environment..." sleep 1
    spin "Running checks..." sleep 1
    spin "Finalizing..." sleep 1

    # Parallel tasks demonstration
    log info "Running parallel tasks..."
    parallel_run 3 \
        "sleep 0.5 && echo 'Task 1 done'" \
        "sleep 0.3 && echo 'Task 2 done'" \
        "sleep 0.4 && echo 'Task 3 done'"

    log info "All tasks completed!"
    echo ""

    # Styled output
    style --bold --foreground 212 "Workflow completed successfully!"
}

main "$@"
