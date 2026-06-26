-- monitor_restore.sql
-- Monitoramento de progresso do RMAN Restore (funciona em MOUNTED)
SET LINESIZE 200
SET PAGESIZE 1000
SET FEEDBACK OFF
SET HEADING ON
SET VERIFY OFF
SET TRIMSPOOL ON
SET TAB OFF

PROMPT
PROMPT ================================================================================
PROMPT                         RMAN RESTORE PROGRESS MONITOR
PROMPT ================================================================================

COL ts FORMAT A20
COL db FORMAT A10
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') AS ts, status AS db FROM v$instance;

PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT   DATAFILES STATUS
PROMPT --------------------------------------------------------------------------------

COL file# FORMAT 9999
COL datafile FORMAT A60
COL st FORMAT A10
COL progress FORMAT A20

SELECT * FROM (
    SELECT
        TO_NUMBER(REGEXP_SUBSTR(sl.target, '[0-9]+')) AS file#,
        df.name AS datafile,
        'RESTORING' AS st,
        LPAD(TO_CHAR(ROUND(sl.sofar / 1024 / 1024 / 1024, 2), 'FM9990.00'), 7) || ' / ' ||
        LPAD(TO_CHAR(ROUND(sl.totalwork / 1024 / 1024 / 1024, 2), 'FM9990.00'), 7) || ' GB' AS progress,
        1 AS ord
    FROM v$session_longops sl
    JOIN v$datafile df ON df.file# = TO_NUMBER(REGEXP_SUBSTR(sl.target, '[0-9]+'))
    WHERE sl.opname LIKE 'RMAN%'
      AND sl.sofar < sl.totalwork
      AND sl.totalwork > 0
    UNION ALL
    SELECT
        TO_NUMBER(REGEXP_SUBSTR(sl.target, '[0-9]+')) AS file#,
        df.name AS datafile,
        'DONE' AS st,
        LPAD(TO_CHAR(ROUND(sl.totalwork / 1024 / 1024 / 1024, 2), 'FM9990.00'), 7) || ' / ' ||
        LPAD(TO_CHAR(ROUND(sl.totalwork / 1024 / 1024 / 1024, 2), 'FM9990.00'), 7) || ' GB' AS progress,
        3 AS ord
    FROM v$session_longops sl
    JOIN v$datafile df ON df.file# = TO_NUMBER(REGEXP_SUBSTR(sl.target, '[0-9]+'))
    WHERE sl.opname LIKE 'RMAN%'
      AND sl.sofar >= sl.totalwork
      AND sl.totalwork > 0
      AND sl.start_time > SYSDATE - 1
      AND TO_NUMBER(REGEXP_SUBSTR(sl.target, '[0-9]+')) NOT IN (
          SELECT TO_NUMBER(REGEXP_SUBSTR(target, '[0-9]+'))
          FROM v$session_longops
          WHERE opname LIKE 'RMAN%' AND sofar < totalwork AND totalwork > 0
      )
    UNION ALL
    SELECT
        df.file# AS file#,
        df.name AS datafile,
        'PENDING' AS st,
        '   -    /    -    GB' AS progress,
        2 AS ord
    FROM v$datafile df
    WHERE df.file# NOT IN (
        SELECT DISTINCT TO_NUMBER(REGEXP_SUBSTR(target, '[0-9]+'))
        FROM v$session_longops
        WHERE opname LIKE 'RMAN%' AND totalwork > 0 AND start_time > SYSDATE - 1
    )
)
ORDER BY ord, file#;

PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT   ACTIVE CHANNELS
PROMPT --------------------------------------------------------------------------------

COL sid FORMAT 9999
COL operation FORMAT A25
COL target FORMAT A8
COL pct FORMAT 999.9
COL elapsed FORMAT A10
COL eta FORMAT A10
COL mbps FORMAT 999.9

SELECT sid, opname AS operation, SUBSTR(target, 1, 8) AS target,
    ROUND(sofar * 100 / NULLIF(totalwork, 0), 1) AS pct,
    LPAD(FLOOR(elapsed_seconds / 3600), 2, '0') || ':' ||
        LPAD(MOD(FLOOR(elapsed_seconds / 60), 60), 2, '0') || ':' ||
        LPAD(MOD(elapsed_seconds, 60), 2, '0') AS elapsed,
    CASE WHEN time_remaining > 0 THEN
        LPAD(FLOOR(time_remaining / 3600), 2, '0') || ':' ||
        LPAD(MOD(FLOOR(time_remaining / 60), 60), 2, '0') || ':' ||
        LPAD(MOD(time_remaining, 60), 2, '0')
    ELSE '-' END AS eta,
    ROUND(sofar / 1024 / 1024 / NULLIF(elapsed_seconds, 0), 1) AS mbps
FROM v$session_longops
WHERE opname LIKE 'RMAN%' AND sofar < totalwork AND totalwork > 0
ORDER BY start_time;

PROMPT
PROMPT --------------------------------------------------------------------------------
PROMPT   TOTALS
PROMPT --------------------------------------------------------------------------------

COL status FORMAT A12
COL cnt FORMAT 999
COL done_gb FORMAT 9,999.99
COL total_gb FORMAT 9,999.99

SELECT 'RESTORING' AS status, COUNT(*) AS cnt,
    ROUND(SUM(sofar) / 1024 / 1024 / 1024, 2) AS done_gb,
    ROUND(SUM(totalwork) / 1024 / 1024 / 1024, 2) AS total_gb
FROM v$session_longops
WHERE opname LIKE 'RMAN%' AND sofar < totalwork AND totalwork > 0
UNION ALL
SELECT 'DONE' AS status, COUNT(*) AS cnt,
    ROUND(SUM(totalwork) / 1024 / 1024 / 1024, 2) AS done_gb,
    ROUND(SUM(totalwork) / 1024 / 1024 / 1024, 2) AS total_gb
FROM v$session_longops
WHERE opname LIKE 'RMAN%' AND sofar >= totalwork AND totalwork > 0 AND start_time > SYSDATE - 1
UNION ALL
SELECT 'PENDING' AS status,
    (SELECT COUNT(*) FROM v$datafile) -
    (SELECT COUNT(DISTINCT TO_NUMBER(REGEXP_SUBSTR(target, '[0-9]+')))
     FROM v$session_longops WHERE opname LIKE 'RMAN%' AND totalwork > 0 AND start_time > SYSDATE - 1) AS cnt,
    0 AS done_gb, 0 AS total_gb
FROM dual;

PROMPT
PROMPT ================================================================================
EXIT;
