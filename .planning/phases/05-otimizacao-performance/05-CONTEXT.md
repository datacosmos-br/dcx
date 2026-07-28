# Phase 05: Otimização de Performance - Context

**Gathered:** 2026-02-02
**Status:** In Progress

<domain>
## Phase Boundary
Actual performance optimizations for Data Pump operations:
- Size-based categorization of tables.
- Parallelism tuned by category.
- Elimination of 0-row table queries.
</domain>

<decisions>
## Implementation Decisions
- Query DBA_SEGMENTS for segment size.
- Group tables: Small (<100MB), Medium (100MB-1GB), Large (>1GB).
- Process small tables in a single batch, large tables individually.
- Use `QUERY=WHERE 1=0` pattern for empty tables if requested.
</decisions>
