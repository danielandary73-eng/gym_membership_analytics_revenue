-- Gym Membership & Revenue Analytics System
-- PDM-019 validation: cumulative exact procedure inventory and metadata
-- Prerequisite: run 00_create_schema.sql through 06_create_payment_procedures.sql first.

USE gym_membership_analytics;

DROP TEMPORARY TABLE IF EXISTS tmp_expected_pdm019_procedure;

CREATE TEMPORARY TABLE tmp_expected_pdm019_procedure (
    procedure_name VARCHAR(64) NOT NULL,
    implementation_batch VARCHAR(10) NOT NULL,
    expected_parameter_count SMALLINT UNSIGNED NOT NULL,
    expected_in_parameter_count SMALLINT UNSIGNED NOT NULL,
    expected_out_parameter_count SMALLINT UNSIGNED NOT NULL,
    CONSTRAINT pk_tmp_expected_pdm019_procedure PRIMARY KEY (procedure_name)
);

INSERT INTO tmp_expected_pdm019_procedure (
    procedure_name,
    implementation_batch,
    expected_parameter_count,
    expected_in_parameter_count,
    expected_out_parameter_count
)
VALUES
    ('sp_create_membership_plan_version', 'PDM-018', 7, 6, 1),
    ('sp_assign_member_home_branch', 'PDM-018', 5, 4, 1),
    ('sp_create_membership_contract', 'PDM-018', 12, 11, 1),
    ('sp_record_cancellation_adjustments', 'PDM-018', 2, 2, 0),
    ('sp_submit_membership_status_event', 'PDM-018', 8, 7, 1),
    ('sp_decide_membership_status_event', 'PDM-018', 4, 3, 1),
    ('sp_ingest_check_in', 'PDM-018', 6, 5, 1),
    ('sp_resolve_check_in_quality_issue', 'PDM-018', 7, 7, 0),
    ('sp_create_payment', 'PDM-019', 6, 5, 1),
    ('sp_record_payment_attempt', 'PDM-019', 7, 6, 1),
    ('sp_transition_payment_attempt', 'PDM-019', 5, 4, 1),
    ('sp_allocate_successful_payment', 'PDM-019', 4, 3, 1);

-- Expected result: PASS with twelve implemented procedures.
SELECT
    'PDM019_CUMULATIVE_PROCEDURE_COUNT' AS validation_control,
    12 AS expected_result,
    COUNT(routine.routine_name) AS actual_result,
    CASE WHEN COUNT(routine.routine_name) = 12 THEN 'PASS' ELSE 'FAIL' END
        AS validation_result
FROM tmp_expected_pdm019_procedure AS expected
LEFT JOIN information_schema.routines AS routine
    ON routine.routine_schema = DATABASE()
   AND routine.routine_type = 'PROCEDURE'
   AND routine.routine_name = expected.procedure_name;

-- Expected result: PASS with four PDM-019 procedures.
SELECT
    'PDM019_BATCH_PROCEDURE_COUNT' AS validation_control,
    4 AS expected_result,
    COUNT(routine.routine_name) AS actual_result,
    CASE WHEN COUNT(routine.routine_name) = 4 THEN 'PASS' ELSE 'FAIL' END
        AS validation_result
FROM tmp_expected_pdm019_procedure AS expected
LEFT JOIN information_schema.routines AS routine
    ON routine.routine_schema = DATABASE()
   AND routine.routine_type = 'PROCEDURE'
   AND routine.routine_name = expected.procedure_name
WHERE expected.implementation_batch = 'PDM-019';

-- Expected result: zero rows. Any row is a missing approved procedure.
SELECT
    expected.implementation_batch,
    expected.procedure_name AS missing_procedure_name
FROM tmp_expected_pdm019_procedure AS expected
LEFT JOIN information_schema.routines AS routine
    ON routine.routine_schema = DATABASE()
   AND routine.routine_type = 'PROCEDURE'
   AND routine.routine_name = expected.procedure_name
WHERE routine.routine_name IS NULL
ORDER BY expected.implementation_batch, expected.procedure_name;

-- Expected result: zero rows immediately after the PDM-019 execution step.
SELECT
    routine.routine_name AS unexpected_procedure_name
FROM information_schema.routines AS routine
LEFT JOIN tmp_expected_pdm019_procedure AS expected
    ON expected.procedure_name = routine.routine_name
WHERE routine.routine_schema = DATABASE()
  AND routine.routine_type = 'PROCEDURE'
  AND routine.routine_name REGEXP '^sp_'
  AND expected.procedure_name IS NULL
ORDER BY routine.routine_name;

-- Expected result: twelve PASS rows with exact total, IN, and OUT counts.
SELECT
    expected.implementation_batch,
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
FROM tmp_expected_pdm019_procedure AS expected
LEFT JOIN information_schema.parameters AS parameter
    ON parameter.specific_schema = DATABASE()
   AND parameter.specific_name = expected.procedure_name
GROUP BY
    expected.implementation_batch,
    expected.procedure_name,
    expected.expected_parameter_count,
    expected.expected_in_parameter_count,
    expected.expected_out_parameter_count
ORDER BY expected.implementation_batch, expected.procedure_name;

-- Expected result: PASS. Every controlled procedure executes with definer rights.
SELECT
    'PDM019_SQL_SECURITY_DEFINER' AS validation_control,
    12 AS expected_result,
    SUM(routine.security_type = 'DEFINER') AS actual_result,
    CASE WHEN SUM(routine.security_type = 'DEFINER') = 12 THEN 'PASS' ELSE 'FAIL' END
        AS validation_result
FROM information_schema.routines AS routine
JOIN tmp_expected_pdm019_procedure AS expected
    ON expected.procedure_name = routine.routine_name
WHERE routine.routine_schema = DATABASE()
  AND routine.routine_type = 'PROCEDURE';

-- Expected result: PASS. The corrected view must reject direct Pending-to-Settled paths.
SELECT
    'PDM019_PENDING_TO_SETTLED_VALIDATOR_CORRECTION' AS validation_control,
    'ABSENT' AS expected_result,
    CASE
        WHEN LOWER(view_definition) REGEXP
             'pending[^)]*successful[^)]*settled[^)]*failed[^)]*cancelled'
        THEN 'PRESENT'
        ELSE 'ABSENT'
    END AS actual_result,
    CASE
        WHEN LOWER(view_definition) REGEXP
             'pending[^)]*successful[^)]*settled[^)]*failed[^)]*cancelled'
        THEN 'FAIL'
        ELSE 'PASS'
    END AS validation_result
FROM information_schema.views
WHERE table_schema = DATABASE()
  AND table_name = 'vw_dq_payment_attempt_integrity';

DROP TEMPORARY TABLE tmp_expected_pdm019_procedure;
