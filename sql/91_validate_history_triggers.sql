-- Gym Membership & Revenue Analytics System
-- PDM-016 structural validation for all 32 history-protection triggers

USE gym_membership_analytics;

SELECT
    'HISTORY_PROTECTION_TRIGGERS' AS control_name,
    32 AS expected_count,
    COUNT(*) AS actual_count,
    CASE WHEN COUNT(*) = 32 THEN 'PASS' ELSE 'FAIL' END AS result
FROM information_schema.triggers
WHERE trigger_schema = 'gym_membership_analytics';

-- This result set must be empty: every expected trigger must have the exact table,
-- timing, and event, and no unexpected trigger may exist at this checkpoint.
WITH expected_trigger AS (
    SELECT 'trg_membership_contract_bu_immutable' AS trigger_name, 'membership_contract' AS table_name, 'BEFORE' AS action_timing, 'UPDATE' AS event_manipulation
    UNION ALL SELECT 'trg_membership_contract_bd_immutable', 'membership_contract', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_membership_status_event_bu_immutable', 'membership_status_event', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_membership_status_event_bd_immutable', 'membership_status_event', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_membership_status_decision_event_bu_immutable', 'membership_status_decision_event', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_membership_status_decision_event_bd_immutable', 'membership_status_decision_event', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_check_in_bu_controlled_correction', 'check_in', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_check_in_bd_no_delete', 'check_in', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_check_in_quality_issue_bu_resolution', 'check_in_quality_issue', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_check_in_quality_issue_bd_no_delete', 'check_in_quality_issue', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_payment_obligation_bu_immutable', 'payment_obligation', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_payment_obligation_bd_immutable', 'payment_obligation', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_payment_obligation_adjustment_bu_immutable', 'payment_obligation_adjustment', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_payment_obligation_adjustment_bd_immutable', 'payment_obligation_adjustment', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_payment_bu_immutable', 'payment', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_payment_bd_immutable', 'payment', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_payment_attempt_bu_immutable', 'payment_attempt', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_payment_attempt_bd_immutable', 'payment_attempt', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_payment_attempt_status_event_bu_immutable', 'payment_attempt_status_event', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_payment_attempt_status_event_bd_immutable', 'payment_attempt_status_event', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_payment_allocation_bu_immutable', 'payment_allocation', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_payment_allocation_bd_immutable', 'payment_allocation', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_refund_bu_immutable', 'refund', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_refund_bd_immutable', 'refund', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_refund_status_event_bu_immutable', 'refund_status_event', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_refund_status_event_bd_immutable', 'refund_status_event', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_refund_allocation_bu_immutable', 'refund_allocation', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_refund_allocation_bd_immutable', 'refund_allocation', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_financial_exception_bu_immutable', 'financial_exception', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_financial_exception_bd_immutable', 'financial_exception', 'BEFORE', 'DELETE'
    UNION ALL SELECT 'trg_financial_exception_status_event_bu_immutable', 'financial_exception_status_event', 'BEFORE', 'UPDATE'
    UNION ALL SELECT 'trg_financial_exception_status_event_bd_immutable', 'financial_exception_status_event', 'BEFORE', 'DELETE'
), actual_trigger AS (
    SELECT
        trigger_name,
        event_object_table AS table_name,
        action_timing,
        event_manipulation
    FROM information_schema.triggers
    WHERE trigger_schema = 'gym_membership_analytics'
)
SELECT
    'MISSING_OR_MISMATCHED' AS discrepancy_type,
    expected.trigger_name,
    expected.table_name AS expected_table,
    actual.table_name AS actual_table,
    expected.action_timing AS expected_timing,
    actual.action_timing AS actual_timing,
    expected.event_manipulation AS expected_event,
    actual.event_manipulation AS actual_event
FROM expected_trigger AS expected
LEFT JOIN actual_trigger AS actual
    ON actual.trigger_name = expected.trigger_name
WHERE actual.trigger_name IS NULL
   OR actual.table_name <> expected.table_name
   OR actual.action_timing <> expected.action_timing
   OR actual.event_manipulation <> expected.event_manipulation

UNION ALL

SELECT
    'UNEXPECTED',
    actual.trigger_name,
    NULL,
    actual.table_name,
    NULL,
    actual.action_timing,
    NULL,
    actual.event_manipulation
FROM actual_trigger AS actual
LEFT JOIN expected_trigger AS expected
    ON expected.trigger_name = actual.trigger_name
WHERE expected.trigger_name IS NULL
ORDER BY trigger_name;

SELECT
    SUM(event_manipulation = 'UPDATE') AS update_trigger_count,
    SUM(event_manipulation = 'DELETE') AS delete_trigger_count,
    SUM(action_timing = 'BEFORE') AS before_trigger_count,
    CASE
        WHEN SUM(event_manipulation = 'UPDATE') = 16
         AND SUM(event_manipulation = 'DELETE') = 16
         AND SUM(action_timing = 'BEFORE') = 32
        THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM information_schema.triggers
WHERE trigger_schema = 'gym_membership_analytics';
