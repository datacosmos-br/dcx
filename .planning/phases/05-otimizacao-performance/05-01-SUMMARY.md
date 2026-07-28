---
phase: 05-otimizacao-performance
plan: 01
subsystem: data-pump-operations
tags: [performance, optimization, oracle, data-pump]

requires:
  - phase: 05
    provides: [oracle-datapump-optimization]

provides:
  - table-categorization
  - size-based-optimization
  - ants-and-elephants-strategy

affected_files:
  - dcx-oracle/lib/oracle_datapump.sh
  - dcx-oracle/tests/test_oracle_datapump_opt.sh

decisions:
  - title: "Categorization Strategy"
    rationale: "Group small tables (<100MB) into batches to reduce Data Pump startup overhead. Process large tables (>1GB) individually."
    chosen: "Ants (<100MB) vs Elephants (>1GB)"

metrics:
  duration: "15 minutes"
  completed: 2026-02-02
---

# Phase [5] Plan [1]: Data Pump Optimization Summary

**One-liner:** Implemented table categorization by size (Ants vs Elephants) for Data Pump optimization.

## What Was Built

### Core Logic
1. **`dp_get_table_sizes`**: Queries `DBA_SEGMENTS` to get table sizes.
2. **`dp_categorize_tables`**: Categorizes tables into "Ants" (small) and "Elephants" (large/medium).
3. **`dp_execute_batch_optimized`**: Orchestrates the export using these categories (stubbed logic for now, utilizing parallel batch execution).

### Verification
- Created unit tests `dcx-oracle/tests/test_oracle_datapump_opt.sh`.
- Verified categorization logic with mock data.
- Verified custom threshold support.

## Next Steps
- Implement the actual execution logic that splits the "Ants" into a single parfile and "Elephants" into individual parfiles. (This was stubbed in `dp_execute_batch_optimized`).
