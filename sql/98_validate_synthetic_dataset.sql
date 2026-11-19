-- Gym Membership & Revenue Analytics System
-- PDM-025 validation: independent scope, integrity, scenario, and reconciliation checks
-- Prerequisite: run 20_seed_synthetic_dataset.sql successfully.

USE gym_membership_analytics;
SET SESSION time_zone = '+00:00';

-- Result 1: approved Branch scope must match the Business Requirements exactly.
SELECT
    'PDM025_BRANCH_SCOPE' AS validation_control,
    3 AS expected_result,
    COUNT(*) AS actual_result,
    CASE
        WHEN COUNT(*) = 3
         AND SUM(city_name IN ('Beirut', 'Aley', 'Jounieh')) = 3
         AND SUM(city_name NOT IN ('Beirut', 'Aley', 'Jounieh')) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_result
FROM branch;

-- Result 2: core target populations.
SELECT 'BRANCH_COUNT' AS population_control, 3 AS minimum_result,
       COUNT(*) AS actual_result,
       CASE WHEN COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM branch
UNION ALL
SELECT 'PLAN_FAMILY_COUNT', 4, COUNT(*),
       CASE WHEN COUNT(*) = 4 THEN 'PASS' ELSE 'FAIL' END
FROM membership_plan
UNION ALL
SELECT 'PLAN_VERSION_COUNT', 8, COUNT(*),
       CASE WHEN COUNT(*) BETWEEN 8 AND 12 THEN 'PASS' ELSE 'FAIL' END
FROM membership_plan_version
UNION ALL
SELECT 'MEMBER_COUNT', 2500, COUNT(*),
       CASE WHEN COUNT(*) = 2500 THEN 'PASS' ELSE 'FAIL' END
FROM member
UNION ALL
SELECT 'CONTRACT_COUNT', 3500, COUNT(*),
       CASE WHEN COUNT(*) = 3500 THEN 'PASS' ELSE 'FAIL' END
FROM membership_contract
UNION ALL
SELECT 'RAW_CHECK_IN_COUNT', 50000, COUNT(*),
       CASE WHEN COUNT(*) BETWEEN 50000 AND 70000 THEN 'PASS' ELSE 'FAIL' END
FROM check_in
UNION ALL
SELECT 'PAYMENT_COUNT', 1, COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM payment
UNION ALL
SELECT 'REFUND_COUNT', 1, COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM refund
UNION ALL
SELECT 'FINANCIAL_EXCEPTION_HISTORY_COUNT', 1, COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM financial_exception;

-- Result 3: 36 complete calendar months represented by operational activity.
WITH RECURSIVE approved_month AS (
    SELECT DATE('2023-09-01') AS month_start
    UNION ALL
    SELECT DATE_ADD(month_start, INTERVAL 1 MONTH)
    FROM approved_month
    WHERE month_start < '2026-08-01'
), activity_month AS (
    SELECT DISTINCT DATE_FORMAT(registration_date, '%Y-%m-01') AS month_start
    FROM member
    WHERE registration_date BETWEEN '2023-09-01' AND '2026-08-31'

    UNION

    SELECT DISTINCT DATE_FORMAT(contract_created_date, '%Y-%m-01')
    FROM membership_contract
    WHERE contract_created_date BETWEEN '2023-09-01' AND '2026-08-31'

    UNION

    SELECT DISTINCT DATE_FORMAT(requested_at, '%Y-%m-01')
    FROM payment
    WHERE requested_at >= '2023-09-01 00:00:00'
      AND requested_at < '2026-09-01 00:00:00'

    UNION

    SELECT DISTINCT DATE_FORMAT(
        CONVERT_TZ(check_in_at, '+00:00', 'Asia/Beirut'),
        '%Y-%m-01'
    )
    FROM check_in
    WHERE check_in_at IS NOT NULL
)
SELECT
    'PDM025_36_COMPLETE_MONTHS' AS validation_control,
    36 AS expected_result,
    SUM(activity.month_start IS NOT NULL) AS actual_result,
    CASE
        WHEN COUNT(*) = 36
         AND SUM(activity.month_start IS NOT NULL) = 36
        THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_result
FROM approved_month
LEFT JOIN activity_month AS activity
    ON activity.month_start = DATE_FORMAT(approved_month.month_start, '%Y-%m-01');

-- Result 4: all independent integrity views must return zero rows.
SELECT 'PLAN_VERSION_OVERLAP' AS integrity_control, COUNT(*) AS issue_count,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM vw_dq_plan_version_overlap
UNION ALL
SELECT 'HOME_BRANCH_OVERLAP', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_home_branch_assignment_overlap
UNION ALL
SELECT 'MEMBERSHIP_DECISION_INTEGRITY', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_membership_decision_integrity
UNION ALL
SELECT 'MEMBERSHIP_STATUS_INTEGRITY', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_membership_status_integrity
UNION ALL
SELECT 'CONTRACT_INTEGRITY', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_contract_integrity
UNION ALL
SELECT 'CONTRACT_SERVICE_OVERLAP', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_contract_service_overlap
UNION ALL
SELECT 'CHECK_IN_ISSUE_INTEGRITY', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_check_in_integrity
UNION ALL
SELECT 'OBLIGATION_SCHEDULE', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_obligation_schedule
UNION ALL
SELECT 'CANCELLATION_ADJUSTMENT', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_cancellation_adjustment
UNION ALL
SELECT 'PAYMENT_ATTEMPT_INTEGRITY', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_payment_attempt_integrity
UNION ALL
SELECT 'PAYMENT_RECONCILIATION', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_payment_reconciliation
UNION ALL
SELECT 'REFUND_STATUS_INTEGRITY', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_refund_status_integrity
UNION ALL
SELECT 'REFUND_RECONCILIATION', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_refund_reconciliation
UNION ALL
SELECT 'CURRENT_FINANCIAL_SOURCE_ISSUES', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_financial_source_issue
UNION ALL
SELECT 'FINANCIAL_EXCEPTION_INTEGRITY', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_financial_exception_integrity;

-- Result 5: required scenario populations for the 15 Business Requirements.
SELECT 'HOME_BRANCH_TRANSFERS' AS scenario_control,
       COUNT(*) AS actual_result,
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM member
WHERE (
    SELECT COUNT(*)
    FROM member_branch_assignment AS assignment
    WHERE assignment.member_id = member.member_id
) > 1
UNION ALL
SELECT 'DIRECT_RENEWAL_CANDIDATES', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM membership_contract AS current_contract
JOIN membership_contract AS previous_contract
    ON previous_contract.membership_contract_id
        = current_contract.previous_membership_contract_id
WHERE current_contract.service_start_date
    = DATE_ADD(previous_contract.original_end_date, INTERVAL 1 DAY)
UNION ALL
SELECT 'REACTIVATION_CANDIDATES', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM membership_contract AS current_contract
JOIN membership_contract AS previous_contract
    ON previous_contract.membership_contract_id
        = current_contract.previous_membership_contract_id
WHERE current_contract.service_start_date
    > DATE_ADD(previous_contract.original_end_date, INTERVAL 1 DAY)
UNION ALL
SELECT 'APPROVED_CANCELLATIONS', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM membership_status_event AS status_event
JOIN membership_status_decision_event AS decision
    ON decision.membership_status_event_id = status_event.membership_status_event_id
WHERE status_event.event_type_code = 'CANCELLATION'
  AND decision.decision_status_code = 'APPROVED'
UNION ALL
SELECT 'APPROVED_FREEZES', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM membership_status_event AS status_event
JOIN membership_status_decision_event AS decision
    ON decision.membership_status_event_id = status_event.membership_status_event_id
WHERE status_event.event_type_code = 'FREEZE'
  AND decision.decision_status_code = 'APPROVED'
UNION ALL
SELECT 'FAILED_PAYMENT_ATTEMPTS', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM payment_attempt_status_event
WHERE attempt_status_code = 'FAILED'
UNION ALL
SELECT 'SUCCESSFUL_RETRIES', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM payment_attempt AS attempt
JOIN payment_attempt_status_event AS status_event
    ON status_event.payment_attempt_id = attempt.payment_attempt_id
WHERE attempt.attempt_sequence_number > 1
  AND status_event.attempt_status_code = 'SETTLED'
UNION ALL
SELECT 'COMPLETED_REFUNDS', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM refund_status_event
WHERE refund_status_code = 'COMPLETED'
UNION ALL
SELECT 'REOPENING_REFUNDS', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM refund_allocation
WHERE reopens_obligation_flag = 1
UNION ALL
SELECT 'DUPLICATE_CHECK_IN_EVIDENCE', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM check_in_quality_issue
WHERE issue_code = 'DUPLICATE_SOURCE_REFERENCE'
UNION ALL
SELECT 'INVALID_CHECK_IN_EVIDENCE', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM check_in_quality_issue
WHERE issue_code IN (
    'MISSING_SOURCE_REFERENCE',
    'UNMATCHED_MEMBER_REFERENCE',
    'UNMATCHED_VISITED_BRANCH_REFERENCE',
    'MISSING_CHECK_IN_TIMESTAMP',
    'INACTIVE_MEMBERSHIP'
)
UNION ALL
SELECT 'HISTORICAL_RESOLVED_EXCEPTIONS', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM financial_exception_status_event
WHERE exception_status_code = 'RESOLVED'
UNION ALL
SELECT 'HISTORICAL_PLAN_VERSION_USAGE', COUNT(DISTINCT plan_version_id),
       CASE WHEN COUNT(DISTINCT plan_version_id) > 4 THEN 'PASS' ELSE 'FAIL' END
FROM membership_contract
UNION ALL
SELECT 'EXPIRING_IN_1_TO_30_DAYS', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM membership_contract AS contract
WHERE contract.original_end_date BETWEEN '2026-09-01' AND '2026-09-30'
  AND NOT EXISTS (
      SELECT 1
      FROM membership_contract AS renewal
      WHERE renewal.previous_membership_contract_id = contract.membership_contract_id
  )
UNION ALL
SELECT 'EXPIRING_IN_31_TO_60_DAYS', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM membership_contract AS contract
WHERE contract.original_end_date BETWEEN '2026-10-01' AND '2026-10-30'
  AND NOT EXISTS (
      SELECT 1
      FROM membership_contract AS renewal
      WHERE renewal.previous_membership_contract_id = contract.membership_contract_id
  )
UNION ALL
SELECT 'LOW_ENGAGEMENT_ACTIVE_MEMBERS', COUNT(*),
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT contract.member_id
    FROM membership_contract AS contract
    LEFT JOIN vw_reporting_check_in AS reporting_check_in
        ON reporting_check_in.member_id = contract.member_id
       AND DATE(reporting_check_in.check_in_at_beirut)
           BETWEEN '2026-08-02' AND '2026-08-31'
    WHERE '2026-08-31' BETWEEN contract.service_start_date AND contract.original_end_date
      AND NOT EXISTS (
          SELECT 1
          FROM membership_status_event AS cancellation
          JOIN membership_status_decision_event AS decision
              ON decision.membership_status_event_id
                  = cancellation.membership_status_event_id
          WHERE cancellation.membership_contract_id = contract.membership_contract_id
            AND cancellation.event_type_code = 'CANCELLATION'
            AND cancellation.effective_start_date <= '2026-08-31'
            AND decision.decision_status_code = 'APPROVED'
      )
    GROUP BY contract.member_id
    HAVING COUNT(reporting_check_in.check_in_id) <= 2
) AS low_engagement;

-- Result 6: Branch-role coverage.
SELECT 'HOME_BRANCH_ROLE' AS branch_role,
       COUNT(DISTINCT home_branch_id) AS represented_branch_count,
       CASE WHEN COUNT(DISTINCT home_branch_id) = 3 THEN 'PASS' ELSE 'FAIL' END
           AS validation_result
FROM member_branch_assignment
UNION ALL
SELECT 'FINANCIAL_OWNERSHIP_BRANCH_ROLE',
       COUNT(DISTINCT financial_ownership_branch_id),
       CASE WHEN COUNT(DISTINCT financial_ownership_branch_id) = 3 THEN 'PASS' ELSE 'FAIL' END
FROM membership_contract
UNION ALL
SELECT 'VISITED_BRANCH_ROLE',
       COUNT(DISTINCT visited_branch_id),
       CASE WHEN COUNT(DISTINCT visited_branch_id) = 3 THEN 'PASS' ELSE 'FAIL' END
FROM vw_reporting_check_in
UNION ALL
SELECT 'PROCESSING_BRANCH_ROLE',
       COUNT(DISTINCT processing_branch_id),
       CASE WHEN COUNT(DISTINCT processing_branch_id) = 3 THEN 'PASS' ELSE 'FAIL' END
FROM payment_attempt;

-- Result 7: exact financial reconciliation bridges.
SELECT
    'PDM025_CONTRACT_VALUE_BRIDGE' AS validation_control,
    ROUND(SUM(historical_list_price_usd), 2) AS gross_contract_value_usd,
    ROUND(SUM(discount_amount_usd), 2) AS discount_amount_usd,
    ROUND(SUM(historical_list_price_usd - discount_amount_usd), 2)
        AS expected_revenue_usd,
    CASE
        WHEN ROUND(SUM(historical_list_price_usd), 2)
           - ROUND(SUM(discount_amount_usd), 2)
           = ROUND(SUM(historical_list_price_usd - discount_amount_usd), 2)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_result
FROM membership_contract;

-- Evaluate the three large reporting aggregates independently. This avoids a
-- MySQL 8 on Windows internal #sql temporary-table materialization failure
-- when all three complex views are combined in one query block.
SELECT COALESCE(ROUND(SUM(gross_collected_amount_usd), 2), 0.00)
INTO @pdm025_gross_collected_revenue_usd
FROM vw_reporting_gross_collected_revenue;

SELECT COALESCE(ROUND(SUM(refund_amount_usd), 2), 0.00)
INTO @pdm025_refund_amount_usd
FROM vw_reporting_refund;

SELECT COALESCE(ROUND(SUM(net_collected_revenue_usd), 2), 0.00)
INTO @pdm025_net_collected_revenue_usd
FROM vw_reporting_net_collected_revenue;

SELECT
    'PDM025_CASH_COLLECTION_BRIDGE' AS validation_control,
    @pdm025_gross_collected_revenue_usd AS gross_collected_revenue_usd,
    @pdm025_refund_amount_usd AS refund_amount_usd,
    @pdm025_net_collected_revenue_usd AS net_collected_revenue_usd,
    CASE
        WHEN @pdm025_gross_collected_revenue_usd
             - @pdm025_refund_amount_usd
             = @pdm025_net_collected_revenue_usd
        THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_result;

-- Result 8: controlled Check-In exclusions must reconcile raw to approved usage.
SELECT COUNT(*)
INTO @pdm025_raw_check_in_count
FROM check_in;

SELECT COUNT(*)
INTO @pdm025_approved_check_in_count
FROM vw_reporting_check_in;

SELECT COUNT(*)
INTO @pdm025_open_quality_issue_count
FROM check_in_quality_issue
WHERE resolved_at IS NULL;

SELECT
    'PDM025_CHECK_IN_CONTROL' AS validation_control,
    @pdm025_raw_check_in_count AS raw_check_in_count,
    @pdm025_approved_check_in_count AS approved_check_in_count,
    @pdm025_open_quality_issue_count AS open_quality_issue_count,
    CASE
        WHEN @pdm025_raw_check_in_count > @pdm025_approved_check_in_count
         AND @pdm025_approved_check_in_count > 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_result;

-- Result 9: the official release gate must be READY with zero unresolved Critical sources.
SELECT
    'PDM025_FINANCIAL_RELEASE_GATE' AS validation_control,
    0 AS expected_critical_result,
    unresolved_critical_source_count AS actual_critical_result,
    release_readiness_code,
    CASE
        WHEN unresolved_critical_source_count = 0
         AND release_readiness_code = 'READY'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_result
FROM vw_dq_financial_release_readiness;

-- Result 10: official procedure result; an error is a release failure.
CALL sp_assert_financial_release_ready(
    @pdm025_unresolved_critical_source_count,
    @pdm025_unresolved_warning_source_count,
    @pdm025_unresolved_critical_amount_usd,
    @pdm025_unresolved_warning_amount_usd
);

SELECT
    'PDM025_RELEASE_PROCEDURE' AS validation_control,
    @pdm025_unresolved_critical_source_count AS unresolved_critical_source_count,
    @pdm025_unresolved_warning_source_count AS unresolved_warning_source_count,
    @pdm025_unresolved_critical_amount_usd AS unresolved_critical_amount_usd,
    @pdm025_unresolved_warning_amount_usd AS unresolved_warning_amount_usd,
    CASE
        WHEN @pdm025_unresolved_critical_source_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_result;
