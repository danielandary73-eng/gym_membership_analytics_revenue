-- Gym Membership & Revenue Analytics System
-- PDM-025: deterministic 36-month synthetic analytics dataset
-- Prerequisite: execute the complete approved schema package through
-- 09_create_roles_grants.sql and confirm an empty gym_membership_analytics schema.
-- Scope: Beirut, Aley, and Jounieh; 2023-09-01 through 2026-08-31; USD.

USE gym_membership_analytics;
SET SESSION time_zone = '+00:00';

-- Stop instead of duplicating or mixing this controlled dataset with existing data.
-- The check constraint fails the script when any approved table already contains rows.
CREATE TEMPORARY TABLE tmp_seed_precondition (
    existing_row_count BIGINT UNSIGNED NOT NULL,
    CONSTRAINT ck_tmp_seed_precondition_empty CHECK (existing_row_count = 0)
);

INSERT INTO tmp_seed_precondition (existing_row_count)
SELECT SUM(table_count)
FROM (
    SELECT COUNT(*) AS table_count FROM branch
    UNION ALL SELECT COUNT(*) FROM membership_plan
    UNION ALL SELECT COUNT(*) FROM membership_plan_version
    UNION ALL SELECT COUNT(*) FROM member
    UNION ALL SELECT COUNT(*) FROM member_branch_assignment
    UNION ALL SELECT COUNT(*) FROM membership_contract
    UNION ALL SELECT COUNT(*) FROM membership_status_event
    UNION ALL SELECT COUNT(*) FROM membership_status_decision_event
    UNION ALL SELECT COUNT(*) FROM check_in
    UNION ALL SELECT COUNT(*) FROM check_in_quality_issue
    UNION ALL SELECT COUNT(*) FROM payment_obligation
    UNION ALL SELECT COUNT(*) FROM payment_obligation_adjustment
    UNION ALL SELECT COUNT(*) FROM payment
    UNION ALL SELECT COUNT(*) FROM payment_attempt
    UNION ALL SELECT COUNT(*) FROM payment_attempt_status_event
    UNION ALL SELECT COUNT(*) FROM payment_allocation
    UNION ALL SELECT COUNT(*) FROM refund
    UNION ALL SELECT COUNT(*) FROM refund_status_event
    UNION ALL SELECT COUNT(*) FROM refund_allocation
    UNION ALL SELECT COUNT(*) FROM financial_exception
    UNION ALL SELECT COUNT(*) FROM financial_exception_status_event
) AS inventory;

DROP TEMPORARY TABLE tmp_seed_precondition;

START TRANSACTION;

-- Reusable deterministic integer set: 1 through 70,000.
-- MySQL cannot reopen one temporary table under multiple aliases in a single
-- statement, so use one statement-scoped CTE for the reusable digits.

CREATE TEMPORARY TABLE tmp_seed_number (
    n INT UNSIGNED NOT NULL PRIMARY KEY
);

INSERT INTO tmp_seed_number (n)
WITH seed_digit (digit) AS (
    SELECT 0
    UNION ALL SELECT 1
    UNION ALL SELECT 2
    UNION ALL SELECT 3
    UNION ALL SELECT 4
    UNION ALL SELECT 5
    UNION ALL SELECT 6
    UNION ALL SELECT 7
    UNION ALL SELECT 8
    UNION ALL SELECT 9
)
SELECT
    ones.digit
    + tens.digit * 10
    + hundreds.digit * 100
    + thousands.digit * 1000
    + ten_thousands.digit * 10000
    + 1 AS n
FROM seed_digit AS ones
CROSS JOIN seed_digit AS tens
CROSS JOIN seed_digit AS hundreds
CROSS JOIN seed_digit AS thousands
CROSS JOIN seed_digit AS ten_thousands
WHERE ones.digit
    + tens.digit * 10
    + hundreds.digit * 100
    + thousands.digit * 1000
    + ten_thousands.digit * 10000 < 70000;

-- ---------------------------------------------------------------------------
-- 1. Approved reference data
-- ---------------------------------------------------------------------------

INSERT INTO branch (
    branch_id,
    branch_code,
    branch_name,
    city_name,
    opened_date,
    closed_date
)
VALUES
    (1, 'BEI', 'Beirut Central', 'Beirut', '2018-01-15', NULL),
    (2, 'ALE', 'Aley Heights', 'Aley', '2019-06-01', NULL),
    (3, 'JOU', 'Jounieh Coast', 'Jounieh', '2020-03-10', NULL);

INSERT INTO membership_plan (plan_id, plan_code)
VALUES
    (1, 'MONTHLY'),
    (2, 'QUARTERLY'),
    (3, 'SEMIANNUAL'),
    (4, 'ANNUAL');

INSERT INTO membership_plan_version (
    plan_version_id,
    plan_id,
    plan_name,
    standard_duration_months,
    standard_price_usd,
    available_from_date,
    available_to_date
)
VALUES
    (1, 1, 'Monthly Access', 1, 35.00, '2023-09-01', '2024-08-31'),
    (2, 1, 'Monthly Access', 1, 38.00, '2024-09-01', '2025-08-31'),
    (3, 1, 'Monthly Access', 1, 40.00, '2025-09-01', NULL),
    (4, 2, 'Quarterly Access', 3, 95.00, '2023-09-01', '2024-08-31'),
    (5, 2, 'Quarterly Access', 3, 102.00, '2024-09-01', '2025-08-31'),
    (6, 2, 'Quarterly Access', 3, 108.00, '2025-09-01', NULL),
    (7, 3, 'Semiannual Access', 6, 175.00, '2023-09-01', '2024-08-31'),
    (8, 3, 'Semiannual Access', 6, 188.00, '2024-09-01', '2025-08-31'),
    (9, 3, 'Semiannual Access', 6, 198.00, '2025-09-01', NULL),
    (10, 4, 'Annual Access', 12, 320.00, '2023-09-01', '2024-08-31'),
    (11, 4, 'Annual Access', 12, 345.00, '2024-09-01', '2025-08-31'),
    (12, 4, 'Annual Access', 12, 365.00, '2025-09-01', NULL);

-- ---------------------------------------------------------------------------
-- 2. Members and effective Home Branch history
-- ---------------------------------------------------------------------------

CREATE TEMPORARY TABLE tmp_seed_member AS
SELECT
    number.n AS member_id,
    CONCAT('MEM', LPAD(number.n, 6, '0')) AS member_number,
    CONCAT('Member', LPAD(number.n, 4, '0')) AS first_name,
    CONCAT('Fictional', LPAD(MOD(number.n - 1, 250) + 1, 3, '0')) AS last_name,
    CONCAT('member', LPAD(number.n, 6, '0'), '@example.invalid') AS email_address,
    CONCAT('+961000', LPAD(number.n, 6, '0')) AS phone_number,
    CASE
        WHEN number.n <= 1000 THEN
            DATE_ADD(
                DATE_ADD('2023-09-01', INTERVAL MOD(number.n - 1, 18) MONTH),
                INTERVAL MOD(FLOOR((number.n - 1) / 18), 20) DAY
            )
        ELSE
            DATE_ADD(
                DATE_ADD('2023-09-01', INTERVAL MOD(number.n - 1, 34) MONTH),
                INTERVAL MOD(FLOOR((number.n - 1) / 34), 20) DAY
            )
    END AS registered_date,
    1 + MOD(number.n - 1, 3) AS initial_branch_id
FROM tmp_seed_number AS number
WHERE number.n <= 2500;

INSERT INTO member (
    member_id,
    member_number,
    first_name,
    last_name,
    registration_date,
    email_address,
    mobile_phone
)
SELECT
    member_id,
    member_number,
    first_name,
    last_name,
    registered_date,
    email_address,
    phone_number
FROM tmp_seed_member
ORDER BY member_id;

INSERT INTO member_branch_assignment (
    member_branch_assignment_id,
    member_id,
    home_branch_id,
    effective_start_date,
    effective_end_date
)
SELECT
    member_id,
    member_id,
    initial_branch_id,
    registered_date,
    CASE WHEN member_id <= 200 THEN '2025-02-28' ELSE NULL END
FROM tmp_seed_member
ORDER BY member_id;

INSERT INTO member_branch_assignment (
    member_branch_assignment_id,
    member_id,
    home_branch_id,
    effective_start_date,
    effective_end_date
)
SELECT
    2500 + member_id,
    member_id,
    1 + MOD(initial_branch_id, 3),
    '2025-03-01',
    NULL
FROM tmp_seed_member
WHERE member_id <= 200
ORDER BY member_id;

-- ---------------------------------------------------------------------------
-- 3. Contracts, predecessor lineage, and obligation schedules
-- ---------------------------------------------------------------------------

CREATE TEMPORARY TABLE tmp_seed_contract (
    membership_contract_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    contract_number VARCHAR(30) NOT NULL,
    member_id BIGINT UNSIGNED NOT NULL,
    plan_version_id BIGINT UNSIGNED NOT NULL,
    financial_ownership_branch_id BIGINT UNSIGNED NOT NULL,
    previous_membership_contract_id BIGINT UNSIGNED NULL,
    contract_created_date DATE NOT NULL,
    service_start_date DATE NOT NULL,
    original_end_date DATE NOT NULL,
    historical_list_price_usd DECIMAL(12,2) NOT NULL,
    discount_amount_usd DECIMAL(12,2) NOT NULL,
    payment_schedule_type_code VARCHAR(20) NOT NULL,
    standard_duration_months SMALLINT UNSIGNED NOT NULL
);

INSERT INTO tmp_seed_contract
SELECT
    first_contract.member_id AS membership_contract_id,
    CONCAT('CTR', LPAD(first_contract.member_id, 7, '0')) AS contract_number,
    first_contract.member_id,
    plan_version.plan_version_id,
    assignment.home_branch_id AS financial_ownership_branch_id,
    NULL AS previous_membership_contract_id,
    first_contract.service_start_date AS contract_created_date,
    first_contract.service_start_date,
    DATE_SUB(
        DATE_ADD(
            first_contract.service_start_date,
            INTERVAL plan_version.standard_duration_months MONTH
        ),
        INTERVAL 1 DAY
    ) AS original_end_date,
    plan_version.standard_price_usd,
    CASE
        WHEN MOD(first_contract.member_id, 10) IN (0, 1) THEN
            ROUND(plan_version.standard_price_usd * 0.10, 2)
        WHEN MOD(first_contract.member_id, 10) = 2 THEN
            ROUND(plan_version.standard_price_usd * 0.05, 2)
        ELSE 0.00
    END AS discount_amount_usd,
    CASE
        WHEN plan_version.standard_duration_months >= 6 THEN 'INSTALLMENT'
        ELSE 'FULL'
    END AS payment_schedule_type_code,
    plan_version.standard_duration_months
FROM (
    SELECT
        seed_member.member_id,
        DATE_ADD(seed_member.registered_date, INTERVAL 7 DAY) AS service_start_date,
        1 + MOD(seed_member.member_id - 1, 4) AS plan_id
    FROM tmp_seed_member AS seed_member
) AS first_contract
JOIN membership_plan_version AS plan_version
    ON plan_version.plan_id = first_contract.plan_id
   AND plan_version.available_from_date <= first_contract.service_start_date
   AND (
       plan_version.available_to_date IS NULL
       OR plan_version.available_to_date >= first_contract.service_start_date
   )
JOIN member_branch_assignment AS assignment
    ON assignment.member_id = first_contract.member_id
   AND assignment.effective_start_date <= first_contract.service_start_date
   AND (
       assignment.effective_end_date IS NULL
       OR assignment.effective_end_date >= first_contract.service_start_date
   )
ORDER BY first_contract.member_id;

-- Materialize continuation inputs separately. This avoids reading
-- tmp_seed_contract twice while simultaneously inserting into it, which
-- raises MySQL Error 1137 for temporary tables.
CREATE TEMPORARY TABLE tmp_seed_continuation AS
SELECT
    membership_contract_id AS previous_membership_contract_id,
    member_id,
    CASE
        WHEN MOD(member_id, 2) = 0 THEN DATE_ADD(original_end_date, INTERVAL 1 DAY)
        ELSE DATE_ADD(original_end_date, INTERVAL 30 DAY)
    END AS service_start_date
FROM tmp_seed_contract
WHERE membership_contract_id <= 1000;

INSERT INTO tmp_seed_contract
SELECT
    2500 + continuation.member_id AS membership_contract_id,
    CONCAT('CTR', LPAD(2500 + continuation.member_id, 7, '0')) AS contract_number,
    continuation.member_id,
    plan_version.plan_version_id,
    assignment.home_branch_id AS financial_ownership_branch_id,
    continuation.previous_membership_contract_id,
    continuation.service_start_date AS contract_created_date,
    continuation.service_start_date,
    DATE_SUB(
        DATE_ADD(
            continuation.service_start_date,
            INTERVAL plan_version.standard_duration_months MONTH
        ),
        INTERVAL 1 DAY
    ) AS original_end_date,
    plan_version.standard_price_usd,
    CASE
        WHEN MOD(continuation.member_id, 8) = 0 THEN
            ROUND(plan_version.standard_price_usd * 0.08, 2)
        ELSE 0.00
    END AS discount_amount_usd,
    CASE
        WHEN plan_version.standard_duration_months >= 6 THEN 'INSTALLMENT'
        ELSE 'FULL'
    END AS payment_schedule_type_code,
    plan_version.standard_duration_months
FROM tmp_seed_continuation AS continuation
JOIN membership_plan_version AS plan_version
    ON plan_version.plan_id = 1 + MOD(continuation.member_id - 1, 4)
   AND plan_version.available_from_date <= continuation.service_start_date
   AND (
       plan_version.available_to_date IS NULL
       OR plan_version.available_to_date >= continuation.service_start_date
   )
JOIN member_branch_assignment AS assignment
    ON assignment.member_id = continuation.member_id
   AND assignment.effective_start_date <= continuation.service_start_date
   AND (
       assignment.effective_end_date IS NULL
       OR assignment.effective_end_date >= continuation.service_start_date
   )
WHERE continuation.service_start_date <= '2026-08-31'
ORDER BY continuation.member_id;

INSERT INTO membership_contract (
    membership_contract_id,
    contract_number,
    member_id,
    plan_version_id,
    financial_ownership_branch_id,
    previous_membership_contract_id,
    contract_created_date,
    service_start_date,
    original_end_date,
    historical_list_price_usd,
    discount_amount_usd,
    payment_schedule_type_code
)
SELECT
    membership_contract_id,
    contract_number,
    member_id,
    plan_version_id,
    financial_ownership_branch_id,
    previous_membership_contract_id,
    contract_created_date,
    service_start_date,
    original_end_date,
    historical_list_price_usd,
    discount_amount_usd,
    payment_schedule_type_code
FROM tmp_seed_contract
ORDER BY membership_contract_id;

CREATE TEMPORARY TABLE tmp_seed_obligation (
    payment_obligation_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    obligation_number VARCHAR(30) NOT NULL,
    membership_contract_id BIGINT UNSIGNED NOT NULL,
    obligation_sequence_number SMALLINT UNSIGNED NOT NULL,
    original_obligation_amount_usd DECIMAL(12,2) NOT NULL,
    due_date DATE NOT NULL
);

INSERT INTO tmp_seed_obligation
SELECT
    ROW_NUMBER() OVER (
        ORDER BY schedule.membership_contract_id, sequence_number.n
    ) AS payment_obligation_id,
    CONCAT(
        'OBL',
        LPAD(schedule.membership_contract_id, 7, '0'),
        '-',
        LPAD(sequence_number.n, 2, '0')
    ) AS obligation_number,
    schedule.membership_contract_id,
    sequence_number.n AS obligation_sequence_number,
    CASE
        WHEN sequence_number.n < schedule.installment_count THEN schedule.regular_amount_usd
        ELSE schedule.expected_revenue_usd
             - schedule.regular_amount_usd * (schedule.installment_count - 1)
    END AS original_obligation_amount_usd,
    DATE_ADD(
        schedule.service_start_date,
        INTERVAL ((sequence_number.n - 1) * schedule.installment_spacing_months) MONTH
    ) AS due_date
FROM (
    SELECT
        contract.membership_contract_id,
        contract.service_start_date,
        contract.historical_list_price_usd - contract.discount_amount_usd
            AS expected_revenue_usd,
        CASE
            WHEN contract.payment_schedule_type_code = 'FULL' THEN 1
            WHEN contract.standard_duration_months = 6 THEN 3
            ELSE 4
        END AS installment_count,
        CASE
            WHEN contract.payment_schedule_type_code = 'FULL' THEN 0
            WHEN contract.standard_duration_months = 6 THEN 2
            ELSE 3
        END AS installment_spacing_months,
        ROUND(
            (contract.historical_list_price_usd - contract.discount_amount_usd)
            / CASE
                WHEN contract.payment_schedule_type_code = 'FULL' THEN 1
                WHEN contract.standard_duration_months = 6 THEN 3
                ELSE 4
              END,
            2
        ) AS regular_amount_usd
    FROM tmp_seed_contract AS contract
) AS schedule
JOIN tmp_seed_number AS sequence_number
    ON sequence_number.n <= schedule.installment_count
ORDER BY schedule.membership_contract_id, sequence_number.n;

INSERT INTO payment_obligation (
    payment_obligation_id,
    obligation_number,
    membership_contract_id,
    obligation_sequence_number,
    original_obligation_amount_usd,
    due_date
)
SELECT
    payment_obligation_id,
    obligation_number,
    membership_contract_id,
    obligation_sequence_number,
    original_obligation_amount_usd,
    due_date
FROM tmp_seed_obligation
ORDER BY payment_obligation_id;

-- ---------------------------------------------------------------------------
-- 4. Approved and rejected membership workflow histories
-- ---------------------------------------------------------------------------

INSERT INTO membership_status_event (
    membership_status_event_id,
    membership_contract_id,
    event_type_code,
    recorded_at,
    effective_start_date,
    effective_end_date,
    reason_code,
    reverses_membership_status_event_id
)
SELECT
    number.n,
    1100 + number.n,
    'FREEZE',
    TIMESTAMP(DATE_ADD(contract.service_start_date, INTERVAL 3 DAY), '09:00:00'),
    DATE_ADD(contract.service_start_date, INTERVAL 10 DAY),
    DATE_ADD(contract.service_start_date, INTERVAL 16 DAY),
    CASE WHEN MOD(number.n, 2) = 0 THEN 'TRAVEL' ELSE 'MEDICAL' END,
    NULL
FROM tmp_seed_number AS number
JOIN tmp_seed_contract AS contract
    ON contract.membership_contract_id = 1100 + number.n
WHERE number.n <= 100;

INSERT INTO membership_status_event (
    membership_status_event_id,
    membership_contract_id,
    event_type_code,
    recorded_at,
    effective_start_date,
    effective_end_date,
    reason_code,
    reverses_membership_status_event_id
)
SELECT
    100 + number.n,
    1200 + number.n,
    'CANCELLATION',
    TIMESTAMP(DATE_ADD(contract.service_start_date, INTERVAL 5 DAY), '10:00:00'),
    DATE_ADD(contract.service_start_date, INTERVAL 20 DAY),
    NULL,
    CASE WHEN MOD(number.n, 2) = 0 THEN 'RELOCATION' ELSE 'PERSONAL' END,
    NULL
FROM tmp_seed_number AS number
JOIN tmp_seed_contract AS contract
    ON contract.membership_contract_id = 1200 + number.n
WHERE number.n <= 100;

INSERT INTO membership_status_event (
    membership_status_event_id,
    membership_contract_id,
    event_type_code,
    recorded_at,
    effective_start_date,
    effective_end_date,
    reason_code,
    reverses_membership_status_event_id
)
SELECT
    200 + number.n,
    1300 + number.n,
    'FREEZE',
    TIMESTAMP(DATE_ADD(contract.service_start_date, INTERVAL 4 DAY), '11:00:00'),
    DATE_ADD(contract.service_start_date, INTERVAL 12 DAY),
    DATE_ADD(contract.service_start_date, INTERVAL 18 DAY),
    'INCOMPLETE_DOCUMENTATION',
    NULL
FROM tmp_seed_number AS number
JOIN tmp_seed_contract AS contract
    ON contract.membership_contract_id = 1300 + number.n
WHERE number.n <= 20;

INSERT INTO membership_status_event (
    membership_status_event_id,
    membership_contract_id,
    event_type_code,
    recorded_at,
    effective_start_date,
    effective_end_date,
    reason_code,
    reverses_membership_status_event_id
)
SELECT
    220 + number.n,
    1100 + number.n,
    'REVERSAL',
    TIMESTAMP(DATE_ADD(contract.service_start_date, INTERVAL 8 DAY), '12:00:00'),
    DATE_ADD(contract.service_start_date, INTERVAL 8 DAY),
    NULL,
    'REQUEST_WITHDRAWN',
    number.n
FROM tmp_seed_number AS number
JOIN tmp_seed_contract AS contract
    ON contract.membership_contract_id = 1100 + number.n
WHERE number.n <= 20;

INSERT INTO membership_status_decision_event (
    membership_status_decision_event_id,
    membership_status_event_id,
    decision_status_code,
    decision_at
)
SELECT
    (status_event.membership_status_event_id * 2) - 1,
    status_event.membership_status_event_id,
    'PENDING',
    status_event.recorded_at
FROM membership_status_event AS status_event
ORDER BY status_event.membership_status_event_id;

INSERT INTO membership_status_decision_event (
    membership_status_decision_event_id,
    membership_status_event_id,
    decision_status_code,
    decision_at
)
SELECT
    status_event.membership_status_event_id * 2,
    status_event.membership_status_event_id,
    CASE
        WHEN status_event.membership_status_event_id BETWEEN 201 AND 220
        THEN 'REJECTED'
        ELSE 'APPROVED'
    END,
    DATE_ADD(status_event.recorded_at, INTERVAL 1 HOUR)
FROM membership_status_event AS status_event
ORDER BY status_event.membership_status_event_id;

INSERT INTO payment_obligation_adjustment (
    payment_obligation_adjustment_id,
    payment_obligation_id,
    membership_status_event_id,
    adjustment_amount_usd,
    recorded_at
)
SELECT
    ROW_NUMBER() OVER (ORDER BY obligation.payment_obligation_id),
    obligation.payment_obligation_id,
    cancellation.membership_status_event_id,
    obligation.original_obligation_amount_usd,
    DATE_ADD(cancellation.recorded_at, INTERVAL 2 HOUR)
FROM membership_status_event AS cancellation
JOIN payment_obligation AS obligation
    ON obligation.membership_contract_id = cancellation.membership_contract_id
   AND obligation.due_date >= cancellation.effective_start_date
WHERE cancellation.event_type_code = 'CANCELLATION'
ORDER BY obligation.payment_obligation_id;

-- ---------------------------------------------------------------------------
-- 5. Payments, failures, retries, settlements, and allocations
-- ---------------------------------------------------------------------------

CREATE TEMPORARY TABLE tmp_seed_payment AS
SELECT
    ROW_NUMBER() OVER (ORDER BY eligible.payment_obligation_id) AS payment_id,
    CONCAT(
        'PAY',
        LPAD(ROW_NUMBER() OVER (ORDER BY eligible.payment_obligation_id), 7, '0')
    ) AS payment_number,
    eligible.membership_contract_id,
    eligible.payment_obligation_id,
    eligible.collectible_amount_usd AS payment_amount_usd,
    TIMESTAMP(
        DATE_ADD(eligible.due_date, INTERVAL MOD(eligible.payment_obligation_id, 8) DAY),
        '10:00:00'
    ) AS requested_at,
    CASE MOD(eligible.payment_obligation_id, 3)
        WHEN 0 THEN 'CASH'
        WHEN 1 THEN 'CARD'
        ELSE 'BANK_TRANSFER'
    END AS intended_payment_method_code
FROM (
    SELECT
        obligation.payment_obligation_id,
        obligation.membership_contract_id,
        obligation.due_date,
        obligation.original_obligation_amount_usd
            - COALESCE(SUM(adjustment.adjustment_amount_usd), 0.00)
            AS collectible_amount_usd
    FROM payment_obligation AS obligation
    LEFT JOIN payment_obligation_adjustment AS adjustment
        ON adjustment.payment_obligation_id = obligation.payment_obligation_id
    WHERE obligation.due_date <= '2026-08-10'
      AND MOD(obligation.payment_obligation_id, 5) <> 0
    GROUP BY
        obligation.payment_obligation_id,
        obligation.membership_contract_id,
        obligation.due_date,
        obligation.original_obligation_amount_usd
    HAVING collectible_amount_usd > 0
) AS eligible;

INSERT INTO payment (
    payment_id,
    payment_number,
    membership_contract_id,
    requested_at,
    requested_amount_usd,
    intended_payment_method_code
)
SELECT
    payment_id,
    payment_number,
    membership_contract_id,
    requested_at,
    payment_amount_usd,
    intended_payment_method_code
FROM tmp_seed_payment
ORDER BY payment_id;

CREATE TEMPORARY TABLE tmp_seed_attempt AS
SELECT
    ROW_NUMBER() OVER (ORDER BY attempt_source.payment_id, attempt_source.attempt_sequence_number)
        AS payment_attempt_id,
    CONCAT(
        'ATT',
        LPAD(
            ROW_NUMBER() OVER (
                ORDER BY attempt_source.payment_id, attempt_source.attempt_sequence_number
            ),
            8,
            '0'
        )
    ) AS attempt_number,
    attempt_source.payment_id,
    attempt_source.attempt_sequence_number,
    CASE
        WHEN attempt_source.attempt_sequence_number = 1 THEN attempt_source.requested_at
        ELSE DATE_ADD(attempt_source.requested_at, INTERVAL 1 DAY)
    END AS attempted_at,
    attempt_source.payment_amount_usd AS attempted_amount_usd,
    CASE
        WHEN attempt_source.attempt_sequence_number = 2 THEN 'CARD'
        ELSE attempt_source.intended_payment_method_code
    END AS payment_method_code,
    CASE
        WHEN MOD(attempt_source.payment_id, 7) = 0
        THEN 1 + MOD(attempt_source.financial_ownership_branch_id, 3)
        ELSE attempt_source.financial_ownership_branch_id
    END AS processing_branch_id,
    (
        attempt_source.attempt_sequence_number = 1
        AND MOD(attempt_source.payment_id, 10) = 0
    ) AS failed_flag
FROM (
    SELECT
        payment.payment_id,
        payment.requested_at,
        payment.requested_amount_usd AS payment_amount_usd,
        payment.intended_payment_method_code,
        contract.financial_ownership_branch_id,
        1 AS attempt_sequence_number
    FROM payment AS payment
    JOIN membership_contract AS contract
        ON contract.membership_contract_id = payment.membership_contract_id

    UNION ALL

    SELECT
        payment.payment_id,
        payment.requested_at,
        payment.requested_amount_usd AS payment_amount_usd,
        payment.intended_payment_method_code,
        contract.financial_ownership_branch_id,
        2 AS attempt_sequence_number
    FROM payment AS payment
    JOIN membership_contract AS contract
        ON contract.membership_contract_id = payment.membership_contract_id
    WHERE MOD(payment.payment_id, 10) = 0
) AS attempt_source;

INSERT INTO payment_attempt (
    payment_attempt_id,
    attempt_number,
    payment_id,
    attempt_sequence_number,
    attempted_at,
    attempted_amount_usd,
    payment_method_code,
    processing_branch_id
)
SELECT
    payment_attempt_id,
    attempt_number,
    payment_id,
    attempt_sequence_number,
    attempted_at,
    attempted_amount_usd,
    payment_method_code,
    processing_branch_id
FROM tmp_seed_attempt
ORDER BY payment_attempt_id;

CREATE TEMPORARY TABLE tmp_seed_attempt_status AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY status_source.payment_attempt_id, status_source.status_sequence
    ) AS payment_attempt_status_event_id,
    status_source.payment_attempt_id,
    status_source.attempt_status_code,
    DATE_ADD(
        status_source.attempted_at,
        INTERVAL status_source.minute_offset MINUTE
    ) AS status_at,
    status_source.reason_code
FROM (
    SELECT
        attempt.payment_attempt_id,
        attempt.attempted_at,
        1 AS status_sequence,
        'PENDING' AS attempt_status_code,
        0 AS minute_offset,
        NULL AS reason_code
    FROM payment_attempt AS attempt

    UNION ALL

    SELECT
        attempt.payment_attempt_id,
        attempt.attempted_at,
        2,
        CASE
            WHEN attempt.attempt_sequence_number = 1
             AND MOD(attempt.payment_id, 10) = 0
            THEN 'FAILED'
            ELSE 'SUCCESSFUL'
        END,
        1,
        CASE
            WHEN attempt.attempt_sequence_number = 1
             AND MOD(attempt.payment_id, 10) = 0
            THEN 'PROCESSOR_DECLINED'
            ELSE NULL
        END
    FROM payment_attempt AS attempt

    UNION ALL

    SELECT
        attempt.payment_attempt_id,
        attempt.attempted_at,
        3,
        'SETTLED',
        2,
        NULL
    FROM payment_attempt AS attempt
    WHERE NOT (
        attempt.attempt_sequence_number = 1
        AND MOD(attempt.payment_id, 10) = 0
    )
) AS status_source;

INSERT INTO payment_attempt_status_event (
    payment_attempt_status_event_id,
    payment_attempt_id,
    attempt_status_code,
    status_at,
    reason_code
)
SELECT
    payment_attempt_status_event_id,
    payment_attempt_id,
    attempt_status_code,
    status_at,
    reason_code
FROM tmp_seed_attempt_status
ORDER BY payment_attempt_status_event_id;

INSERT INTO payment_allocation (
    payment_allocation_id,
    payment_id,
    payment_obligation_id,
    allocated_amount_usd,
    recorded_at
)
SELECT
    payment.payment_id,
    payment.payment_id,
    payment.payment_obligation_id,
    payment.payment_amount_usd,
    DATE_ADD(successful_attempt.attempted_at, INTERVAL 3 MINUTE)
FROM tmp_seed_payment AS payment
JOIN tmp_seed_attempt AS successful_attempt
    ON successful_attempt.payment_id = payment.payment_id
   AND successful_attempt.failed_flag = 0
ORDER BY payment.payment_id;

-- ---------------------------------------------------------------------------
-- 6. Refund lifecycles and obligation reopening
-- ---------------------------------------------------------------------------

CREATE TEMPORARY TABLE tmp_seed_refund AS
SELECT
    ROW_NUMBER() OVER (ORDER BY refundable.payment_id) AS refund_id,
    CONCAT(
        'REF',
        LPAD(ROW_NUMBER() OVER (ORDER BY refundable.payment_id), 7, '0')
    ) AS refund_number,
    refundable.payment_id,
    DATE_ADD(refundable.collected_at, INTERVAL 10 DAY) AS requested_at,
    ROUND(refundable.allocated_amount_usd * 0.20, 2) AS refund_amount_usd,
    CASE MOD(refundable.payment_id, 3)
        WHEN 0 THEN 'SERVICE_DISSATISFACTION'
        WHEN 1 THEN 'MEDICAL'
        ELSE 'DUPLICATE_CHARGE_CLAIM'
    END AS refund_reason_code
FROM (
    SELECT
        allocation.payment_id,
        allocation.allocated_amount_usd,
        allocation.recorded_at AS collected_at
    FROM payment_allocation AS allocation
    WHERE allocation.recorded_at <= '2026-08-15 23:59:59.999999'
    ORDER BY allocation.payment_id
    LIMIT 200
) AS refundable;

INSERT INTO refund (
    refund_id,
    refund_number,
    payment_id,
    requested_at,
    refund_amount_usd,
    refund_reason_code
)
SELECT
    refund_id,
    refund_number,
    payment_id,
    requested_at,
    refund_amount_usd,
    refund_reason_code
FROM tmp_seed_refund
ORDER BY refund_id;

INSERT INTO refund_status_event (
    refund_status_event_id,
    refund_id,
    refund_status_code,
    status_at,
    status_reason_code
)
SELECT
    (refund.refund_id * 2) - 1,
    refund.refund_id,
    'PENDING',
    refund.requested_at,
    NULL
FROM tmp_seed_refund AS refund
ORDER BY refund.refund_id;

INSERT INTO refund_status_event (
    refund_status_event_id,
    refund_id,
    refund_status_code,
    status_at,
    status_reason_code
)
SELECT
    refund.refund_id * 2,
    refund.refund_id,
    CASE
        WHEN refund.refund_id <= 150 THEN 'COMPLETED'
        WHEN refund.refund_id <= 175 THEN 'FAILED'
        ELSE 'CANCELLED'
    END,
    DATE_ADD(refund.requested_at, INTERVAL 1 DAY),
    CASE
        WHEN refund.refund_id <= 150 THEN NULL
        WHEN refund.refund_id <= 175 THEN 'REVIEW_FAILED'
        ELSE 'MEMBER_WITHDREW_REQUEST'
    END
FROM tmp_seed_refund AS refund
ORDER BY refund.refund_id;

INSERT INTO refund_allocation (
    refund_allocation_id,
    refund_id,
    payment_allocation_id,
    refund_allocated_amount_usd,
    reopens_obligation_flag,
    recorded_at
)
SELECT
    refund.refund_id,
    refund.refund_id,
    allocation.payment_allocation_id,
    refund.refund_amount_usd,
    MOD(refund.refund_id, 3) = 0,
    DATE_ADD(refund.requested_at, INTERVAL 1 DAY)
FROM tmp_seed_refund AS refund
JOIN payment_allocation AS allocation
    ON allocation.payment_id = refund.payment_id
WHERE refund.refund_id <= 150
ORDER BY refund.refund_id;

-- ---------------------------------------------------------------------------
-- 7. Historical resolved Financial Exceptions
-- ---------------------------------------------------------------------------

INSERT INTO financial_exception (
    financial_exception_id,
    exception_number,
    affected_source_domain_code,
    affected_source_record_reference,
    exception_type_code,
    severity_code,
    affected_amount_usd,
    detected_at
)
SELECT
    number.n,
    CONCAT('EXC', LPAD(number.n, 7, '0')),
    'PAYMENT',
    payment.payment_number,
    'RECONCILIATION_DIFFERENCE',
    CASE WHEN MOD(number.n, 4) = 0 THEN 'WARNING' ELSE 'CRITICAL' END,
    payment.requested_amount_usd,
    DATE_ADD(payment.requested_at, INTERVAL 3 DAY)
FROM tmp_seed_number AS number
JOIN payment
    ON payment.payment_id = number.n
WHERE number.n <= 20;

INSERT INTO financial_exception_status_event (
    financial_exception_status_event_id,
    financial_exception_id,
    exception_status_code,
    status_at,
    assigned_owner_code,
    reporting_disposition_code,
    review_note,
    resolution_note
)
SELECT
    (exception_record.financial_exception_id * 3) - 2,
    exception_record.financial_exception_id,
    'OPEN',
    exception_record.detected_at,
    'FINANCE_REVIEW',
    'EXCLUDED',
    NULL,
    NULL
FROM financial_exception AS exception_record
ORDER BY exception_record.financial_exception_id;

INSERT INTO financial_exception_status_event (
    financial_exception_status_event_id,
    financial_exception_id,
    exception_status_code,
    status_at,
    assigned_owner_code,
    reporting_disposition_code,
    review_note,
    resolution_note
)
SELECT
    (exception_record.financial_exception_id * 3) - 1,
    exception_record.financial_exception_id,
    'UNDER_REVIEW',
    DATE_ADD(exception_record.detected_at, INTERVAL 1 DAY),
    'FINANCE_REVIEW',
    CASE
        WHEN exception_record.severity_code = 'WARNING'
        THEN 'INCLUDED_WITH_WARNING'
        ELSE 'EXCLUDED'
    END,
    'SOURCE LINKAGE AND AMOUNT VERIFIED DURING CONTROLLED REVIEW',
    NULL
FROM financial_exception AS exception_record
ORDER BY exception_record.financial_exception_id;

INSERT INTO financial_exception_status_event (
    financial_exception_status_event_id,
    financial_exception_id,
    exception_status_code,
    status_at,
    assigned_owner_code,
    reporting_disposition_code,
    review_note,
    resolution_note
)
SELECT
    exception_record.financial_exception_id * 3,
    exception_record.financial_exception_id,
    'RESOLVED',
    DATE_ADD(exception_record.detected_at, INTERVAL 2 DAY),
    'FINANCE_REVIEW',
    'ELIGIBLE',
    'SOURCE REVALIDATED',
    'CONTROLLED REVIEW CONFIRMED A VALID AND RECONCILED PAYMENT SOURCE'
FROM financial_exception AS exception_record
ORDER BY exception_record.financial_exception_id;

-- ---------------------------------------------------------------------------
-- 8. Valid Check-Ins and controlled quality scenarios
-- ---------------------------------------------------------------------------

CREATE TEMPORARY TABLE tmp_seed_check_in_contract AS
SELECT
    contract.membership_contract_id,
    contract.member_id,
    contract.financial_ownership_branch_id,
    contract.service_start_date,
    LEAST(contract.original_end_date, DATE('2026-08-31')) AS reporting_end_date,
    ROW_NUMBER() OVER (ORDER BY contract.membership_contract_id) AS contract_sequence
FROM membership_contract AS contract
WHERE contract.membership_contract_id <= 1000
   OR contract.membership_contract_id > 2500;

CREATE TEMPORARY TABLE tmp_seed_check_in_valid AS
SELECT
    number.n AS check_in_id,
    CONCAT('CHK', LPAD(number.n, 8, '0')) AS source_check_in_reference,
    contract.member_id,
    CASE
        WHEN MOD(number.n, 5) = 0
        THEN 1 + MOD(contract.financial_ownership_branch_id, 3)
        ELSE contract.financial_ownership_branch_id
    END AS visited_branch_id,
    CONVERT_TZ(
        TIMESTAMP(
            DATE_ADD(
                contract.service_start_date,
                INTERVAL FLOOR(
                    MOD(number.n - 1, 30)
                    * DATEDIFF(contract.reporting_end_date, contract.service_start_date)
                    / 29
                ) DAY
            ),
            MAKETIME(6 + MOD(number.n, 16), MOD(number.n * 7, 60), 0)
        ),
        'Asia/Beirut',
        '+00:00'
    ) AS check_in_at
FROM tmp_seed_number AS number
JOIN tmp_seed_check_in_contract AS contract
    ON contract.contract_sequence = 1 + FLOOR((number.n - 1) / 30)
WHERE number.n <= 60000;

INSERT INTO check_in (
    check_in_id,
    source_check_in_reference,
    member_id,
    visited_branch_id,
    check_in_at,
    recorded_at
)
SELECT
    check_in_id,
    source_check_in_reference,
    member_id,
    visited_branch_id,
    check_in_at,
    DATE_ADD(check_in_at, INTERVAL 5 MINUTE)
FROM tmp_seed_check_in_valid
ORDER BY check_in_id;

-- Duplicate source references: the later row is blocked by a matching open issue.
INSERT INTO check_in (
    check_in_id,
    source_check_in_reference,
    member_id,
    visited_branch_id,
    check_in_at,
    recorded_at
)
SELECT
    60000 + original.check_in_id,
    original.source_check_in_reference,
    original.member_id,
    original.visited_branch_id,
    original.check_in_at,
    DATE_ADD(original.recorded_at, INTERVAL 1 MINUTE)
FROM check_in AS original
WHERE original.check_in_id <= 100
ORDER BY original.check_in_id;

INSERT INTO check_in_quality_issue (
    check_in_quality_issue_id,
    check_in_id,
    issue_code,
    detected_at,
    resolved_at,
    resolution_note
)
SELECT
    original.check_in_id,
    60000 + original.check_in_id,
    'DUPLICATE_SOURCE_REFERENCE',
    DATE_ADD(original.recorded_at, INTERVAL 1 MINUTE),
    NULL,
    NULL
FROM check_in AS original
WHERE original.check_in_id <= 100
ORDER BY original.check_in_id;

-- Missing source reference.
INSERT INTO check_in (
    check_in_id,
    source_check_in_reference,
    member_id,
    visited_branch_id,
    check_in_at,
    recorded_at
)
SELECT
    60100 + number.n,
    NULL,
    valid.member_id,
    valid.visited_branch_id,
    valid.check_in_at,
    DATE_ADD(valid.recorded_at, INTERVAL 2 MINUTE)
FROM tmp_seed_number AS number
JOIN check_in AS valid ON valid.check_in_id = 100 + number.n
WHERE number.n <= 25;

INSERT INTO check_in_quality_issue
SELECT
    100 + number.n,
    60100 + number.n,
    'MISSING_SOURCE_REFERENCE',
    DATE_ADD(valid.recorded_at, INTERVAL 2 MINUTE),
    NULL,
    NULL
FROM tmp_seed_number AS number
JOIN check_in AS valid ON valid.check_in_id = 100 + number.n
WHERE number.n <= 25;

-- Unmatched Member reference.
INSERT INTO check_in
SELECT
    60125 + number.n,
    CONCAT('CHK-UNMATCHED-MEMBER-', LPAD(number.n, 3, '0')),
    NULL,
    valid.visited_branch_id,
    valid.check_in_at,
    DATE_ADD(valid.recorded_at, INTERVAL 3 MINUTE)
FROM tmp_seed_number AS number
JOIN check_in AS valid ON valid.check_in_id = 200 + number.n
WHERE number.n <= 25;

INSERT INTO check_in_quality_issue
SELECT
    125 + number.n,
    60125 + number.n,
    'UNMATCHED_MEMBER_REFERENCE',
    DATE_ADD(valid.recorded_at, INTERVAL 3 MINUTE),
    NULL,
    NULL
FROM tmp_seed_number AS number
JOIN check_in AS valid ON valid.check_in_id = 200 + number.n
WHERE number.n <= 25;

-- Unmatched Visited Branch reference.
INSERT INTO check_in
SELECT
    60150 + number.n,
    CONCAT('CHK-UNMATCHED-BRANCH-', LPAD(number.n, 3, '0')),
    valid.member_id,
    NULL,
    valid.check_in_at,
    DATE_ADD(valid.recorded_at, INTERVAL 4 MINUTE)
FROM tmp_seed_number AS number
JOIN check_in AS valid ON valid.check_in_id = 300 + number.n
WHERE number.n <= 25;

INSERT INTO check_in_quality_issue
SELECT
    150 + number.n,
    60150 + number.n,
    'UNMATCHED_VISITED_BRANCH_REFERENCE',
    DATE_ADD(valid.recorded_at, INTERVAL 4 MINUTE),
    NULL,
    NULL
FROM tmp_seed_number AS number
JOIN check_in AS valid ON valid.check_in_id = 300 + number.n
WHERE number.n <= 25;

-- Missing Check-In timestamp.
INSERT INTO check_in
SELECT
    60175 + number.n,
    CONCAT('CHK-MISSING-TIME-', LPAD(number.n, 3, '0')),
    valid.member_id,
    valid.visited_branch_id,
    NULL,
    DATE_ADD(valid.recorded_at, INTERVAL 5 MINUTE)
FROM tmp_seed_number AS number
JOIN check_in AS valid ON valid.check_in_id = 400 + number.n
WHERE number.n <= 25;

INSERT INTO check_in_quality_issue
SELECT
    175 + number.n,
    60175 + number.n,
    'MISSING_CHECK_IN_TIMESTAMP',
    DATE_ADD(valid.recorded_at, INTERVAL 5 MINUTE),
    NULL,
    NULL
FROM tmp_seed_number AS number
JOIN check_in AS valid ON valid.check_in_id = 400 + number.n
WHERE number.n <= 25;

COMMIT;

DROP TEMPORARY TABLE tmp_seed_check_in_valid;
DROP TEMPORARY TABLE tmp_seed_check_in_contract;
DROP TEMPORARY TABLE tmp_seed_refund;
DROP TEMPORARY TABLE tmp_seed_attempt_status;
DROP TEMPORARY TABLE tmp_seed_attempt;
DROP TEMPORARY TABLE tmp_seed_payment;
DROP TEMPORARY TABLE tmp_seed_obligation;
DROP TEMPORARY TABLE tmp_seed_continuation;
DROP TEMPORARY TABLE tmp_seed_contract;
DROP TEMPORARY TABLE tmp_seed_member;
DROP TEMPORARY TABLE tmp_seed_number;

SELECT
    'PDM025_SYNTHETIC_DATASET_LOAD' AS load_control,
    'COMPLETE' AS load_result,
    'Run 98_validate_synthetic_dataset.sql next' AS next_step;
