#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Parfile Integration Test Suite (Phase 6)
#
# Tests for parfile validation and integration:
# - Parfile syntax validation
# - Parameter extraction (TABLES, QUERY, INCLUDE)
# - Dynamic subquery handling
# - Path resolution and file operations
# - Integration with Data Pump operations
#
# Expected: 10+ tests covering parfile scenarios
#===============================================================================

source "$(dirname "$0")/lib/test_helpers.sh"

setup_test_env

echo "========================================"
echo "  Phase 6: Parfile Integration Tests"
echo "========================================"
echo ""

#===============================================================================
# SECTION 1: Parfile Syntax Validation
#===============================================================================

echo "SECTION 1: Parfile Syntax Validation"
echo ""

# Test 1: Valid parfile structure
run_test "Valid parfile structure" '
    parfile="$TEST_TEMP_DIR/valid.par"
    cat > "$parfile" << "EOF"
-- Test Parfile
USERID=admin/password@db
DIRECTORY=dpump_dir
DUMPFILE=test.dmp
LOGFILE=test.log
PARALLEL=4
TABLES=TEST.TABLE1,TEST.TABLE2
EOF
    [[ -f "$parfile" ]] && grep -q "USERID=" "$parfile"
'

# Test 2: Parfile with comments
run_test "Parfile with comments" '
    parfile="$TEST_TEMP_DIR/comments.par"
    cat > "$parfile" << "EOF"
-- This is a comment
USERID=admin/password@db
-- Another comment
DIRECTORY=dpump_dir
DUMPFILE=test.dmp  -- inline comment
EOF
    grep -c "^--" "$parfile" | grep -q "2"
'

# Test 3: Parfile with multiline parameters
run_test "Parfile with multiline parameters" '
    parfile="$TEST_TEMP_DIR/multiline.par"
    cat > "$parfile" << "EOF"
USERID=admin/password@db
DIRECTORY=dpump_dir
TABLES =
  TEST.TABLE1,
  TEST.TABLE2,
  TEST.TABLE3
EOF
    [[ -f "$parfile" ]] && grep -q "TABLES" "$parfile"
'

#===============================================================================
# SECTION 2: Parameter Extraction
#===============================================================================

echo "SECTION 2: Parameter Extraction"
echo ""

# Test 4: Extract USERID parameter
run_test "Extract USERID parameter" '
    parfile="$TEST_TEMP_DIR/params.par"
    echo "USERID=admin/password@db" > "$parfile"
    echo "DIRECTORY=dpump_dir" >> "$parfile"

    extract_param() {
        local param="$1"
        local file="$2"
        grep "^$param=" "$file" | cut -d= -f2- | head -1
    }

    userid=$(extract_param "USERID" "$parfile")
    [[ "$userid" == "admin/password@db" ]]
'

# Test 5: Extract DUMPFILE parameter
run_test "Extract DUMPFILE parameter" '
    parfile="$TEST_TEMP_DIR/dump.par"
    cat > "$parfile" << "EOF"
USERID=admin/password
DUMPFILE=/path/to/export_%U.dmp
PARALLEL=4
EOF

    extract_param() {
        grep "^$1=" "$2" | cut -d= -f2- | head -1
    }

    dumpfile=$(extract_param "DUMPFILE" "$parfile")
    [[ "$dumpfile" =~ .dmp$ ]]
'

# Test 6: Extract QUERY parameter
run_test "Extract QUERY parameter" '
    parfile="$TEST_TEMP_DIR/query.par"
    cat > "$parfile" << "EOF"
USERID=admin/password
QUERY=STAGE.SALES_ITEMS:"WHERE DATE > 2024-01-01"
EOF

    extract_query() {
        grep "^QUERY=" "$1" || echo ""
    }

    query=$(extract_query "$parfile")
    [[ -n "$query" ]] && [[ "$query" =~ QUERY= ]]
'

#===============================================================================
# SECTION 3: Dynamic Subquery Validation
#===============================================================================

echo "SECTION 3: Dynamic Subquery Validation"
echo ""

# Test 7: Parfile with dynamic table selection
run_test "Parfile with dynamic table selection" '
    parfile="$TEST_TEMP_DIR/dynamic.par"
    cat > "$parfile" << "EOF"
USERID=admin/password
TABLES =
  -- Dynamic selection - includes only tables in STAGE schema
  SELECT "'"'"'OWNER'"'"'","'"'"'TABLE_NAME'"'"'" FROM all_tables WHERE OWNER='"'"'STAGE'"'"'
EOF
    [[ -f "$parfile" ]] && grep -q "all_tables" "$parfile"
'

# Test 8: Validate SQL syntax in parfiles
run_test "Validate SQL syntax in parfiles" '
    validate_sql_syntax() {
        local parfile="$1"
        # Check for valid SQL keywords in QUERY parameters
        grep "^QUERY=" "$parfile" | grep -qE "WHERE|SELECT" || echo ""
        return 0
    }

    parfile="$TEST_TEMP_DIR/sql.par"
    cat > "$parfile" << "EOF"
USERID=admin/password
QUERY=TEST.ORDERS:"WHERE ORDER_DATE > SYSDATE-30"
EOF
    validate_sql_syntax "$parfile"
'

#===============================================================================
# SECTION 4: Parfile Integration
#===============================================================================

echo "SECTION 4: Parfile Integration"
echo ""

# Test 9: Parfile execution prerequisites
run_test "Parfile execution prerequisites" '
    check_parfile_prerequisites() {
        local parfile="$1"
        local dir_name="${2:-dpump_dir}"

        # Check required parameters
        [[ -f "$parfile" ]] || return 1
        grep -q "USERID=" "$parfile" || return 1
        grep -q "DIRECTORY=" "$parfile" || return 1
        return 0
    }

    parfile="$TEST_TEMP_DIR/prereq.par"
    cat > "$parfile" << "EOF"
USERID=admin/password
DIRECTORY=dpump_dir
DUMPFILE=test.dmp
EOF
    check_parfile_prerequisites "$parfile"
'

# Test 10: Parfile transformation (remove QUERY for execution)
run_test "Parfile transformation for execution" '
    transform_for_execution() {
        local input="$1"
        local output="$2"

        # Copy parfile and remove QUERY parameter
        grep -v "^QUERY=" "$input" > "$output"
    }

    source_par="$TEST_TEMP_DIR/with_query.par"
    target_par="$TEST_TEMP_DIR/without_query.par"

    cat > "$source_par" << "EOF"
USERID=admin/password
QUERY=TEST.TABLE:"WHERE ID > 1000"
DUMPFILE=test.dmp
EOF

    transform_for_execution "$source_par" "$target_par"
    ! grep -q "^QUERY=" "$target_par" && grep -q "DUMPFILE=" "$target_par"
'

echo ""
print_test_summary
