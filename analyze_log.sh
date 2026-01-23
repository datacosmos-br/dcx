#!/usr/bin/env bash
# shellcheck shell=bash
################################################################################
# analyze_log.sh - Analisa logs de import e gera relatório detalhado
################################################################################

set -euo pipefail

analyze_import_log() {
    local log_file="${1?ERROR: analyze_import_log requires log_file}"
    local parfile_name="${2?ERROR: analyze_import_log requires parfile_name}"

    if [ ! -f "${log_file}" ]; then
        echo "ERROR|${parfile_name}|Log não encontrado"
        return 1
    fi

    # Extrai informações do log
    local start_time end_time duration errors_count
    start_time=$(grep -m1 "Import: Release" "${log_file}" | awk '{print $NF}' || echo "N/A")
    end_time=$(grep "Job.*completed" "${log_file}" | awk '{print $NF}' || echo "N/A")
    duration=$(grep "elapsed" "${log_file}" | grep -oP 'elapsed \K[^\s]+' || echo "N/A")
    errors_count=$(grep "completed with.*error" "${log_file}" | grep -oP '\d+ error' | grep -oP '\d+' || echo "0")

    # Tabelas com falha ORA-31693 (definition changed)
    local failed_tables_def
    failed_tables_def=$(grep "ORA-31693" "${log_file}" | grep -oP 'Table data object "\w+"\."[^"]+' | sed 's/Table data object "//' | tr '\n' '|' || echo "")

    # Tabelas com falha ORA-39166 (not found)
    local failed_tables_notfound
    failed_tables_notfound=$(grep "ORA-39166" "${log_file}" | grep -oP 'Object \w+\.[^\s]+' | sed 's/Object //' | tr '\n' '|' || echo "")

    # Tabelas importadas com sucesso
    local success_tables success_count
    success_tables=$(grep "imported.*rows" "${log_file}" | grep -oP '"\w+"\."[^"]+"\s+\d+ rows' || echo "")
    success_count=$(echo "${success_tables}" | grep -c "rows" || echo "0")

    # Grants com falha
    local failed_grants failed_grants_count
    failed_grants=$(grep "ORA-39083.*OBJECT_GRANT" "${log_file}" | grep -oP "ORA-01917.*" || echo "")
    failed_grants_count=$(echo "${failed_grants}" | grep -c "ORA-01917" || echo "0")

    # Status geral
    if grep -q "completed with.*error" "${log_file}"; then
        local status="ERRORS"
    elif grep -q "successfully completed" "${log_file}"; then
        local status="SUCCESS"
    else
        local status="UNKNOWN"
    fi

    # Output em formato estruturado
    echo "STATUS|${status}"
    echo "PARFILE|${parfile_name}"
    echo "START_TIME|${start_time}"
    echo "END_TIME|${end_time}"
    echo "DURATION|${duration}"
    echo "ERROR_COUNT|${errors_count}"
    echo "SUCCESS_TABLES_COUNT|${success_count}"
    echo "FAILED_GRANTS_COUNT|${failed_grants_count}"
    echo "FAILED_DEF_CHANGE|${failed_tables_def}"
    echo "FAILED_NOT_FOUND|${failed_tables_notfound}"
    echo "SUCCESS_TABLES|${success_tables}"
}

analyze_import_log "$@"
