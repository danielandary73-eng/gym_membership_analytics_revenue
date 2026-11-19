-- Gym Membership & Revenue Analytics System
-- PDM-017 validation: exact view inventory, classification, execution, and release gate
-- Prerequisite: run 00_create_schema.sql through 04_create_views.sql first.

USE gym_membership_analytics;

DROP TEMPORARY TABLE IF EXISTS tmp_expected_pdm017_view;

CREATE TEMPORARY TABLE tmp_expected_pdm017_view (
    view_name VARCHAR(64) NOT NULL,
    view_class VARCHAR(20) NOT NULL,
    CONSTRAINT pk_tmp_expected_pdm017_view PRIMARY KEY (view_name)
);

INSERT INTO tmp_expected_pdm017_view (view_name, view_class)
VALUES
    ('vw_dq_plan_version_overlap', 'VALIDATION'),
    ('vw_dq_home_branch_assignment_overlap', 'VALIDATION'),
    ('vw_dq_membership_decision_integrity', 'VALIDATION'),
    ('vw_dq_membership_status_integrity', 'VALIDATION'),
    ('vw_dq_contract_integrity', 'VALIDATION'),
    ('vw_dq_contract_service_overlap', 'VALIDATION'),
    ('vw_dq_check_in_duplicate_reference', 'VALIDATION'),
    ('vw_dq_check_in_integrity', 'VALIDATION'),
    ('vw_dq_obligation_schedule', 'VALIDATION'),
    ('vw_dq_cancellation_adjustment', 'VALIDATION'),
    ('vw_dq_payment_attempt_integrity', 'VALIDATION'),
    ('vw_dq_payment_reconciliation', 'VALIDATION'),
    ('vw_dq_refund_status_integrity', 'VALIDATION'),
    ('vw_dq_refund_reconciliation', 'VALIDATION'),
    ('vw_dq_financial_source_issue', 'VALIDATION'),
    ('vw_dq_financial_exception_integrity', 'VALIDATION'),
    ('vw_dq_financial_release_readiness', 'VALIDATION'),
    ('vw_reporting_check_in', 'REPORTING'),
    ('vw_reporting_financial_exception', 'REPORTING'),
    ('vw_reporting_financial_exception_summary', 'REPORTING'),
    ('vw_reporting_financial_source_disposition', 'REPORTING'),
    ('vw_reporting_gross_collected_revenue', 'REPORTING'),
    ('vw_reporting_net_collected_revenue', 'REPORTING'),
    ('vw_reporting_obligation_balance', 'REPORTING'),
    ('vw_reporting_refund', 'REPORTING');

-- Expected result: PASS, 25 expected views, and 25 implemented views.
SELECT
    'PDM017_EXACT_VIEW_COUNT' AS validation_control,
    25 AS expected_result,
    COUNT(*) AS actual_result,
    CASE WHEN COUNT(*) = 25 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM information_schema.views AS implemented
JOIN tmp_expected_pdm017_view AS expected
    ON expected.view_name = implemented.table_name
WHERE implemented.table_schema = DATABASE();

-- Expected result: two rows, 17 validation views and 8 reporting views, both PASS.
SELECT
    CONCAT('PDM017_', expected.view_class, '_VIEW_COUNT') AS validation_control,
    CASE expected.view_class WHEN 'VALIDATION' THEN 17 ELSE 8 END AS expected_result,
    COUNT(implemented.table_name) AS actual_result,
    CASE
        WHEN COUNT(implemented.table_name)
             = CASE expected.view_class WHEN 'VALIDATION' THEN 17 ELSE 8 END
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM tmp_expected_pdm017_view AS expected
LEFT JOIN information_schema.views AS implemented
    ON implemented.table_schema = DATABASE()
   AND implemented.table_name = expected.view_name
GROUP BY expected.view_class;

-- Expected result: zero rows. Any row is a missing approved view.
SELECT
    expected.view_name AS missing_view_name,
    expected.view_class
FROM tmp_expected_pdm017_view AS expected
LEFT JOIN information_schema.views AS implemented
    ON implemented.table_schema = DATABASE()
   AND implemented.table_name = expected.view_name
WHERE implemented.table_name IS NULL
ORDER BY expected.view_name;

-- Expected result: zero rows. This catches unapproved vw_dq_* or vw_reporting_* objects.
SELECT
    implemented.table_name AS unexpected_view_name
FROM information_schema.views AS implemented
LEFT JOIN tmp_expected_pdm017_view AS expected
    ON expected.view_name = implemented.table_name
WHERE implemented.table_schema = DATABASE()
  AND implemented.table_name REGEXP '^vw_(dq|reporting)_'
  AND expected.view_name IS NULL
ORDER BY implemented.table_name;

-- Expected result: PASS. Named-zone conversion requires loaded MySQL time-zone tables.
SELECT
    'PDM017_BEIRUT_TIME_ZONE_SUPPORT' AS validation_control,
    'NONNULL' AS expected_result,
    CASE
        WHEN CONVERT_TZ(TIMESTAMP('2026-01-01 00:00:00'), '+00:00', 'Asia/Beirut')
             IS NULL
        THEN 'NULL'
        ELSE 'NONNULL'
    END AS actual_result,
    CASE
        WHEN CONVERT_TZ(TIMESTAMP('2026-01-01 00:00:00'), '+00:00', 'Asia/Beirut')
             IS NOT NULL
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result;

-- Execute every view and disclose current row counts. Successful execution proves that
-- all view definitions and dependencies compile in the target schema.
SELECT 'vw_dq_plan_version_overlap' AS view_name, COUNT(*) AS current_row_count FROM vw_dq_plan_version_overlap
UNION ALL SELECT 'vw_dq_home_branch_assignment_overlap', COUNT(*) FROM vw_dq_home_branch_assignment_overlap
UNION ALL SELECT 'vw_dq_membership_decision_integrity', COUNT(*) FROM vw_dq_membership_decision_integrity
UNION ALL SELECT 'vw_dq_membership_status_integrity', COUNT(*) FROM vw_dq_membership_status_integrity
UNION ALL SELECT 'vw_dq_contract_integrity', COUNT(*) FROM vw_dq_contract_integrity
UNION ALL SELECT 'vw_dq_contract_service_overlap', COUNT(*) FROM vw_dq_contract_service_overlap
UNION ALL SELECT 'vw_dq_check_in_duplicate_reference', COUNT(*) FROM vw_dq_check_in_duplicate_reference
UNION ALL SELECT 'vw_dq_check_in_integrity', COUNT(*) FROM vw_dq_check_in_integrity
UNION ALL SELECT 'vw_dq_obligation_schedule', COUNT(*) FROM vw_dq_obligation_schedule
UNION ALL SELECT 'vw_dq_cancellation_adjustment', COUNT(*) FROM vw_dq_cancellation_adjustment
UNION ALL SELECT 'vw_dq_payment_attempt_integrity', COUNT(*) FROM vw_dq_payment_attempt_integrity
UNION ALL SELECT 'vw_dq_payment_reconciliation', COUNT(*) FROM vw_dq_payment_reconciliation
UNION ALL SELECT 'vw_dq_refund_status_integrity', COUNT(*) FROM vw_dq_refund_status_integrity
UNION ALL SELECT 'vw_dq_refund_reconciliation', COUNT(*) FROM vw_dq_refund_reconciliation
UNION ALL SELECT 'vw_dq_financial_source_issue', COUNT(*) FROM vw_dq_financial_source_issue
UNION ALL SELECT 'vw_dq_financial_exception_integrity', COUNT(*) FROM vw_dq_financial_exception_integrity
UNION ALL SELECT 'vw_dq_financial_release_readiness', COUNT(*) FROM vw_dq_financial_release_readiness
UNION ALL SELECT 'vw_reporting_check_in', COUNT(*) FROM vw_reporting_check_in
UNION ALL SELECT 'vw_reporting_financial_exception', COUNT(*) FROM vw_reporting_financial_exception
UNION ALL SELECT 'vw_reporting_financial_exception_summary', COUNT(*) FROM vw_reporting_financial_exception_summary
UNION ALL SELECT 'vw_reporting_financial_source_disposition', COUNT(*) FROM vw_reporting_financial_source_disposition
UNION ALL SELECT 'vw_reporting_gross_collected_revenue', COUNT(*) FROM vw_reporting_gross_collected_revenue
UNION ALL SELECT 'vw_reporting_net_collected_revenue', COUNT(*) FROM vw_reporting_net_collected_revenue
UNION ALL SELECT 'vw_reporting_obligation_balance', COUNT(*) FROM vw_reporting_obligation_balance
UNION ALL SELECT 'vw_reporting_refund', COUNT(*) FROM vw_reporting_refund
ORDER BY view_name;

-- Required operational disclosure. Empty valid test data should return READY.
SELECT *
FROM vw_dq_financial_release_readiness;

DROP TEMPORARY TABLE tmp_expected_pdm017_view;
