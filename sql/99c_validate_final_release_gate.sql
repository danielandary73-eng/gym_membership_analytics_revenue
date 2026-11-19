-- Gym Membership & Revenue Analytics System
-- SQLA-003C: lightweight final release gate
--
-- Purpose:
--   Confirm that the approved analytical layer is deployed, populated, indexed,
--   and protected by the approved read-only access boundaries.
--
-- Prerequisites already completed and approved:
--   98_validate_synthetic_dataset.sql
--   21_create_analysis_views.sql
--   23_build_analysis_mart.sql
--   24_build_obligation_activity_mart.sql
--   22_extend_analysis_grants.sql
--   97_validate_roles_grants.sql
--
-- This is the normal final gate. It deliberately avoids re-expanding the large
-- reporting views that trigger MySQL 8.0 on Windows internal #sql table errors.

USE gym_membership_analytics;

DROP TEMPORARY TABLE IF EXISTS tmp_sqla003_final_release_gate;

CREATE TEMPORARY TABLE tmp_sqla003_final_release_gate (
    control_sequence TINYINT UNSIGNED NOT NULL,
    validation_control VARCHAR(64) NOT NULL,
    expected_result VARCHAR(64) NOT NULL,
    actual_result VARCHAR(64) NOT NULL,
    validation_result VARCHAR(4) NOT NULL,
    PRIMARY KEY (control_sequence)
) ENGINE = InnoDB;

-- 1. Exact public analytical-view inventory.
INSERT INTO tmp_sqla003_final_release_gate
SELECT
    1,
    'SQLA003_ANALYSIS_VIEW_COUNT',
    '10',
    CAST(COUNT(*) AS CHAR),
    CASE WHEN COUNT(*) = 10 THEN 'PASS' ELSE 'FAIL' END
FROM information_schema.views
WHERE table_schema = DATABASE()
  AND table_name LIKE 'vw\\_analysis\\_%';

-- 2. Exact internal analytical-mart inventory.
INSERT INTO tmp_sqla003_final_release_gate
SELECT
    2,
    'SQLA003_MART_TABLE_COUNT',
    '3',
    CAST(COUNT(*) AS CHAR),
    CASE WHEN COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_type = 'BASE TABLE'
  AND table_name IN (
      'mart_analysis_membership_contract',
      'mart_analysis_membership_daily_snapshot',
      'mart_analysis_obligation_activity'
  );

-- 3. Every mart has its enforced primary-key grain.
INSERT INTO tmp_sqla003_final_release_gate
SELECT
    3,
    'SQLA003_MART_PRIMARY_KEYS',
    '3',
    CAST(COUNT(*) AS CHAR),
    CASE WHEN COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END
FROM information_schema.table_constraints
WHERE constraint_schema = DATABASE()
  AND constraint_type = 'PRIMARY KEY'
  AND table_name IN (
      'mart_analysis_membership_contract',
      'mart_analysis_membership_daily_snapshot',
      'mart_analysis_obligation_activity'
  );

-- 4-6. Fast population checks against the materialized marts only.
INSERT INTO tmp_sqla003_final_release_gate
SELECT
    4,
    'SQLA003_CONTRACT_MART_POPULATED',
    'POPULATED',
    CASE WHEN EXISTS (
        SELECT 1 FROM mart_analysis_membership_contract LIMIT 1
    ) THEN 'POPULATED' ELSE 'EMPTY' END,
    CASE WHEN EXISTS (
        SELECT 1 FROM mart_analysis_membership_contract LIMIT 1
    ) THEN 'PASS' ELSE 'FAIL' END;

INSERT INTO tmp_sqla003_final_release_gate
SELECT
    5,
    'SQLA003_DAILY_SNAPSHOT_MART_POPULATED',
    'POPULATED',
    CASE WHEN EXISTS (
        SELECT 1 FROM mart_analysis_membership_daily_snapshot LIMIT 1
    ) THEN 'POPULATED' ELSE 'EMPTY' END,
    CASE WHEN EXISTS (
        SELECT 1 FROM mart_analysis_membership_daily_snapshot LIMIT 1
    ) THEN 'PASS' ELSE 'FAIL' END;

INSERT INTO tmp_sqla003_final_release_gate
SELECT
    6,
    'SQLA003_OBLIGATION_MART_POPULATED',
    'POPULATED',
    CASE WHEN EXISTS (
        SELECT 1 FROM mart_analysis_obligation_activity LIMIT 1
    ) THEN 'POPULATED' ELSE 'EMPTY' END,
    CASE WHEN EXISTS (
        SELECT 1 FROM mart_analysis_obligation_activity LIMIT 1
    ) THEN 'PASS' ELSE 'FAIL' END;

-- 7. Power BI analyst remains curated-view-only.
INSERT INTO tmp_sqla003_final_release_gate
SELECT
    7,
    'SQLA003_ANALYST_SELECT_BOUNDARY',
    '19 VIEWS / 0 TABLES',
    CONCAT(
        COALESCE(SUM(object_catalog.table_type = 'VIEW'), 0),
        ' VIEWS / ',
        COALESCE(SUM(object_catalog.table_type = 'BASE TABLE'), 0),
        ' TABLES'
    ),
    CASE
        WHEN COALESCE(SUM(object_catalog.table_type = 'VIEW'), 0) = 19
         AND COALESCE(SUM(object_catalog.table_type = 'BASE TABLE'), 0) = 0
        THEN 'PASS' ELSE 'FAIL'
    END
FROM information_schema.table_privileges AS privilege
JOIN information_schema.tables AS object_catalog
  ON object_catalog.table_schema = privilege.table_schema
 AND object_catalog.table_name = privilege.table_name
WHERE privilege.grantee = '''gym_analyst_powerbi''@''%'''
  AND privilege.table_schema = DATABASE()
  AND privilege.privilege_type = 'SELECT';

-- 8. Audit reviewer retains complete read-only object coverage.
INSERT INTO tmp_sqla003_final_release_gate
SELECT
    8,
    'SQLA003_AUDIT_SELECT_BOUNDARY',
    '59',
    CAST(COUNT(*) AS CHAR),
    CASE WHEN COUNT(*) = 59 THEN 'PASS' ELSE 'FAIL' END
FROM information_schema.table_privileges
WHERE grantee = '''gym_audit_reviewer''@''%'''
  AND table_schema = DATABASE()
  AND privilege_type = 'SELECT';

-- Detailed evidence: eight PASS rows.
SELECT
    control_sequence,
    validation_control,
    expected_result,
    actual_result,
    validation_result
FROM tmp_sqla003_final_release_gate
ORDER BY control_sequence;

-- Final project decision: one READY row.
SELECT
    'SQLA003_FINAL_RELEASE_GATE' AS release_control,
    COUNT(*) AS control_count,
    SUM(validation_result = 'PASS') AS passed_control_count,
    SUM(validation_result = 'FAIL') AS failed_control_count,
    CASE
        WHEN COUNT(*) = 8
         AND SUM(validation_result = 'FAIL') = 0
        THEN 'READY'
        ELSE 'NOT_READY'
    END AS release_status
FROM tmp_sqla003_final_release_gate;

DROP TEMPORARY TABLE tmp_sqla003_final_release_gate;
