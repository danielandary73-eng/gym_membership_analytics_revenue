-- Gym Membership & Revenue Analytics System
-- PDM-023 Functional Test Batch 1: membership and valid Check-In workflow
-- Prerequisite: run 10_build_test_environment.sql immediately before this test.
-- Safety: this script writes only to gym_membership_analytics_test.

USE gym_membership_analytics_test;

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION time_zone = '+00:00';

-- Foundation reference records intentionally use a clear FT01 test prefix.
INSERT INTO branch (
    branch_code, branch_name, city_name, opened_date, closed_date
)
VALUES (
    'FT01BR', 'Functional Test Beirut Branch', 'Beirut', '2020-01-01', NULL
);
SET @ft_branch_id = LAST_INSERT_ID();

INSERT INTO membership_plan (plan_code)
VALUES ('FT01ANNUAL');
SET @ft_plan_id = LAST_INSERT_ID();

CALL sp_create_membership_plan_version(
    @ft_plan_id,
    'Functional Test Annual Plan',
    12,
    120.00,
    '2025-01-01',
    NULL,
    @ft_plan_version_id
);

INSERT INTO member (
    member_number, first_name, last_name, registration_date,
    email_address, mobile_phone
)
VALUES (
    'FT01MEM001', 'Functional', 'Tester', '2025-12-01',
    'functional.tester@example.test', '+96170000000'
);
SET @ft_member_id = LAST_INSERT_ID();

CALL sp_assign_member_home_branch(
    @ft_member_id,
    @ft_branch_id,
    '2025-12-01',
    NULL,
    @ft_assignment_id
);

SET @ft_obligation_schedule = JSON_ARRAY(
    JSON_OBJECT(
        'obligation_number', 'FT01OBL001',
        'sequence_number', 1,
        'amount_usd', 60.00,
        'due_date', '2026-01-01'
    ),
    JSON_OBJECT(
        'obligation_number', 'FT01OBL002',
        'sequence_number', 2,
        'amount_usd', 60.00,
        'due_date', '2026-02-01'
    )
);

CALL sp_create_membership_contract(
    'FT01CON001',
    @ft_member_id,
    @ft_plan_version_id,
    NULL,
    '2025-12-20',
    '2026-01-01',
    '2026-12-31',
    120.00,
    0.00,
    'INSTALLMENT',
    @ft_obligation_schedule,
    @ft_contract_id
);

CALL sp_ingest_check_in(
    'FT01-CHECKIN-001',
    'FT01MEM001',
    'FT01BR',
    '2026-01-15 15:00:00.000000',
    '2026-01-15 15:00:05.000000',
    @ft_check_in_id
);

-- Every row below must return PASS.
SELECT
    'FT01_BRANCH_CREATED' AS validation_control,
    1 AS expected_result,
    COUNT(*) AS actual_result,
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM branch
WHERE branch_id = @ft_branch_id
  AND branch_code = 'FT01BR'

UNION ALL

SELECT
    'FT01_PLAN_VERSION_CREATED', 1, COUNT(*),
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM membership_plan_version
WHERE plan_version_id = @ft_plan_version_id
  AND standard_duration_months = 12
  AND standard_price_usd = 120.00

UNION ALL

SELECT
    'FT01_HOME_BRANCH_ASSIGNED', 1, COUNT(*),
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM member_branch_assignment
WHERE member_branch_assignment_id = @ft_assignment_id
  AND member_id = @ft_member_id
  AND home_branch_id = @ft_branch_id

UNION ALL

SELECT
    'FT01_CONTRACT_CREATED', 1, COUNT(*),
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM membership_contract
WHERE membership_contract_id = @ft_contract_id
  AND financial_ownership_branch_id = @ft_branch_id
  AND historical_list_price_usd = 120.00
  AND discount_amount_usd = 0.00

UNION ALL

SELECT
    'FT01_OBLIGATIONS_RECONCILE', 1,
    IF(COUNT(*) = 2 AND SUM(original_obligation_amount_usd) = 120.00, 1, 0),
    CASE
        WHEN COUNT(*) = 2 AND SUM(original_obligation_amount_usd) = 120.00
        THEN 'PASS' ELSE 'FAIL'
    END
FROM payment_obligation
WHERE membership_contract_id = @ft_contract_id

UNION ALL

SELECT
    'FT01_CHECK_IN_CREATED', 1, COUNT(*),
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM check_in
WHERE check_in_id = @ft_check_in_id
  AND member_id = @ft_member_id
  AND visited_branch_id = @ft_branch_id

UNION ALL

SELECT
    'FT01_CHECK_IN_HAS_NO_QUALITY_ISSUE', 0, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM check_in_quality_issue
WHERE check_in_id = @ft_check_in_id

UNION ALL

SELECT
    'FT01_CHECK_IN_REPORTING_ELIGIBLE', 1, COUNT(*),
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM vw_reporting_check_in
WHERE check_in_id = @ft_check_in_id;

-- Detail evidence for manual review.
SELECT
    membership_contract_id,
    contract_number,
    financial_ownership_branch_id,
    historical_list_price_usd,
    discount_amount_usd,
    historical_list_price_usd - discount_amount_usd AS expected_revenue_usd
FROM membership_contract
WHERE membership_contract_id = @ft_contract_id;

SELECT
    payment_obligation_id,
    obligation_number,
    obligation_sequence_number,
    original_obligation_amount_usd,
    due_date
FROM payment_obligation
WHERE membership_contract_id = @ft_contract_id
ORDER BY obligation_sequence_number;

SELECT *
FROM vw_reporting_check_in
WHERE check_in_id = @ft_check_in_id;
