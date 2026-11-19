-- Gym Membership & Revenue Analytics System
-- PDM-023 Functional Test Batch 3: completed Refund and obligation reopening
-- Prerequisite: successfully run scripts 10, 11, and 12 in order.
-- Safety: this script writes only to gym_membership_analytics_test.

USE gym_membership_analytics_test;

SET SESSION time_zone = '+00:00';

SELECT payment_id
  INTO @ft_payment_id
FROM payment
WHERE payment_number = 'FT02PAY001';

SELECT payment_allocation_id
  INTO @ft_payment_allocation_id
FROM payment_allocation
WHERE payment_id = @ft_payment_id;

SELECT membership_contract_id
  INTO @ft_contract_id
FROM membership_contract
WHERE contract_number = 'FT01CON001';

CALL sp_request_refund(
    'FT03REF001',
    @ft_payment_id,
    '2026-01-10 10:00:00.000000',
    20.00,
    'CUSTOMER_REQUEST',
    @ft_refund_id
);

SET @ft_refund_allocation_json = JSON_ARRAY(
    JSON_OBJECT(
        'payment_allocation_id', @ft_payment_allocation_id,
        'refund_allocated_amount_usd', 20.00,
        'reopens_obligation_flag', 1
    )
);

CALL sp_complete_refund(
    @ft_refund_id,
    '2026-01-10 10:05:00.000000',
    @ft_refund_allocation_json,
    @ft_inserted_refund_allocation_count
);

-- Every row below must return PASS.
SELECT
    'FT03_REFUND_CREATED' AS validation_control,
    1 AS expected_result,
    COUNT(*) AS actual_result,
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM refund
WHERE refund_id = @ft_refund_id
  AND refund_amount_usd = 20.00

UNION ALL

SELECT
    'FT03_REFUND_COMPLETED', 1, COUNT(*),
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM refund_status_event
WHERE refund_id = @ft_refund_id
  AND refund_status_code = 'COMPLETED'

UNION ALL

SELECT
    'FT03_ONE_REFUND_ALLOCATION', 1, @ft_inserted_refund_allocation_count,
    CASE WHEN @ft_inserted_refund_allocation_count = 1 THEN 'PASS' ELSE 'FAIL' END

UNION ALL

SELECT
    'FT03_OBLIGATION_REOPENED', 1, COUNT(*),
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM refund_allocation
WHERE refund_id = @ft_refund_id
  AND refund_allocated_amount_usd = 20.00
  AND reopens_obligation_flag = 1

UNION ALL

SELECT
    'FT03_REFUND_STATUS_ISSUES', 0, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_refund_status_integrity
WHERE refund_id = @ft_refund_id

UNION ALL

SELECT
    'FT03_REFUND_RECONCILIATION_ISSUES', 0, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_refund_reconciliation
WHERE refund_id = @ft_refund_id

UNION ALL

SELECT
    'FT03_GROSS_REVENUE_UNCHANGED', 60.00,
    COALESCE(SUM(gross_collected_amount_usd), 0.00),
    CASE WHEN COALESCE(SUM(gross_collected_amount_usd), 0.00) = 60.00
         THEN 'PASS' ELSE 'FAIL' END
FROM vw_reporting_gross_collected_revenue
WHERE payment_id = @ft_payment_id

UNION ALL

SELECT
    'FT03_REPORTED_REFUND', 20.00,
    COALESCE(SUM(refund_amount_usd), 0.00),
    CASE WHEN COALESCE(SUM(refund_amount_usd), 0.00) = 20.00
         THEN 'PASS' ELSE 'FAIL' END
FROM vw_reporting_refund
WHERE refund_id = @ft_refund_id

UNION ALL

SELECT
    'FT03_NET_COLLECTED_REVENUE', 40.00,
    COALESCE(SUM(net_collected_revenue_usd), 0.00),
    CASE WHEN COALESCE(SUM(net_collected_revenue_usd), 0.00) = 40.00
         THEN 'PASS' ELSE 'FAIL' END
FROM vw_reporting_net_collected_revenue
WHERE payment_id = @ft_payment_id

UNION ALL

SELECT
    'FT03_REMAINING_CONTRACT_BALANCE', 80.00,
    COALESCE(SUM(outstanding_balance_usd), 0.00),
    CASE WHEN COALESCE(SUM(outstanding_balance_usd), 0.00) = 80.00
         THEN 'PASS' ELSE 'FAIL' END
FROM vw_reporting_obligation_balance
WHERE membership_contract_id = @ft_contract_id;

-- Detail evidence for manual review.
SELECT
    refund_number,
    refund_amount_usd,
    refund_amount_usd AS requested_refund_usd
FROM refund
WHERE refund_id = @ft_refund_id;

SELECT *
FROM vw_reporting_refund
WHERE refund_id = @ft_refund_id;

SELECT
    revenue_transaction_type,
    gross_collected_amount_usd,
    refund_amount_usd,
    net_collected_revenue_usd
FROM vw_reporting_net_collected_revenue
WHERE payment_id = @ft_payment_id
ORDER BY transaction_at_utc;

SELECT
    obligation_number,
    original_obligation_amount_usd,
    gross_applied_amount_usd,
    reopened_amount_usd,
    outstanding_balance_usd
FROM vw_reporting_obligation_balance
WHERE membership_contract_id = @ft_contract_id
ORDER BY obligation_sequence_number;
