#!/usr/bin/env bash
#===============================================================================
# dc-scripts/lib/report.sh - Workflow Tracking & Reporting
#===============================================================================
# Version: 0.2.0
# Dependencies: gum (optional, falls back to basic output)
# License: MIT
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DC_REPORT_LOADED:-}" ]] && return 0
declare -r _DC_REPORT_LOADED=1

#===============================================================================
# GLOBAL VARIABLES
#===============================================================================

# Report state
declare -g _DC_REPORT_NAME=""
declare -g _DC_REPORT_FILE=""
declare -g _DC_REPORT_START_TIME=""
declare -g _DC_REPORT_CURRENT_PHASE=""
declare -g _DC_REPORT_PHASE_START=""

# Counters
declare -gi _DC_REPORT_TOTAL_ITEMS=0
declare -gi _DC_REPORT_SUCCESS_ITEMS=0
declare -gi _DC_REPORT_FAILED_ITEMS=0
declare -gi _DC_REPORT_SKIPPED_ITEMS=0

# Metrics (associative array)
declare -gA _DC_REPORT_METRICS=()

# Tracked items (indexed array for order)
declare -ga _DC_REPORT_ITEMS=()

#===============================================================================
# REPORT INITIALIZATION
#===============================================================================

#-------------------------------------------------------------------------------
# report_init - Initialize a new report
#-------------------------------------------------------------------------------
# Usage: report_init "Report Name" [output_file]
# Sets up report tracking with optional markdown output file.
#-------------------------------------------------------------------------------
report_init() {
    local name="$1"
    local file="${2:-}"

    _DC_REPORT_NAME="$name"
    _DC_REPORT_FILE="$file"
    _DC_REPORT_START_TIME=$(date +%s)
    _DC_REPORT_CURRENT_PHASE=""
    _DC_REPORT_PHASE_START=""

    # Reset counters
    _DC_REPORT_TOTAL_ITEMS=0
    _DC_REPORT_SUCCESS_ITEMS=0
    _DC_REPORT_FAILED_ITEMS=0
    _DC_REPORT_SKIPPED_ITEMS=0

    # Reset metrics and items
    _DC_REPORT_METRICS=()
    _DC_REPORT_ITEMS=()

    # Print header
    if command -v gum &>/dev/null; then
        gum style --bold --foreground 212 "=== $name ==="
    else
        echo "=== $name ==="
    fi
    echo ""

    # Initialize markdown file if specified
    if [[ -n "$file" ]]; then
        mkdir -p "$(dirname "$file")"
        cat > "$file" << EOF
# $name

**Started:** $(date -Iseconds)
**Status:** In Progress

---

EOF
    fi
}

#===============================================================================
# PHASE TRACKING
#===============================================================================

#-------------------------------------------------------------------------------
# report_phase - Start a new phase
#-------------------------------------------------------------------------------
# Usage: report_phase "Phase Name" ["Description"]
#-------------------------------------------------------------------------------
report_phase() {
    local phase="$1"
    local description="${2:-}"

    # End previous phase if any
    if [[ -n "$_DC_REPORT_CURRENT_PHASE" ]]; then
        _report_phase_end
    fi

    _DC_REPORT_CURRENT_PHASE="$phase"
    _DC_REPORT_PHASE_START=$(date +%s)

    # Output
    echo ""
    if command -v gum &>/dev/null; then
        gum style --bold --foreground 99 ">> $phase"
        [[ -n "$description" ]] && echo "   $description"
    else
        echo ">> $phase"
        [[ -n "$description" ]] && echo "   $description"
    fi

    # Write to file
    if [[ -n "$_DC_REPORT_FILE" ]]; then
        echo "" >> "$_DC_REPORT_FILE"
        echo "## $phase" >> "$_DC_REPORT_FILE"
        [[ -n "$description" ]] && echo "" >> "$_DC_REPORT_FILE" && echo "$description" >> "$_DC_REPORT_FILE"
        echo "" >> "$_DC_REPORT_FILE"
    fi
}

#-------------------------------------------------------------------------------
# _report_phase_end - End current phase (internal)
#-------------------------------------------------------------------------------
_report_phase_end() {
    if [[ -z "$_DC_REPORT_CURRENT_PHASE" ]]; then
        return
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - _DC_REPORT_PHASE_START))

    if [[ -n "$_DC_REPORT_FILE" ]]; then
        echo "" >> "$_DC_REPORT_FILE"
        echo "_Phase completed in ${duration}s_" >> "$_DC_REPORT_FILE"
    fi

    _DC_REPORT_CURRENT_PHASE=""
}

#===============================================================================
# STEP TRACKING
#===============================================================================

#-------------------------------------------------------------------------------
# report_step - Log start of a step
#-------------------------------------------------------------------------------
# Usage: report_step "Step description"
#-------------------------------------------------------------------------------
report_step() {
    local step="$1"

    echo "   -> $step"

    if [[ -n "$_DC_REPORT_FILE" ]]; then
        echo "- [ ] $step" >> "$_DC_REPORT_FILE"
    fi
}

#-------------------------------------------------------------------------------
# report_step_done - Log completion of a step
#-------------------------------------------------------------------------------
# Usage: report_step_done "Step description" [status]
# status: success (default), failed, skipped
#-------------------------------------------------------------------------------
report_step_done() {
    local step="$1"
    local status="${2:-success}"

    case "$status" in
        success)
            if command -v gum &>/dev/null; then
                gum style --foreground 82 "   [OK] $step"
            else
                echo "   [OK] $step"
            fi
            ;;
        failed)
            if command -v gum &>/dev/null; then
                gum style --foreground 196 "   [FAIL] $step"
            else
                echo "   [FAIL] $step"
            fi
            ;;
        skipped)
            if command -v gum &>/dev/null; then
                gum style --foreground 226 "   [SKIP] $step"
            else
                echo "   [SKIP] $step"
            fi
            ;;
    esac

    if [[ -n "$_DC_REPORT_FILE" ]]; then
        local checkbox="[x]"
        [[ "$status" == "failed" ]] && checkbox="[-]"
        [[ "$status" == "skipped" ]] && checkbox="[~]"
        # Note: This doesn't update the previous unchecked item, but adds completion status
        echo "  - $checkbox $step" >> "$_DC_REPORT_FILE"
    fi
}

#===============================================================================
# ITEM TRACKING
#===============================================================================

#-------------------------------------------------------------------------------
# report_track_item - Track an item with status
#-------------------------------------------------------------------------------
# Usage: report_track_item "item_name" "status" ["message"]
# status: success, failed, skipped, pending
#-------------------------------------------------------------------------------
report_track_item() {
    local item="$1"
    local status="$2"
    local message="${3:-}"

    _DC_REPORT_TOTAL_ITEMS=$((_DC_REPORT_TOTAL_ITEMS + 1))

    case "$status" in
        success)
            _DC_REPORT_SUCCESS_ITEMS=$((_DC_REPORT_SUCCESS_ITEMS + 1))
            ;;
        failed)
            _DC_REPORT_FAILED_ITEMS=$((_DC_REPORT_FAILED_ITEMS + 1))
            ;;
        skipped)
            _DC_REPORT_SKIPPED_ITEMS=$((_DC_REPORT_SKIPPED_ITEMS + 1))
            ;;
    esac

    # Store item
    _DC_REPORT_ITEMS+=("$item|$status|$message")

    # Output
    local icon=""
    case "$status" in
        success) icon="[OK]" ;;
        failed)  icon="[FAIL]" ;;
        skipped) icon="[SKIP]" ;;
        pending) icon="[...]" ;;
    esac

    if [[ -n "$message" ]]; then
        echo "   $icon $item: $message"
    else
        echo "   $icon $item"
    fi
}

#===============================================================================
# METRICS
#===============================================================================

#-------------------------------------------------------------------------------
# report_metric - Set a metric value
#-------------------------------------------------------------------------------
# Usage: report_metric "metric_name" "value"
#-------------------------------------------------------------------------------
report_metric() {
    local name="$1"
    local value="$2"

    _DC_REPORT_METRICS[$name]="$value"
}

#-------------------------------------------------------------------------------
# report_metric_add - Add to a numeric metric
#-------------------------------------------------------------------------------
# Usage: report_metric_add "metric_name" increment
#-------------------------------------------------------------------------------
report_metric_add() {
    local name="$1"
    local increment="${2:-1}"

    local current="${_DC_REPORT_METRICS[$name]:-0}"
    _DC_REPORT_METRICS[$name]=$((current + increment))
}

#-------------------------------------------------------------------------------
# report_metric_get - Get a metric value
#-------------------------------------------------------------------------------
# Usage: report_metric_get "metric_name" [default]
#-------------------------------------------------------------------------------
report_metric_get() {
    local name="$1"
    local default="${2:-0}"

    echo "${_DC_REPORT_METRICS[$name]:-$default}"
}

#===============================================================================
# INTERACTIVE
#===============================================================================

#-------------------------------------------------------------------------------
# report_confirm - Ask for confirmation and log response
#-------------------------------------------------------------------------------
# Usage: report_confirm "Question?"
# Returns 0 if confirmed, 1 otherwise.
#-------------------------------------------------------------------------------
report_confirm() {
    local question="$1"

    local result=1
    if command -v gum &>/dev/null; then
        if gum confirm "$question"; then
            result=0
        fi
    else
        read -r -p "$question [y/N] " response
        [[ "$response" =~ ^[Yy] ]] && result=0
    fi

    # Log to file
    if [[ -n "$_DC_REPORT_FILE" ]]; then
        local answer="No"
        [[ $result -eq 0 ]] && answer="Yes"
        echo "" >> "$_DC_REPORT_FILE"
        echo "**Confirmation:** $question -> $answer" >> "$_DC_REPORT_FILE"
    fi

    return $result
}

#-------------------------------------------------------------------------------
# report_select - Select from options and log choice
#-------------------------------------------------------------------------------
# Usage: report_select "header" "opt1" "opt2" ...
# Returns: Selected option on stdout
#-------------------------------------------------------------------------------
report_select() {
    local header="$1"
    shift
    local options=("$@")

    local choice=""
    if command -v gum &>/dev/null; then
        choice=$(gum choose --header "$header" "${options[@]}")
    else
        echo "$header"
        local i=1
        for opt in "${options[@]}"; do
            echo "  $i) $opt"
            i=$((i + 1))
        done
        read -r -p "Choice [1-${#options[@]}]: " num
        if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#options[@]} ]]; then
            choice="${options[$((num - 1))]}"
        fi
    fi

    # Log to file
    if [[ -n "$_DC_REPORT_FILE" ]]; then
        echo "" >> "$_DC_REPORT_FILE"
        echo "**Selection:** $header -> $choice" >> "$_DC_REPORT_FILE"
    fi

    echo "$choice"
}

#===============================================================================
# PROGRESS
#===============================================================================

#-------------------------------------------------------------------------------
# report_progress - Show progress bar
#-------------------------------------------------------------------------------
# Usage: report_progress current total ["message"]
#-------------------------------------------------------------------------------
report_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing}"

    local percent=$((current * 100 / total))

    if command -v gum &>/dev/null && [[ -t 1 ]]; then
        # Use spinner for gum progress
        printf "\r   [%3d%%] %s (%d/%d)" "$percent" "$message" "$current" "$total"
    else
        printf "\r   [%3d%%] %s (%d/%d)" "$percent" "$message" "$current" "$total"
    fi

    [[ $current -eq $total ]] && echo ""
}

#===============================================================================
# FINALIZATION
#===============================================================================

#-------------------------------------------------------------------------------
# report_finalize - Finalize and close report
#-------------------------------------------------------------------------------
# Usage: report_finalize ["final_status"]
# final_status: success (default), failed, partial
#-------------------------------------------------------------------------------
report_finalize() {
    local status="${1:-}"

    # End current phase if any
    if [[ -n "$_DC_REPORT_CURRENT_PHASE" ]]; then
        _report_phase_end
    fi

    # Auto-determine status if not specified
    if [[ -z "$status" ]]; then
        if [[ $_DC_REPORT_FAILED_ITEMS -gt 0 ]]; then
            if [[ $_DC_REPORT_SUCCESS_ITEMS -gt 0 ]]; then
                status="partial"
            else
                status="failed"
            fi
        else
            status="success"
        fi
    fi

    # Calculate duration
    local end_time
    end_time=$(date +%s)
    local duration=$((_DC_REPORT_START_TIME > 0 ? end_time - _DC_REPORT_START_TIME : 0))
    local duration_str="${duration}s"
    if [[ $duration -ge 60 ]]; then
        duration_str="$((duration / 60))m $((duration % 60))s"
    fi

    echo ""
    echo "========================================"

    # Print summary
    report_summary

    echo "========================================"
    echo "Duration: $duration_str"
    echo ""

    # Update file
    if [[ -n "$_DC_REPORT_FILE" ]]; then
        cat >> "$_DC_REPORT_FILE" << EOF

---

## Summary

| Metric | Value |
|--------|-------|
| Status | ${status^} |
| Duration | $duration_str |
| Total Items | $_DC_REPORT_TOTAL_ITEMS |
| Success | $_DC_REPORT_SUCCESS_ITEMS |
| Failed | $_DC_REPORT_FAILED_ITEMS |
| Skipped | $_DC_REPORT_SKIPPED_ITEMS |

EOF

        # Add custom metrics if any
        if [[ ${#_DC_REPORT_METRICS[@]} -gt 0 ]]; then
            echo "### Custom Metrics" >> "$_DC_REPORT_FILE"
            echo "" >> "$_DC_REPORT_FILE"
            for metric in "${!_DC_REPORT_METRICS[@]}"; do
                echo "- **$metric**: ${_DC_REPORT_METRICS[$metric]}" >> "$_DC_REPORT_FILE"
            done
            echo "" >> "$_DC_REPORT_FILE"
        fi

        # Update status at top of file
        sed -i "s/^\\*\\*Status:\\*\\* In Progress/\\*\\*Status:\\*\\* ${status^}/" "$_DC_REPORT_FILE" 2>/dev/null || true

        echo "Report saved: $_DC_REPORT_FILE"
    fi
}

#-------------------------------------------------------------------------------
# report_summary - Print summary statistics
#-------------------------------------------------------------------------------
# Usage: report_summary
#-------------------------------------------------------------------------------
report_summary() {
    echo ""
    if command -v gum &>/dev/null; then
        gum style --bold "$_DC_REPORT_NAME - Summary"
    else
        echo "$_DC_REPORT_NAME - Summary"
    fi
    echo ""

    # Item counts
    printf "  Total:   %d\n" "$_DC_REPORT_TOTAL_ITEMS"
    if command -v gum &>/dev/null; then
        gum style --foreground 82 "  Success: $_DC_REPORT_SUCCESS_ITEMS"
        [[ $_DC_REPORT_FAILED_ITEMS -gt 0 ]] && gum style --foreground 196 "  Failed:  $_DC_REPORT_FAILED_ITEMS"
        [[ $_DC_REPORT_SKIPPED_ITEMS -gt 0 ]] && gum style --foreground 226 "  Skipped: $_DC_REPORT_SKIPPED_ITEMS"
    else
        printf "  Success: %d\n" "$_DC_REPORT_SUCCESS_ITEMS"
        [[ $_DC_REPORT_FAILED_ITEMS -gt 0 ]] && printf "  Failed:  %d\n" "$_DC_REPORT_FAILED_ITEMS"
        [[ $_DC_REPORT_SKIPPED_ITEMS -gt 0 ]] && printf "  Skipped: %d\n" "$_DC_REPORT_SKIPPED_ITEMS"
    fi

    # Custom metrics
    if [[ ${#_DC_REPORT_METRICS[@]} -gt 0 ]]; then
        echo ""
        echo "  Metrics:"
        for metric in "${!_DC_REPORT_METRICS[@]}"; do
            printf "    %-15s: %s\n" "$metric" "${_DC_REPORT_METRICS[$metric]}"
        done
    fi
}

#-------------------------------------------------------------------------------
# report_table - Display items as a table
#-------------------------------------------------------------------------------
# Usage: report_table
# Shows tracked items in a formatted table.
#-------------------------------------------------------------------------------
report_table() {
    if [[ ${#_DC_REPORT_ITEMS[@]} -eq 0 ]]; then
        echo "No items tracked."
        return
    fi

    echo ""
    printf "%-30s %-10s %s\n" "Item" "Status" "Message"
    printf "%-30s %-10s %s\n" "----" "------" "-------"

    for item_data in "${_DC_REPORT_ITEMS[@]}"; do
        IFS='|' read -r item status message <<< "$item_data"
        printf "%-30s %-10s %s\n" "${item:0:30}" "$status" "${message:0:40}"
    done
}
