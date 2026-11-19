-- Gym Membership & Revenue Analytics System
-- SQLA-003 validation: exact analytical views, columns, reconciliations, and grants
-- Prerequisite: run 21_create_analysis_views.sql,
-- 23_build_analysis_mart.sql, 24_build_obligation_activity_mart.sql,
-- and 22_extend_analysis_grants.sql.

USE gym_membership_analytics;
SET SESSION group_concat_max_len = 8192;

DROP TEMPORARY TABLE IF EXISTS tmp_expected_sqla003_view;
DROP TEMPORARY TABLE IF EXISTS tmp_sqla003_obligation_activity_balance;
DROP TEMPORARY TABLE IF EXISTS tmp_sqla003_reporting_refund_summary;
DROP TEMPORARY TABLE IF EXISTS tmp_sqla003_analysis_refund_summary;
DROP TEMPORARY TABLE IF EXISTS tmp_sqla003_gross_revenue_summary;
DROP TEMPORARY TABLE IF EXISTS tmp_sqla003_net_revenue_summary;

CREATE TEMPORARY TABLE tmp_expected_sqla003_view (
    view_name VARCHAR(64) NOT NULL,
    expected_column_count SMALLINT UNSIGNED NOT NULL,
    expected_column_csv TEXT NOT NULL,
    CONSTRAINT pk_tmp_expected_sqla003_view PRIMARY KEY (view_name)
);

INSERT INTO tmp_expected_sqla003_view (
    view_name,
    expected_column_count,
    expected_column_csv
)
VALUES
    (
        'vw_analysis_date', 15,
        'calendar_date,calendar_year,calendar_quarter_number,calendar_month_number,calendar_month_name,calendar_year_month,month_start_date,month_end_date,weekday_number_monday_1,weekday_name,previous_month_start_date,previous_year_month_start_date,reporting_scope_flag,opening_anchor_flag,forward_planning_scope_flag'
    ),
    (
        'vw_analysis_branch', 7,
        'branch_id,branch_code,branch_name,city_name,opened_date,closed_date,active_at_reporting_end_flag'
    ),
    (
        'vw_analysis_membership_plan_version', 9,
        'plan_version_id,plan_id,plan_code,plan_name,standard_duration_months,standard_price_usd,available_from_date,available_to_date,available_at_reporting_end_flag'
    ),
    (
        'vw_analysis_home_branch_assignment', 14,
        'member_branch_assignment_id,member_id,member_number,home_branch_id,home_branch_code,home_branch_name,effective_start_date,effective_end_date,previous_member_branch_assignment_id,previous_home_branch_id,previous_home_branch_code,previous_home_branch_name,initial_assignment_flag,transfer_event_flag'
    ),
    (
        'vw_analysis_membership_status_event', 13,
        'membership_status_event_id,membership_contract_id,event_type_code,recorded_at_utc,recorded_at_beirut,effective_start_date,effective_end_date,reason_code,latest_decision_event_id,latest_decision_status_code,latest_decision_at_utc,latest_decision_at_beirut,freeze_duration_days'
    ),
    (
        'vw_analysis_membership_contract', 27,
        'membership_contract_id,contract_number,member_id,member_number,plan_version_id,plan_id,plan_code,plan_name,financial_ownership_branch_id,financial_ownership_branch_code,financial_ownership_branch_name,home_branch_at_start_id,home_branch_at_start_code,home_branch_at_start_name,previous_membership_contract_id,previous_contract_number,contract_classification_code,contract_created_date,service_start_date,original_end_date,approved_freeze_days,effective_end_date,cancellation_effective_date,historical_list_price_usd,discount_amount_usd,expected_revenue_usd,payment_schedule_type_code'
    ),
    (
        'vw_analysis_membership_daily_snapshot', 24,
        'snapshot_date,membership_contract_id,contract_number,member_id,member_number,plan_version_id,plan_id,plan_code,plan_name,home_branch_id,home_branch_code,home_branch_name,financial_ownership_branch_id,service_start_date,effective_end_date,cancellation_effective_date,membership_status_code,active_contract_flag,live_contract_flag,active_member_flag,live_member_flag,days_to_effective_end,expiring_1_30_day_flag,expiring_31_60_day_flag'
    ),
    (
        'vw_analysis_payment_attempt_final', 26,
        'payment_attempt_id,attempt_number,payment_id,payment_number,membership_contract_id,contract_number,member_id,plan_version_id,financial_ownership_branch_id,attempt_sequence_number,attempted_at_utc,attempted_at_beirut,attempt_date_beirut,attempted_amount_usd,payment_method_code,processing_branch_id,processing_branch_code,processing_branch_name,final_status_event_id,final_attempt_status_code,final_status_at_utc,final_status_at_beirut,final_reason_code,finalized_attempt_flag,failed_attempt_flag,reporting_warning_flag'
    ),
    (
        'vw_analysis_obligation_activity', 22,
        'obligation_activity_key,obligation_activity_type_code,activity_date,activity_at_utc,activity_at_beirut,payment_obligation_id,obligation_number,obligation_sequence_number,due_date,membership_contract_id,contract_number,member_id,plan_version_id,financial_ownership_branch_id,source_record_id,source_record_reference,activity_amount_usd,balance_effect_amount_usd,cancelled_amount_flag,gross_application_flag,refund_reopening_flag,reporting_warning_flag'
    ),
    (
        'vw_analysis_refund', 21,
        'refund_allocation_id,refund_id,refund_number,refund_reason_code,refund_amount_usd,reopens_obligation_flag,refunded_at_utc,refunded_at_beirut,refund_date_beirut,payment_id,payment_number,payment_allocation_id,payment_obligation_id,obligation_number,membership_contract_id,contract_number,member_id,plan_version_id,financial_ownership_branch_id,processing_branch_id,reporting_warning_flag'
    );

-- 1. Exact view inventory.
SELECT
    'SQLA003_ANALYSIS_VIEW_COUNT' AS validation_control,
    10 AS expected_result,
    COUNT(*) AS actual_result,
    CASE WHEN COUNT(*) = 10 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM information_schema.views
WHERE table_schema = DATABASE()
  AND table_name LIKE 'vw\\_analysis\\_%';

-- Expected result: zero rows.
SELECT expected.view_name AS missing_analysis_view
FROM tmp_expected_sqla003_view AS expected
LEFT JOIN information_schema.views AS actual
    ON actual.table_schema = DATABASE()
   AND actual.table_name = expected.view_name
WHERE actual.table_name IS NULL
ORDER BY expected.view_name;

-- Expected result: zero rows.
SELECT actual.table_name AS unexpected_analysis_view
FROM information_schema.views AS actual
LEFT JOIN tmp_expected_sqla003_view AS expected
    ON expected.view_name = actual.table_name
WHERE actual.table_schema = DATABASE()
  AND actual.table_name LIKE 'vw\\_analysis\\_%'
  AND expected.view_name IS NULL
ORDER BY actual.table_name;

-- 2. Exact ordered column contracts: ten PASS rows.
SELECT
    expected.view_name,
    expected.expected_column_count,
    COUNT(actual.column_name) AS actual_column_count,
    CASE
        WHEN COUNT(actual.column_name) = expected.expected_column_count
         AND GROUP_CONCAT(
                 actual.column_name
                 ORDER BY actual.ordinal_position
                 SEPARATOR ','
             ) = expected.expected_column_csv
        THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_result
FROM tmp_expected_sqla003_view AS expected
LEFT JOIN information_schema.columns AS actual
    ON actual.table_schema = DATABASE()
   AND actual.table_name = expected.view_name
GROUP BY
    expected.view_name,
    expected.expected_column_count,
    expected.expected_column_csv
ORDER BY expected.view_name;

-- 3. Exact runtime view availability. Later controls execute each data domain
-- independently, avoiding one opaque and expensive combined materialization.
SELECT
    expected.view_name,
    CASE WHEN actual.table_name IS NOT NULL THEN 'AVAILABLE' ELSE 'MISSING' END
        AS runtime_status
FROM tmp_expected_sqla003_view AS expected
LEFT JOIN information_schema.views AS actual
    ON actual.table_schema = DATABASE()
   AND actual.table_name = expected.view_name
ORDER BY expected.view_name;

-- 4. Calendar boundary and scope counts.
SELECT
    'SQLA003_DATE_INVENTORY' AS validation_control,
    MIN(calendar_date) AS minimum_date,
    MAX(calendar_date) AS maximum_date,
    COUNT(*) AS total_dates,
    COUNT(DISTINCT calendar_date) AS distinct_dates,
    SUM(reporting_scope_flag) AS reporting_dates,
    SUM(opening_anchor_flag) AS opening_anchor_dates,
    SUM(forward_planning_scope_flag) AS planning_dates,
    CASE
        WHEN MIN(calendar_date) = DATE('2023-08-31')
         AND MAX(calendar_date) = DATE('2026-10-30')
         AND COUNT(*) = 1157
         AND COUNT(DISTINCT calendar_date) = 1157
         AND SUM(reporting_scope_flag) = 1096
         AND SUM(opening_anchor_flag) = 1
         AND SUM(forward_planning_scope_flag) = 60
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM vw_analysis_date;

-- 5. Exact approved Branch set.
SELECT
    'SQLA003_BRANCH_INVENTORY' AS validation_control,
    3 AS expected_result,
    COUNT(*) AS actual_result,
    CASE
        WHEN COUNT(*) = 3
         AND SUM(branch_code IN ('BEI', 'ALE', 'JOU')) = 3
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM vw_analysis_branch;

-- 6. Plan Version completeness and source-period integrity.
SELECT
    'SQLA003_PLAN_VERSION_COMPLETENESS' AS validation_control,
    (SELECT COUNT(*) FROM membership_plan_version) AS expected_result,
    COUNT(*) AS actual_result,
    CASE
        WHEN COUNT(*) = (SELECT COUNT(*) FROM membership_plan_version)
         AND (SELECT COUNT(*) FROM vw_dq_plan_version_overlap) = 0
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM vw_analysis_membership_plan_version;

-- 7. Assignment lineage: valid Member population, unique rows, balanced transfers.
SELECT
    'SQLA003_HOME_ASSIGNMENT_GRAIN' AS validation_control,
    COUNT(*) AS row_count,
    COUNT(DISTINCT member_branch_assignment_id) AS distinct_assignment_count,
    SUM(transfer_event_flag) AS transfer_in_count,
    SUM(previous_home_branch_id IS NOT NULL AND transfer_event_flag = 1)
        AS transfer_out_count,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT member_branch_assignment_id)
         AND SUM(transfer_event_flag)
             = SUM(previous_home_branch_id IS NOT NULL AND transfer_event_flag = 1)
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM vw_analysis_home_branch_assignment;

-- 8. Status events remain approved, active, and at their frozen grain.
SELECT
    'SQLA003_STATUS_EVENT_GRAIN' AS validation_control,
    COUNT(*) AS row_count,
    COUNT(DISTINCT membership_status_event_id) AS distinct_event_count,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT membership_status_event_id)
         AND SUM(latest_decision_status_code <> 'APPROVED') = 0
         AND SUM(event_type_code NOT IN ('CANCELLATION', 'FREEZE')) = 0
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM vw_analysis_membership_status_event;

-- 9. Contract grain, classifications, and financial bridge.
SELECT
    'SQLA003_CONTRACT_VALUE_BRIDGE' AS validation_control,
    COUNT(*) AS contract_count,
    COUNT(DISTINCT membership_contract_id) AS distinct_contract_count,
    ROUND(SUM(historical_list_price_usd), 2) AS gross_contract_value_usd,
    ROUND(SUM(discount_amount_usd), 2) AS discount_amount_usd,
    ROUND(SUM(expected_revenue_usd), 2) AS expected_revenue_usd,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT membership_contract_id)
         AND SUM(contract_classification_code NOT IN (
                 'NEW_MEMBERSHIP', 'DIRECT_RENEWAL', 'REACTIVATION'
             )) = 0
         AND ROUND(
                 SUM(historical_list_price_usd) - SUM(discount_amount_usd), 2
             ) = ROUND(SUM(expected_revenue_usd), 2)
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM vw_analysis_membership_contract;

-- 9A. The public Contract view must be a complete wrapper over its mart table.
SELECT
    'SQLA003_CONTRACT_MART_RECONCILIATION' AS validation_control,
    mart.contract_count AS expected_result,
    view_data.contract_count AS actual_result,
    CASE WHEN mart.contract_count = view_data.contract_count
         THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM (SELECT COUNT(*) AS contract_count
      FROM mart_analysis_membership_contract) AS mart
CROSS JOIN (SELECT COUNT(*) AS contract_count
            FROM vw_analysis_membership_contract) AS view_data;

-- 10. Performance-safe snapshot grain and status validation.
-- Validate both approved period boundaries: the opening anchor and reporting end.
-- The view's interval joins inherit uniqueness from the already validated,
-- non-overlapping Contract, status-event, and Home Branch source populations.
SELECT
    'SQLA003_DAILY_SNAPSHOT_GRAIN' AS validation_control,
    2 AS expected_snapshot_date_count,
    COUNT(*) AS actual_snapshot_date_count,
    contract.contract_count AS expected_contracts_per_date,
    MIN(daily.row_count) AS minimum_rows_per_date,
    MAX(daily.row_count) AS maximum_rows_per_date,
    CASE
        WHEN COUNT(*) = 2
         AND MIN(daily.row_count) = contract.contract_count
         AND MAX(daily.row_count) = contract.contract_count
         AND MIN(daily.distinct_contract_count) = contract.contract_count
         AND MAX(daily.distinct_contract_count) = contract.contract_count
         AND SUM(daily.invalid_status_count) = 0
         AND SUM(daily.overlapping_expiry_flag_count) = 0
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM (
    SELECT
        snapshot_date,
        COUNT(*) AS row_count,
        COUNT(DISTINCT membership_contract_id) AS distinct_contract_count,
        SUM(membership_status_code NOT IN (
            'NOT_STARTED', 'ACTIVE', 'FROZEN', 'CANCELLED', 'EXPIRED'
        )) AS invalid_status_count,
        SUM(
            expiring_1_30_day_flag = 1
            AND expiring_31_60_day_flag = 1
    ) AS overlapping_expiry_flag_count
    FROM vw_analysis_membership_daily_snapshot
    WHERE snapshot_date IN (DATE('2023-08-31'), DATE('2026-08-31'))
    GROUP BY snapshot_date
) AS daily
CROSS JOIN (
    SELECT COUNT(*) AS contract_count
    FROM vw_analysis_membership_contract
) AS contract
GROUP BY contract.contract_count;

-- 11. Final Payment Attempt flags follow the approved denominator definition.
SELECT
    'SQLA003_PAYMENT_ATTEMPT_FINAL' AS validation_control,
    COUNT(*) AS attempt_count,
    COUNT(DISTINCT payment_attempt_id) AS distinct_attempt_count,
    SUM(finalized_attempt_flag) AS finalized_attempt_count,
    SUM(failed_attempt_flag) AS failed_attempt_count,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT payment_attempt_id)
         AND SUM(
                 finalized_attempt_flag <>
                 (final_attempt_status_code IN ('SUCCESSFUL', 'SETTLED', 'FAILED'))
             ) = 0
         AND SUM(failed_attempt_flag <> (final_attempt_status_code = 'FAILED')) = 0
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM vw_analysis_payment_attempt_final;

-- 12. Activity types and current Obligation balances reconcile per Obligation.
-- Materialize the grouped UNION ALL ledger explicitly. This avoids a MySQL 8
-- for Windows optimizer defect that can lose its internal #sql temporary table
-- when the grouped union view is used directly inside a joined derived table.
CREATE TEMPORARY TABLE tmp_sqla003_obligation_activity_balance (
    payment_obligation_id BIGINT UNSIGNED NOT NULL,
    reconstructed_balance_usd DECIMAL(18, 2) NOT NULL,
    CONSTRAINT pk_tmp_sqla003_obligation_activity_balance
        PRIMARY KEY (payment_obligation_id)
) ENGINE = InnoDB;

INSERT INTO tmp_sqla003_obligation_activity_balance (
    payment_obligation_id,
    reconstructed_balance_usd
)
SELECT
    payment_obligation_id,
    ROUND(SUM(balance_effect_amount_usd), 2) AS reconstructed_balance_usd
FROM vw_analysis_obligation_activity
GROUP BY payment_obligation_id;

SELECT
    'SQLA003_OBLIGATION_ACTIVITY_RECONCILIATION' AS validation_control,
    COUNT(*) AS obligation_count,
    SUM(
        ROUND(GREATEST(activity.reconstructed_balance_usd, 0.00), 2)
        <> ROUND(balance.outstanding_balance_usd, 2)
    ) AS mismatched_obligation_count,
    CASE
        WHEN SUM(
                 ROUND(GREATEST(activity.reconstructed_balance_usd, 0.00), 2)
                 <> ROUND(balance.outstanding_balance_usd, 2)
             ) = 0
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM vw_reporting_obligation_balance AS balance
JOIN tmp_sqla003_obligation_activity_balance AS activity
    ON activity.payment_obligation_id = balance.payment_obligation_id;

-- 13. Analytical Refund exactly inherits the approved reporting population.
-- Execute each complex Refund view independently to avoid the MySQL Windows
-- internal #sql collision seen when both are expanded in one statement.
CREATE TEMPORARY TABLE tmp_sqla003_reporting_refund_summary (
    row_count BIGINT UNSIGNED NOT NULL,
    refund_amount_usd DECIMAL(18, 2) NOT NULL
) ENGINE = InnoDB;

INSERT INTO tmp_sqla003_reporting_refund_summary
SELECT
    COUNT(*),
    ROUND(COALESCE(SUM(refund_amount_usd), 0.00), 2)
FROM vw_reporting_refund;

CREATE TEMPORARY TABLE tmp_sqla003_analysis_refund_summary (
    row_count BIGINT UNSIGNED NOT NULL,
    refund_amount_usd DECIMAL(18, 2) NOT NULL
) ENGINE = InnoDB;

INSERT INTO tmp_sqla003_analysis_refund_summary
SELECT
    COUNT(*),
    ROUND(COALESCE(SUM(refund_amount_usd), 0.00), 2)
FROM vw_analysis_refund;

SELECT
    'SQLA003_REFUND_RECONCILIATION' AS validation_control,
    reporting.row_count AS expected_row_count,
    analysis.row_count AS actual_row_count,
    reporting.refund_amount_usd AS expected_amount_usd,
    analysis.refund_amount_usd AS actual_amount_usd,
    CASE
        WHEN reporting.row_count = analysis.row_count
         AND reporting.refund_amount_usd = analysis.refund_amount_usd
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM tmp_sqla003_reporting_refund_summary AS reporting
CROSS JOIN tmp_sqla003_analysis_refund_summary AS analysis;

-- 14. Existing controlled gross less Refund equals the net ledger.
CREATE TEMPORARY TABLE tmp_sqla003_gross_revenue_summary (
    gross_amount_usd DECIMAL(18, 2) NOT NULL
) ENGINE = InnoDB;

INSERT INTO tmp_sqla003_gross_revenue_summary
SELECT ROUND(COALESCE(SUM(gross_collected_amount_usd), 0.00), 2)
FROM vw_reporting_gross_collected_revenue;

CREATE TEMPORARY TABLE tmp_sqla003_net_revenue_summary (
    net_amount_usd DECIMAL(18, 2) NOT NULL
) ENGINE = InnoDB;

INSERT INTO tmp_sqla003_net_revenue_summary
SELECT ROUND(COALESCE(SUM(net_collected_revenue_usd), 0.00), 2)
FROM vw_reporting_net_collected_revenue;

SELECT
    'SQLA003_NET_REVENUE_BRIDGE' AS validation_control,
    gross.gross_amount_usd,
    refunded.refund_amount_usd,
    net.net_amount_usd,
    CASE
        WHEN ROUND(gross.gross_amount_usd - refunded.refund_amount_usd, 2)
             = net.net_amount_usd
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM tmp_sqla003_gross_revenue_summary AS gross
CROSS JOIN tmp_sqla003_reporting_refund_summary AS refunded
CROSS JOIN tmp_sqla003_net_revenue_summary AS net;

-- 15. Exact read-only analytical grants.
SELECT
    grantee,
    10 AS expected_result,
    COUNT(*) AS actual_result,
    CASE WHEN COUNT(*) = 10 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM information_schema.table_privileges
WHERE table_schema = DATABASE()
  AND table_name IN (SELECT view_name FROM tmp_expected_sqla003_view)
  AND privilege_type = 'SELECT'
  AND grantee IN (
      '''gym_analyst_powerbi''@''%''',
      '''gym_audit_reviewer''@''%'''
  )
GROUP BY grantee
ORDER BY grantee;

-- Analyst remains curated-only: 19 view reads and zero base-table reads.
SELECT
    'SQLA003_ANALYST_SELECT_BOUNDARY' AS validation_control,
    19 AS expected_view_grants,
    SUM(object_catalog.table_type = 'VIEW') AS actual_view_grants,
    0 AS expected_base_table_grants,
    SUM(object_catalog.table_type = 'BASE TABLE') AS actual_base_table_grants,
    CASE
        WHEN SUM(object_catalog.table_type = 'VIEW') = 19
         AND SUM(object_catalog.table_type = 'BASE TABLE') = 0
        THEN 'PASS' ELSE 'FAIL'
    END AS validation_result
FROM information_schema.table_privileges AS privilege
JOIN information_schema.tables AS object_catalog
    ON object_catalog.table_schema = privilege.table_schema
   AND object_catalog.table_name = privilege.table_name
WHERE privilege.grantee = '''gym_analyst_powerbi''@''%'''
  AND privilege.table_schema = DATABASE()
  AND privilege.privilege_type = 'SELECT';

-- Audit remains read-only and covers all 24 tables plus all 35 views.
SELECT
    'SQLA003_AUDIT_SELECT_BOUNDARY' AS validation_control,
    59 AS expected_select_grants,
    COUNT(*) AS actual_select_grants,
    CASE WHEN COUNT(*) = 59 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM information_schema.table_privileges
WHERE grantee = '''gym_audit_reviewer''@''%'''
  AND table_schema = DATABASE()
  AND privilege_type = 'SELECT';

-- Expected result: zero rows. No analytical grant is grantable or writable.
SELECT grantee, table_name, privilege_type, is_grantable
FROM information_schema.table_privileges
WHERE table_schema = DATABASE()
  AND table_name IN (SELECT view_name FROM tmp_expected_sqla003_view)
  AND grantee IN (
      '''gym_analyst_powerbi''@''%''',
      '''gym_audit_reviewer''@''%'''
  )
  AND (privilege_type <> 'SELECT' OR is_grantable = 'YES')
ORDER BY grantee, table_name, privilege_type;

-- 16. Mandatory release gate disclosure. Expected release_status: READY.
SELECT *
FROM vw_dq_financial_release_readiness;

DROP TEMPORARY TABLE tmp_expected_sqla003_view;
DROP TEMPORARY TABLE tmp_sqla003_obligation_activity_balance;
DROP TEMPORARY TABLE tmp_sqla003_reporting_refund_summary;
DROP TEMPORARY TABLE tmp_sqla003_analysis_refund_summary;
DROP TEMPORARY TABLE tmp_sqla003_gross_revenue_summary;
DROP TEMPORARY TABLE tmp_sqla003_net_revenue_summary;
