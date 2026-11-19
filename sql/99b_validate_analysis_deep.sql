-- Gym Membership & Revenue Analytics System
-- SQLA-003B optional deep source-to-mart audit
-- This is not the interactive release gate. Run it only when source data is
-- deliberately rebuilt or when investigating a data-quality exception.

USE gym_membership_analytics;

-- Expected result: zero rows. This intentionally re-executes the expensive
-- source quality views and is separated from the normal fast validator.
SELECT contract.membership_contract_id AS excluded_contract_in_mart
FROM mart_analysis_membership_contract AS contract
WHERE EXISTS (
    SELECT 1 FROM vw_dq_contract_integrity AS issue
    WHERE issue.membership_contract_id = contract.membership_contract_id
)
   OR EXISTS (
       SELECT 1 FROM vw_dq_contract_service_overlap AS issue
       WHERE issue.left_membership_contract_id = contract.membership_contract_id
          OR issue.right_membership_contract_id = contract.membership_contract_id
   )
   OR EXISTS (
       SELECT 1 FROM vw_dq_membership_status_integrity AS issue
       WHERE issue.membership_contract_id = contract.membership_contract_id
   );

-- Exact full-period snapshot grain. This is fast against the materialized mart.
SELECT
    'SQLA003_DEEP_SNAPSHOT_GRAIN' AS validation_control,
    COUNT(*) AS snapshot_rows,
    COUNT(DISTINCT snapshot_date, membership_contract_id) AS distinct_grain_rows,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT snapshot_date, membership_contract_id)
         AND SUM(membership_status_code NOT IN (
             'NOT_STARTED', 'ACTIVE', 'FROZEN', 'CANCELLED', 'EXPIRED'
         )) = 0
         AND SUM(expiring_1_30_day_flag = 1
                 AND expiring_31_60_day_flag = 1) = 0
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM mart_analysis_membership_daily_snapshot;

SELECT
    'SQLA003_DEEP_MART_AUDIT_COMPLETE' AS audit_control,
    'Review the zero-row exception result and PASS grain result' AS audit_result;
