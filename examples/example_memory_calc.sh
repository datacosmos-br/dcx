#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Example: Oracle Memory Calculation
#
# This script demonstrates oracle.sh utilities for memory sizing.
# Shows SGA/PGA calculation based on available system memory.
#
# Usage:
#   ./example_memory_calc.sh
#   SGA_TARGET=12G PGA_TARGET=4G ./example_memory_calc.sh  # Override
#===============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/oracle.sh"

#===============================================================================
# SYSTEM MEMORY INFO
#===============================================================================

echo "=== System Memory Information ==="
echo
free -h
echo

#===============================================================================
# AUTO-CALCULATE SGA/PGA
#===============================================================================

echo "=== Auto-Calculate SGA/PGA ==="
echo

# Clear any overrides for demo
unset SGA_TARGET 2>/dev/null || true
unset PGA_TARGET 2>/dev/null || true

log "Calculating optimal SGA/PGA based on available memory..."
read -r sga pga < <(oracle_config_calc_memory)

echo
log "Calculated values:"
log "  SGA_TARGET: ${sga}"
log "  PGA_TARGET: ${pga}"

# Validate the calculated values
oracle_config_validate_mem_value "${sga}"
oracle_config_validate_mem_value "${pga}"
log "Both values are valid memory formats!"

#===============================================================================
# OVERRIDE WITH CUSTOM VALUES
#===============================================================================

echo
echo "=== Override with Custom Values ==="
echo

export SGA_TARGET="16G"
export PGA_TARGET="8G"

log "Using overrides: SGA_TARGET=${SGA_TARGET}, PGA_TARGET=${PGA_TARGET}"
read -r sga_override pga_override < <(oracle_config_calc_memory)

echo
log "Returned values (with override):"
log "  SGA_TARGET: ${sga_override}"
log "  PGA_TARGET: ${pga_override}"

#===============================================================================
# MEMORY VALIDATION EXAMPLES
#===============================================================================

echo
echo "=== Memory Value Validation ==="
echo

valid_values=("4G" "512M" "1024K" "2g" "256m" "8192k")
invalid_values=("4GB" "512MB" "4" "G" "abc" "4 G")

log "Testing valid values..."
for v in "${valid_values[@]}"; do
    if oracle_config_validate_mem_value "${v}" 2>/dev/null; then
        echo "  ${v}: VALID"
    else
        echo "  ${v}: INVALID (unexpected!)"
    fi
done

echo
log "Testing invalid values (these should fail)..."
for v in "${invalid_values[@]}"; do
    if oracle_config_validate_mem_value "${v}" 2>/dev/null; then
        echo "  '${v}': VALID (unexpected!)"
    else
        echo "  '${v}': INVALID (expected)"
    fi
done

#===============================================================================
# PRACTICAL SIZING RECOMMENDATIONS
#===============================================================================

echo
echo "=== Practical Sizing Recommendations ==="
echo

# Get raw numbers for calculations
unset SGA_TARGET PGA_TARGET
total_mem_gb=$(free -g | awk '/^Mem:/ {print $2}')
avail_mem_gb=$(free -g | awk '/^Mem:/ {print $7}')

echo "Total system memory:     ${total_mem_gb}GB"
echo "Available memory:        ${avail_mem_gb}GB"
echo

# Sizing recommendations based on workload
echo "Recommended configurations by workload type:"
echo

# OLTP workload
oltp_sga=$((total_mem_gb * 60 / 100))
oltp_pga=$((total_mem_gb * 15 / 100))
echo "OLTP (transaction processing):"
echo "  SGA: ${oltp_sga}G (60% of total)"
echo "  PGA: ${oltp_pga}G (15% of total)"
echo "  Remaining for OS/other: $((total_mem_gb - oltp_sga - oltp_pga))G"
echo

# DW workload
dw_sga=$((total_mem_gb * 40 / 100))
dw_pga=$((total_mem_gb * 35 / 100))
echo "DW (data warehouse):"
echo "  SGA: ${dw_sga}G (40% of total)"
echo "  PGA: ${dw_pga}G (35% of total)"
echo "  Remaining for OS/other: $((total_mem_gb - dw_sga - dw_pga))G"
echo

# Mixed workload (what oracle_config_calc_memory uses)
read -r auto_sga auto_pga < <(oracle_config_calc_memory)
echo "Mixed (oracle_config_calc_memory default):"
echo "  SGA: ${auto_sga} (45% of available)"
echo "  PGA: ${auto_pga} (20% of available)"
echo

#===============================================================================
# SUMMARY
#===============================================================================

runtime_print_section "Memory Sizing Summary"

runtime_print_vars "System Resources" \
    "Total Memory=${total_mem_gb}GB" \
    "Available Memory=${avail_mem_gb}GB"

runtime_print_vars "Auto-Calculated (Mixed)" \
    "SGA=${auto_sga}" \
    "PGA=${auto_pga}"

log "Example complete!"
