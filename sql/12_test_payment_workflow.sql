-- Gym Membership & Revenue Analytics System
-- PDM-023 Functional Test Batch 2: Payment Attempt, retry, and Allocation workflow
-- Prerequisite: successfully run 10_build_test_environment.sql and
-- 11_test_membership_check_in_workflow.sql in that order.
-- Safety: this script writes only to gym_membership_analytics_test.

USE gym_membership_analytics_test;

SET SESSION time_zone = '+00:00';

SELECT membership_contract_id
  INTO @ft_contract_id
FROM membership_contract
WHERE contract_number = 'FT01CON001';

SELECT payment_obligation_id
  INTO @ft_first_obligation_id
FROM payment_obligation
WHERE membership_contract_id = @ft_contract_id
  AND obligation_sequence_number = 1;

SELECT branch_id
  INTO @ft_branch_id
FROM branch
WHERE branch_code = 'FT01BR';

CALL sp_create_payment(
    'FT02PAY001',
    @ft_contract_id,
    '2026-01-01 08:00:00.000000',
    60.00,
    'CARD',
    @ft_payment_id
);

-- First attempt fails and remains preserved as part of the audit trail.
CALL sp_record_payment_attempt(
    'FT02ATT001',
    @ft_payment_id,
    '2026-01-01 08:01:00.000000',
    60.00,
    'CARD',
    @ft_branch_id,
    @ft_failed_attempt_id
);

CALL sp_transition_payment_attempt(
    @ft_failed_attempt_id,
    'FAILED',
    '2026-01-01 08:02:00.000000',
    'CARD_DECLINED',
    @ft_failed_status_id
);

-- A separate retry succeeds using the member's chosen fallback method.
CALL sp_record_payment_attempt(
    'FT02ATT002',
    @ft_payment_id,
    '2026-01-01 08:05:00.000000',
    60.00,
    'BANK_TRANSFER',
    @ft_branch_id,
    @ft_successful_attempt_id
);

CALL sp_transition_payment_attempt(
    @ft_successful_attempt_id,
    'SUCCESSFUL',
    '2026-01-01 08:06:00.000000',
    NULL,
    @ft_successful_status_id
);

SET @ft_allocation_json = JSON_ARRAY(
    JSON_OBJECT(
        'payment_obligation_id', @ft_first_obligation_id,
        'allocated_amount_usd', 60.00
    )
);

CALL sp_allocate_successful_payment(
    @ft_payment_id,
    '2026-01-01 08:07:00.000000',
    @ft_allocation_json,
    @ft_inserted_allocation_count
);

-- Every row below must return PASS.
SELECT
    'FT02_PAYMENT_CREATED' AS validation_control,
    1 AS expected_result,
    COUNT(*) AS actual_result,
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM payment
WHERE payment_id = @ft_payment_id
  AND requested_amount_usd = 60.00

UNION ALL

SELECT
    'FT02_TWO_ATTEMPTS_PRESERVED', 2, COUNT(*),
    CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END
FROM payment_attempt
WHERE payment_id = @ft_payment_id

UNION ALL

SELECT
    'FT02_FAILED_ATTEMPT_RECORDED', 1, COUNT(*),
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM payment_attempt_status_event
WHERE payment_attempt_id = @ft_failed_attempt_id
  AND attempt_status_code = 'FAILED'

UNION ALL

SELECT
    'FT02_SUCCESSFUL_RETRY_RECORDED', 1, COUNT(*),
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM payment_attempt_status_event
WHERE payment_attempt_id = @ft_successful_attempt_id
  AND attempt_status_code = 'SUCCESSFUL'

UNION ALL

SELECT
    'FT02_ONE_ALLOCATION_INSERTED', 1, @ft_inserted_allocation_count,
    CASE WHEN @ft_inserted_allocation_count = 1 THEN 'PASS' ELSE 'FAIL' END

UNION ALL

SELECT
    'FT02_ALLOCATION_TOTAL', 60.00, COALESCE(SUM(allocated_amount_usd), 0.00),
    CASE WHEN COALESCE(SUM(allocated_amount_usd), 0.00) = 60.00
         THEN 'PASS' ELSE 'FAIL' END
FROM payment_allocation
WHERE payment_id = @ft_payment_id

UNION ALL

SELECT
    'FT02_PAYMENT_RECONCILIATION_ISSUES', 0, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_payment_reconciliation
WHERE payment_id = @ft_payment_id

UNION ALL

SELECT
    'FT02_GROSS_COLLECTED_REVENUE', 60.00,
    COALESCE(SUM(gross_collected_amount_usd), 0.00),
    CASE WHEN COALESCE(SUM(gross_collected_amount_usd), 0.00) = 60.00
         THEN 'PASS' ELSE 'FAIL' END
FROM vw_reporting_gross_collected_revenue
WHERE payment_id = @ft_payment_id

UNION ALL

SELECT
    'FT02_REMAINING_CONTRACT_BALANCE', 60.00,
    COALESCE(SUM(outstanding_balance_usd), 0.00),
    CASE WHEN COALESCE(SUM(outstanding_balance_usd), 0.00) = 60.00
         THEN 'PASS' ELSE 'FAIL' END
FROM vw_reporting_obligation_balance
WHERE membership_contract_id = @ft_contract_id;

-- Detail evidence for manual review.
SELECT
    attempt.attempt_number,
    attempt.attempt_sequence_number,
    attempt.payment_method_code,
    status_event.attempt_status_code,
    status_event.status_at
FROM payment_attempt AS attempt
JOIN payment_attempt_status_event AS status_event
    ON status_event.payment_attempt_id = attempt.payment_attempt_id
WHERE attempt.payment_id = @ft_payment_id
ORDER BY attempt.attempt_sequence_number, status_event.status_at;

SELECT *
FROM vw_reporting_gross_collected_revenue
WHERE payment_id = @ft_payment_id;

SELECT
    obligation_number,
    original_obligation_amount_usd,
    gross_applied_amount_usd,
    outstanding_balance_usd
FROM vw_reporting_obligation_balance
WHERE membership_contract_id = @ft_contract_id
ORDER BY obligation_sequence_number;

