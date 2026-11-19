-- Gym Membership & Revenue Analytics System
-- PDM-018 validation: exact first procedure-batch inventory and metadata
-- Prerequisite: run 00_create_schema.sql through
-- 05_create_membership_check_in_procedures.sql first.

USE gym_membership_analytics;

DROP TEMPORARY TABLE IF EXISTS tmp_expected_pdm018_procedure;

CREATE TEMPORARY TABLE tmp_expected_pdm018_procedure (
    procedure_name VARCHAR(64) NOT NULL,
    expected_parameter_count SMALLINT UNSIGNED NOT NULL,
    expected_in_parameter_count SMALLINT UNSIGNED NOT NULL,
    expected_out_parameter_count SMALLINT UNSIGNED NOT NULL,
    CONSTRAINT pk_tmp_expected_pdm018_procedure PRIMARY KEY (procedure_name)
);

INSERT INTO tmp_expected_pdm018_procedure (
    procedure_name,
    expected_parameter_count,
    expected_in_parameter_count,
    expected_out_parameter_count
)
VALUES
    ('sp_create_membership_plan_version', 7, 6, 1),
    ('sp_assign_member_home_branch', 5, 4, 1),
    ('sp_create_membership_contract', 12, 11, 1),
    ('sp_record_cancellation_adjustments', 2, 2, 0),
    ('sp_submit_membership_status_event', 8, 7, 1),
    ('sp_decide_membership_status_event', 4, 3, 1),
    ('sp_ingest_check_in', 6, 5, 1),
    ('sp_resolve_check_in_quality_issue', 7, 7, 0);

-- Expected result: PASS with eight implemented procedures.
SELECT
    'PDM018_EXACT_PROCEDURE_COUNT' AS validation_control,
    8 AS expected_result,
    COUNT(routine.routine_name) AS actual_result,
    CASE WHEN COUNT(routine.routine_name) = 8 THEN 'PASS' ELSE 'FAIL' END
        AS validation_result
FROM tmp_expected_pdm018_procedure AS expected
LEFT JOIN information_schema.routines AS routine
    ON routine.routine_schema = DATABASE()
   AND routine.routine_type = 'PROCEDURE'
   AND routine.routine_name = expected.procedure_name;

-- Expected result: zero rows. Any row is a missing approved PDM-018 procedure.
SELECT
    expected.procedure_name AS missing_procedure_name
FROM tmp_expected_pdm018_procedure AS expected
LEFT JOIN information_schema.routines AS routine
    ON routine.routine_schema = DATABASE()
   AND routine.routine_type = 'PROCEDURE'
   AND routine.routine_name = expected.procedure_name
WHERE routine.routine_name IS NULL
ORDER BY expected.procedure_name;

-- Expected result: zero rows immediately after the PDM-018 execution step.
SELECT
    routine.routine_name AS unexpected_procedure_name
FROM information_schema.routines AS routine
LEFT JOIN tmp_expected_pdm018_procedure AS expected
    ON expected.procedure_name = routine.routine_name
WHERE routine.routine_schema = DATABASE()
  AND routine.routine_type = 'PROCEDURE'
  AND routine.routine_name REGEXP '^sp_'
  AND expected.procedure_name IS NULL
ORDER BY routine.routine_name;

-- Expected result: eight PASS rows with exact total, IN, and OUT counts.
SELECT
    expected.procedure_name,
    expected.expected_parameter_count,
    COUNT(parameter.parameter_name) AS actual_parameter_count,
    expected.expected_in_parameter_count,
    SUM(parameter.parameter_mode = 'IN') AS actual_in_parameter_count,
    expected.expected_out_parameter_count,
    SUM(parameter.parameter_mode = 'OUT') AS actual_out_parameter_count,
    CASE
        WHEN COUNT(parameter.parameter_name) = expected.expected_parameter_count
         AND SUM(parameter.parameter_mode = 'IN')
                = expected.expected_in_parameter_count
         AND SUM(parameter.parameter_mode = 'OUT')
                = expected.expected_out_parameter_count
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM tmp_expected_pdm018_procedure AS expected
LEFT JOIN information_schema.parameters AS parameter
    ON parameter.specific_schema = DATABASE()
   AND parameter.specific_name = expected.procedure_name
GROUP BY
    expected.procedure_name,
    expected.expected_parameter_count,
    expected.expected_in_parameter_count,
    expected.expected_out_parameter_count
ORDER BY expected.procedure_name;

-- Expected result: PASS. Every controlled procedure executes with definer rights.
SELECT
    'PDM018_SQL_SECURITY_DEFINER' AS validation_control,
    8 AS expected_result,
    SUM(routine.security_type = 'DEFINER') AS actual_result,
    CASE WHEN SUM(routine.security_type = 'DEFINER') = 8 THEN 'PASS' ELSE 'FAIL' END
        AS validation_result
FROM information_schema.routines AS routine
JOIN tmp_expected_pdm018_procedure AS expected
    ON expected.procedure_name = routine.routine_name
WHERE routine.routine_schema = DATABASE()
  AND routine.routine_type = 'PROCEDURE';

-- Expected result: PASS. Named Beirut conversion is required by Check-In procedures.
SELECT
    'PDM018_BEIRUT_TIME_ZONE_SUPPORT' AS validation_control,
    'NONNULL' AS expected_result,
    CASE
        WHEN CONVERT_TZ(TIMESTAMP('2026-01-01 00:00:00'), '+00:00', 'Asia/Beirut')
             IS NULL
        THEN 'NULL' ELSE 'NONNULL'
    END AS actual_result,
    CASE
        WHEN CONVERT_TZ(TIMESTAMP('2026-01-01 00:00:00'), '+00:00', 'Asia/Beirut')
             IS NOT NULL
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result;

DROP TEMPORARY TABLE tmp_expected_pdm018_procedure;
