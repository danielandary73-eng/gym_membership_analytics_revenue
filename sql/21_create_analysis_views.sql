-- Gym Membership & Revenue Analytics System
-- SQLA-003: controlled read-only analytical views
-- Prerequisite: complete the approved Phase 7 build, role package, synthetic load,
-- and data-bearing validation before running this file.

USE gym_membership_analytics;

-- Repeatable rebuild in reverse dependency order.
DROP VIEW IF EXISTS vw_analysis_refund;
DROP VIEW IF EXISTS vw_analysis_obligation_activity;
DROP VIEW IF EXISTS vw_analysis_payment_attempt_final;
DROP VIEW IF EXISTS vw_analysis_membership_daily_snapshot;
DROP VIEW IF EXISTS vw_analysis_membership_contract;
DROP VIEW IF EXISTS vw_analysis_membership_status_event;
DROP VIEW IF EXISTS vw_analysis_home_branch_assignment;
DROP VIEW IF EXISTS vw_analysis_membership_plan_version;
DROP VIEW IF EXISTS vw_analysis_branch;
DROP VIEW IF EXISTS vw_analysis_date;

-- 1. Deterministic calendar with one opening anchor and a 60-day planning horizon.
CREATE VIEW vw_analysis_date AS
WITH digit AS (
    SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL
    SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL
    SELECT 8 UNION ALL SELECT 9
), sequence_number AS (
    SELECT
        ones.n
        + tens.n * 10
        + hundreds.n * 100
        + thousands.n * 1000 AS n
    FROM digit AS ones
    CROSS JOIN digit AS tens
    CROSS JOIN digit AS hundreds
    CROSS JOIN digit AS thousands
), calendar AS (
    SELECT DATE_ADD(DATE('2023-08-31'), INTERVAL sequence_number.n DAY) AS calendar_date
    FROM sequence_number
    WHERE sequence_number.n <= DATEDIFF(DATE('2026-10-30'), DATE('2023-08-31'))
)
SELECT
    calendar_date,
    CAST(YEAR(calendar_date) AS UNSIGNED) AS calendar_year,
    CAST(QUARTER(calendar_date) AS UNSIGNED) AS calendar_quarter_number,
    CAST(MONTH(calendar_date) AS UNSIGNED) AS calendar_month_number,
    MONTHNAME(calendar_date) AS calendar_month_name,
    DATE_FORMAT(calendar_date, '%Y-%m') AS calendar_year_month,
    DATE_SUB(calendar_date, INTERVAL DAYOFMONTH(calendar_date) - 1 DAY) AS month_start_date,
    LAST_DAY(calendar_date) AS month_end_date,
    CAST(WEEKDAY(calendar_date) + 1 AS UNSIGNED) AS weekday_number_monday_1,
    DAYNAME(calendar_date) AS weekday_name,
    DATE_SUB(
        DATE_SUB(calendar_date, INTERVAL DAYOFMONTH(calendar_date) - 1 DAY),
        INTERVAL 1 MONTH
    ) AS previous_month_start_date,
    DATE_SUB(
        DATE_SUB(calendar_date, INTERVAL DAYOFMONTH(calendar_date) - 1 DAY),
        INTERVAL 1 YEAR
    ) AS previous_year_month_start_date,
    (calendar_date BETWEEN DATE('2023-09-01') AND DATE('2026-08-31'))
        AS reporting_scope_flag,
    (calendar_date = DATE('2023-08-31')) AS opening_anchor_flag,
    (calendar_date BETWEEN DATE('2026-09-01') AND DATE('2026-10-30'))
        AS forward_planning_scope_flag
FROM calendar;

-- 2. Approved Branch dimension.
CREATE VIEW vw_analysis_branch AS
SELECT
    branch.branch_id,
    branch.branch_code,
    branch.branch_name,
    branch.city_name,
    branch.opened_date,
    branch.closed_date,
    (
        branch.opened_date <= DATE('2026-08-31')
        AND (branch.closed_date IS NULL OR branch.closed_date >= DATE('2026-08-31'))
    ) AS active_at_reporting_end_flag
FROM branch;

-- 3. Historical Membership Plan Version dimension.
CREATE VIEW vw_analysis_membership_plan_version AS
SELECT
    plan_version.plan_version_id,
    plan.plan_id,
    plan.plan_code,
    plan_version.plan_name,
    plan_version.standard_duration_months,
    plan_version.standard_price_usd,
    plan_version.available_from_date,
    plan_version.available_to_date,
    (
        plan_version.available_from_date <= DATE('2026-08-31')
        AND (
            plan_version.available_to_date IS NULL
            OR plan_version.available_to_date >= DATE('2026-08-31')
        )
    ) AS available_at_reporting_end_flag
FROM membership_plan_version AS plan_version
JOIN membership_plan AS plan
    ON plan.plan_id = plan_version.plan_id;

-- 4. Valid Home Branch assignment intervals with explicit transfer lineage.
CREATE VIEW vw_analysis_home_branch_assignment AS
WITH valid_assignment AS (
    SELECT assignment.*
    FROM member_branch_assignment AS assignment
    WHERE NOT EXISTS (
        SELECT 1
        FROM vw_dq_home_branch_assignment_overlap AS issue
        WHERE issue.member_id = assignment.member_id
    )
), sequenced_assignment AS (
    SELECT
        assignment.*,
        LAG(assignment.member_branch_assignment_id) OVER (
            PARTITION BY assignment.member_id
            ORDER BY assignment.effective_start_date,
                     assignment.member_branch_assignment_id
        ) AS previous_member_branch_assignment_id,
        LAG(assignment.home_branch_id) OVER (
            PARTITION BY assignment.member_id
            ORDER BY assignment.effective_start_date,
                     assignment.member_branch_assignment_id
        ) AS previous_home_branch_id
    FROM valid_assignment AS assignment
)
SELECT
    assignment.member_branch_assignment_id,
    assignment.member_id,
    member.member_number,
    assignment.home_branch_id,
    home_branch.branch_code AS home_branch_code,
    home_branch.branch_name AS home_branch_name,
    assignment.effective_start_date,
    assignment.effective_end_date,
    assignment.previous_member_branch_assignment_id,
    assignment.previous_home_branch_id,
    previous_branch.branch_code AS previous_home_branch_code,
    previous_branch.branch_name AS previous_home_branch_name,
    (assignment.previous_member_branch_assignment_id IS NULL) AS initial_assignment_flag,
    (
        assignment.previous_member_branch_assignment_id IS NOT NULL
        AND assignment.previous_home_branch_id <> assignment.home_branch_id
    ) AS transfer_event_flag
FROM sequenced_assignment AS assignment
JOIN member
    ON member.member_id = assignment.member_id
JOIN vw_analysis_branch AS home_branch
    ON home_branch.branch_id = assignment.home_branch_id
LEFT JOIN vw_analysis_branch AS previous_branch
    ON previous_branch.branch_id = assignment.previous_home_branch_id;

-- 5. Currently approved, non-reversed Cancellation and Freeze events.
CREATE VIEW vw_analysis_membership_status_event AS
WITH ranked_decision AS (
    SELECT
        decision.membership_status_decision_event_id,
        decision.membership_status_event_id,
        decision.decision_status_code,
        decision.decision_at,
        ROW_NUMBER() OVER (
            PARTITION BY decision.membership_status_event_id
            ORDER BY decision.decision_at DESC,
                     decision.membership_status_decision_event_id DESC
        ) AS latest_rank
    FROM membership_status_decision_event AS decision
), approved_event AS (
    SELECT
        status_event.*,
        decision.membership_status_decision_event_id AS latest_decision_event_id,
        decision.decision_status_code AS latest_decision_status_code,
        decision.decision_at AS latest_decision_at
    FROM membership_status_event AS status_event
    JOIN ranked_decision AS decision
        ON decision.membership_status_event_id = status_event.membership_status_event_id
       AND decision.latest_rank = 1
       AND decision.decision_status_code = 'APPROVED'
    WHERE NOT EXISTS (
        SELECT 1
        FROM vw_dq_membership_decision_integrity AS issue
        WHERE issue.membership_status_event_id = status_event.membership_status_event_id
    )
      AND NOT EXISTS (
        SELECT 1
        FROM vw_dq_membership_status_integrity AS issue
        WHERE issue.membership_contract_id = status_event.membership_contract_id
    )
), active_event AS (
    SELECT approved.*
    FROM approved_event AS approved
    WHERE NOT EXISTS (
        SELECT 1
        FROM approved_event AS reversal
        WHERE reversal.event_type_code = 'REVERSAL'
          AND reversal.reverses_membership_status_event_id
              = approved.membership_status_event_id
    )
)
SELECT
    active_event.membership_status_event_id,
    active_event.membership_contract_id,
    active_event.event_type_code,
    active_event.recorded_at AS recorded_at_utc,
    CONVERT_TZ(active_event.recorded_at, '+00:00', 'Asia/Beirut')
        AS recorded_at_beirut,
    active_event.effective_start_date,
    active_event.effective_end_date,
    active_event.reason_code,
    active_event.latest_decision_event_id,
    active_event.latest_decision_status_code,
    active_event.latest_decision_at AS latest_decision_at_utc,
    CONVERT_TZ(active_event.latest_decision_at, '+00:00', 'Asia/Beirut')
        AS latest_decision_at_beirut,
    CAST(
        CASE
            WHEN active_event.event_type_code = 'FREEZE'
            THEN DATEDIFF(active_event.effective_end_date, active_event.effective_start_date) + 1
            ELSE 0
        END AS UNSIGNED
    ) AS freeze_duration_days
FROM active_event
WHERE active_event.event_type_code IN ('CANCELLATION', 'FREEZE');

-- 6. Valid Contract lifecycle and Contract-value fact.
CREATE VIEW vw_analysis_membership_contract AS
WITH event_summary AS (
    SELECT
        status_event.membership_contract_id,
        SUM(
            CASE WHEN status_event.event_type_code = 'FREEZE'
                 THEN status_event.freeze_duration_days ELSE 0 END
        ) AS approved_freeze_days,
        MIN(
            CASE WHEN status_event.event_type_code = 'CANCELLATION'
                 THEN status_event.effective_start_date END
        ) AS cancellation_effective_date
    FROM vw_analysis_membership_status_event AS status_event
    GROUP BY status_event.membership_contract_id
), valid_contract AS (
    SELECT contract.*
    FROM membership_contract AS contract
    WHERE NOT EXISTS (
        SELECT 1
        FROM vw_dq_contract_integrity AS issue
        WHERE issue.membership_contract_id = contract.membership_contract_id
    )
      AND NOT EXISTS (
        SELECT 1
        FROM vw_dq_contract_service_overlap AS issue
        WHERE issue.left_membership_contract_id = contract.membership_contract_id
           OR issue.right_membership_contract_id = contract.membership_contract_id
    )
      AND NOT EXISTS (
        SELECT 1
        FROM vw_dq_membership_status_integrity AS issue
        WHERE issue.membership_contract_id = contract.membership_contract_id
    )
), contract_enriched AS (
    SELECT
        contract.*,
        member.member_number,
        plan.plan_id,
        plan.plan_code,
        plan.plan_name,
        financial_branch.branch_code AS financial_ownership_branch_code,
        financial_branch.branch_name AS financial_ownership_branch_name,
        home_assignment.home_branch_id AS home_branch_at_start_id,
        home_assignment.home_branch_code AS home_branch_at_start_code,
        home_assignment.home_branch_name AS home_branch_at_start_name,
        CAST(COALESCE(summary.approved_freeze_days, 0) AS UNSIGNED)
            AS approved_freeze_days,
        DATE_ADD(
            contract.original_end_date,
            INTERVAL COALESCE(summary.approved_freeze_days, 0) DAY
        ) AS effective_end_date,
        summary.cancellation_effective_date
    FROM valid_contract AS contract
    JOIN member
        ON member.member_id = contract.member_id
    JOIN vw_analysis_membership_plan_version AS plan
        ON plan.plan_version_id = contract.plan_version_id
    JOIN vw_analysis_branch AS financial_branch
        ON financial_branch.branch_id = contract.financial_ownership_branch_id
    JOIN vw_analysis_home_branch_assignment AS home_assignment
        ON home_assignment.member_id = contract.member_id
       AND home_assignment.effective_start_date <= contract.service_start_date
       AND (
           home_assignment.effective_end_date IS NULL
           OR home_assignment.effective_end_date >= contract.service_start_date
       )
    LEFT JOIN event_summary AS summary
        ON summary.membership_contract_id = contract.membership_contract_id
)
SELECT
    contract.membership_contract_id,
    contract.contract_number,
    contract.member_id,
    contract.member_number,
    contract.plan_version_id,
    contract.plan_id,
    contract.plan_code,
    contract.plan_name,
    contract.financial_ownership_branch_id,
    contract.financial_ownership_branch_code,
    contract.financial_ownership_branch_name,
    contract.home_branch_at_start_id,
    contract.home_branch_at_start_code,
    contract.home_branch_at_start_name,
    contract.previous_membership_contract_id,
    predecessor.contract_number AS previous_contract_number,
    CASE
        WHEN contract.previous_membership_contract_id IS NULL THEN 'NEW_MEMBERSHIP'
        WHEN contract.service_start_date
             = DATE_ADD(predecessor.effective_end_date, INTERVAL 1 DAY)
        THEN 'DIRECT_RENEWAL'
        ELSE 'REACTIVATION'
    END AS contract_classification_code,
    contract.contract_created_date,
    contract.service_start_date,
    contract.original_end_date,
    contract.approved_freeze_days,
    contract.effective_end_date,
    contract.cancellation_effective_date,
    contract.historical_list_price_usd,
    contract.discount_amount_usd,
    contract.historical_list_price_usd - contract.discount_amount_usd
        AS expected_revenue_usd,
    contract.payment_schedule_type_code
FROM contract_enriched AS contract
LEFT JOIN contract_enriched AS predecessor
    ON predecessor.membership_contract_id = contract.previous_membership_contract_id;

-- 7. Daily Contract status snapshot for the opening anchor and 36 reporting months.
CREATE VIEW vw_analysis_membership_daily_snapshot AS
SELECT
    reporting_date.calendar_date AS snapshot_date,
    contract.membership_contract_id,
    contract.contract_number,
    contract.member_id,
    contract.member_number,
    contract.plan_version_id,
    contract.plan_id,
    contract.plan_code,
    contract.plan_name,
    home_assignment.home_branch_id,
    home_assignment.home_branch_code,
    home_assignment.home_branch_name,
    contract.financial_ownership_branch_id,
    contract.service_start_date,
    contract.effective_end_date,
    contract.cancellation_effective_date,
    CASE
        WHEN contract.cancellation_effective_date IS NOT NULL
         AND contract.cancellation_effective_date <= reporting_date.calendar_date
        THEN 'CANCELLED'
        WHEN reporting_date.calendar_date < contract.service_start_date
        THEN 'NOT_STARTED'
        WHEN freeze_event.membership_status_event_id IS NOT NULL
        THEN 'FROZEN'
        WHEN reporting_date.calendar_date <= contract.effective_end_date
        THEN 'ACTIVE'
        ELSE 'EXPIRED'
    END AS membership_status_code,
    (
        (contract.cancellation_effective_date IS NULL
         OR contract.cancellation_effective_date > reporting_date.calendar_date)
        AND reporting_date.calendar_date >= contract.service_start_date
        AND reporting_date.calendar_date <= contract.effective_end_date
        AND freeze_event.membership_status_event_id IS NULL
    ) AS active_contract_flag,
    (
        (contract.cancellation_effective_date IS NULL
         OR contract.cancellation_effective_date > reporting_date.calendar_date)
        AND reporting_date.calendar_date >= contract.service_start_date
        AND reporting_date.calendar_date <= contract.effective_end_date
    ) AS live_contract_flag,
    (
        (contract.cancellation_effective_date IS NULL
         OR contract.cancellation_effective_date > reporting_date.calendar_date)
        AND reporting_date.calendar_date >= contract.service_start_date
        AND reporting_date.calendar_date <= contract.effective_end_date
        AND freeze_event.membership_status_event_id IS NULL
    ) AS active_member_flag,
    (
        (contract.cancellation_effective_date IS NULL
         OR contract.cancellation_effective_date > reporting_date.calendar_date)
        AND reporting_date.calendar_date >= contract.service_start_date
        AND reporting_date.calendar_date <= contract.effective_end_date
    ) AS live_member_flag,
    CAST(DATEDIFF(contract.effective_end_date, reporting_date.calendar_date) AS SIGNED)
        AS days_to_effective_end,
    (
        (contract.cancellation_effective_date IS NULL
         OR contract.cancellation_effective_date > reporting_date.calendar_date)
        AND reporting_date.calendar_date >= contract.service_start_date
        AND reporting_date.calendar_date <= contract.effective_end_date
        AND DATEDIFF(contract.effective_end_date, reporting_date.calendar_date)
            BETWEEN 1 AND 30
        AND renewal.membership_contract_id IS NULL
    ) AS expiring_1_30_day_flag,
    (
        (contract.cancellation_effective_date IS NULL
         OR contract.cancellation_effective_date > reporting_date.calendar_date)
        AND reporting_date.calendar_date >= contract.service_start_date
        AND reporting_date.calendar_date <= contract.effective_end_date
        AND DATEDIFF(contract.effective_end_date, reporting_date.calendar_date)
            BETWEEN 31 AND 60
        AND renewal.membership_contract_id IS NULL
    ) AS expiring_31_60_day_flag
FROM vw_analysis_date AS reporting_date
CROSS JOIN vw_analysis_membership_contract AS contract
LEFT JOIN vw_analysis_membership_status_event AS freeze_event
    ON freeze_event.membership_contract_id = contract.membership_contract_id
   AND freeze_event.event_type_code = 'FREEZE'
   AND reporting_date.calendar_date
       BETWEEN freeze_event.effective_start_date AND freeze_event.effective_end_date
LEFT JOIN vw_analysis_home_branch_assignment AS home_assignment
    ON home_assignment.member_id = contract.member_id
   AND home_assignment.effective_start_date <= reporting_date.calendar_date
   AND (
       home_assignment.effective_end_date IS NULL
       OR home_assignment.effective_end_date >= reporting_date.calendar_date
   )
LEFT JOIN vw_analysis_membership_contract AS renewal
    ON renewal.previous_membership_contract_id = contract.membership_contract_id
   AND renewal.contract_classification_code = 'DIRECT_RENEWAL'
WHERE reporting_date.opening_anchor_flag = 1
   OR reporting_date.reporting_scope_flag = 1;

-- 8. One final current state per eligible Payment Attempt.
CREATE VIEW vw_analysis_payment_attempt_final AS
WITH ranked_status AS (
    SELECT
        status_event.payment_attempt_status_event_id,
        status_event.payment_attempt_id,
        status_event.attempt_status_code,
        status_event.status_at,
        status_event.reason_code,
        ROW_NUMBER() OVER (
            PARTITION BY status_event.payment_attempt_id
            ORDER BY status_event.status_at DESC,
                     status_event.payment_attempt_status_event_id DESC
        ) AS latest_rank
    FROM payment_attempt_status_event AS status_event
), current_disposition AS (
    SELECT disposition.*
    FROM vw_reporting_financial_source_disposition AS disposition
    WHERE disposition.effective_from <= UTC_TIMESTAMP(6)
      AND (
          disposition.effective_to IS NULL
          OR disposition.effective_to > UTC_TIMESTAMP(6)
      )
), disposition_summary AS (
    SELECT
        attempt.payment_attempt_id,
        MAX(
            CASE disposition.reporting_disposition_code
                WHEN 'EXCLUDED' THEN 2
                WHEN 'INCLUDED_WITH_WARNING' THEN 1
                ELSE 0
            END
        ) AS worst_disposition_rank
    FROM payment_attempt AS attempt
    JOIN payment
        ON payment.payment_id = attempt.payment_id
    JOIN vw_analysis_membership_contract AS contract
        ON contract.membership_contract_id = payment.membership_contract_id
    LEFT JOIN current_disposition AS disposition
        ON (
            disposition.affected_source_domain_code = 'PAYMENT_ATTEMPT'
            AND disposition.affected_source_record_reference = attempt.attempt_number
        ) OR (
            disposition.affected_source_domain_code = 'PAYMENT'
            AND disposition.affected_source_record_reference = payment.payment_number
        ) OR (
            disposition.affected_source_domain_code = 'CONTRACT'
            AND disposition.affected_source_record_reference = contract.contract_number
        )
    GROUP BY attempt.payment_attempt_id
)
SELECT
    attempt.payment_attempt_id,
    attempt.attempt_number,
    payment.payment_id,
    payment.payment_number,
    contract.membership_contract_id,
    contract.contract_number,
    contract.member_id,
    contract.plan_version_id,
    contract.financial_ownership_branch_id,
    attempt.attempt_sequence_number,
    attempt.attempted_at AS attempted_at_utc,
    CONVERT_TZ(attempt.attempted_at, '+00:00', 'Asia/Beirut') AS attempted_at_beirut,
    DATE(CONVERT_TZ(attempt.attempted_at, '+00:00', 'Asia/Beirut'))
        AS attempt_date_beirut,
    attempt.attempted_amount_usd,
    attempt.payment_method_code,
    attempt.processing_branch_id,
    processing_branch.branch_code AS processing_branch_code,
    processing_branch.branch_name AS processing_branch_name,
    final_status.payment_attempt_status_event_id AS final_status_event_id,
    final_status.attempt_status_code AS final_attempt_status_code,
    final_status.status_at AS final_status_at_utc,
    CONVERT_TZ(final_status.status_at, '+00:00', 'Asia/Beirut')
        AS final_status_at_beirut,
    final_status.reason_code AS final_reason_code,
    (final_status.attempt_status_code IN ('SUCCESSFUL', 'SETTLED', 'FAILED'))
        AS finalized_attempt_flag,
    (final_status.attempt_status_code = 'FAILED') AS failed_attempt_flag,
    (COALESCE(disposition.worst_disposition_rank, 0) = 1)
        AS reporting_warning_flag
FROM payment_attempt AS attempt
JOIN payment
    ON payment.payment_id = attempt.payment_id
JOIN vw_analysis_membership_contract AS contract
    ON contract.membership_contract_id = payment.membership_contract_id
JOIN ranked_status AS final_status
    ON final_status.payment_attempt_id = attempt.payment_attempt_id
   AND final_status.latest_rank = 1
JOIN vw_analysis_branch AS processing_branch
    ON processing_branch.branch_id = attempt.processing_branch_id
JOIN disposition_summary AS disposition
    ON disposition.payment_attempt_id = attempt.payment_attempt_id
WHERE COALESCE(disposition.worst_disposition_rank, 0) < 2
  AND NOT EXISTS (
      SELECT 1
      FROM vw_dq_payment_attempt_integrity AS issue
      WHERE issue.payment_attempt_id = attempt.payment_attempt_id
         OR (
             issue.payment_attempt_id IS NULL
             AND issue.payment_id = payment.payment_id
         )
  )
  AND NOT EXISTS (
      SELECT 1
      FROM vw_dq_financial_source_issue AS source_issue
      WHERE (
          source_issue.affected_source_domain_code = 'PAYMENT_ATTEMPT'
          AND source_issue.affected_source_record_reference = attempt.attempt_number
      ) OR (
          source_issue.affected_source_domain_code = 'PAYMENT'
          AND source_issue.affected_source_record_reference = payment.payment_number
      ) OR (
          source_issue.affected_source_domain_code = 'CONTRACT'
          AND source_issue.affected_source_record_reference = contract.contract_number
      )
  );

-- 9. Dated balance-changing activity ledger for reproducible as-of balances.
CREATE VIEW vw_analysis_obligation_activity AS
SELECT
    CONCAT('OBLIGATION:', balance.payment_obligation_id) AS obligation_activity_key,
    'ORIGINAL_OBLIGATION' AS obligation_activity_type_code,
    contract.contract_created_date AS activity_date,
    CAST(NULL AS DATETIME(6)) AS activity_at_utc,
    CAST(NULL AS DATETIME(6)) AS activity_at_beirut,
    balance.payment_obligation_id,
    balance.obligation_number,
    balance.obligation_sequence_number,
    balance.due_date,
    balance.membership_contract_id,
    balance.contract_number,
    balance.member_id,
    balance.plan_version_id,
    balance.financial_ownership_branch_id,
    balance.payment_obligation_id AS source_record_id,
    balance.obligation_number AS source_record_reference,
    balance.original_obligation_amount_usd AS activity_amount_usd,
    balance.original_obligation_amount_usd AS balance_effect_amount_usd,
    FALSE AS cancelled_amount_flag,
    FALSE AS gross_application_flag,
    FALSE AS refund_reopening_flag,
    balance.reporting_warning_flag
FROM vw_reporting_obligation_balance AS balance
JOIN vw_analysis_membership_contract AS contract
    ON contract.membership_contract_id = balance.membership_contract_id

UNION ALL

SELECT
    CONCAT('CANCELLATION_ADJUSTMENT:', adjustment.payment_obligation_adjustment_id),
    'CANCELLATION_ADJUSTMENT',
    cancellation.effective_start_date,
    adjustment.recorded_at,
    CONVERT_TZ(adjustment.recorded_at, '+00:00', 'Asia/Beirut'),
    balance.payment_obligation_id,
    balance.obligation_number,
    balance.obligation_sequence_number,
    balance.due_date,
    balance.membership_contract_id,
    balance.contract_number,
    balance.member_id,
    balance.plan_version_id,
    balance.financial_ownership_branch_id,
    adjustment.payment_obligation_adjustment_id,
    CAST(adjustment.payment_obligation_adjustment_id AS CHAR),
    adjustment.adjustment_amount_usd,
    -adjustment.adjustment_amount_usd,
    TRUE,
    FALSE,
    FALSE,
    balance.reporting_warning_flag
FROM payment_obligation_adjustment AS adjustment
JOIN vw_reporting_obligation_balance AS balance
    ON balance.payment_obligation_id = adjustment.payment_obligation_id
JOIN vw_analysis_membership_status_event AS cancellation
    ON cancellation.membership_status_event_id = adjustment.membership_status_event_id
   AND cancellation.event_type_code = 'CANCELLATION'
WHERE NOT EXISTS (
    SELECT 1
    FROM vw_dq_financial_source_issue AS source_issue
    WHERE source_issue.affected_source_domain_code = 'OBLIGATION_ADJUSTMENT'
      AND source_issue.affected_source_record_reference
          = CAST(adjustment.payment_obligation_adjustment_id AS CHAR)
)
  AND NOT EXISTS (
      SELECT 1
      FROM vw_reporting_financial_source_disposition AS disposition
      WHERE disposition.effective_from <= UTC_TIMESTAMP(6)
        AND (disposition.effective_to IS NULL
             OR disposition.effective_to > UTC_TIMESTAMP(6))
        AND disposition.reporting_disposition_code = 'EXCLUDED'
        AND disposition.affected_source_domain_code = 'OBLIGATION_ADJUSTMENT'
        AND disposition.affected_source_record_reference
            = CAST(adjustment.payment_obligation_adjustment_id AS CHAR)
  )

UNION ALL

SELECT
    CONCAT('GROSS_APPLICATION:', gross.payment_allocation_id),
    'GROSS_APPLICATION',
    DATE(gross.collected_at_beirut),
    gross.collected_at_utc,
    gross.collected_at_beirut,
    balance.payment_obligation_id,
    balance.obligation_number,
    balance.obligation_sequence_number,
    balance.due_date,
    balance.membership_contract_id,
    balance.contract_number,
    balance.member_id,
    balance.plan_version_id,
    balance.financial_ownership_branch_id,
    gross.payment_allocation_id,
    CAST(gross.payment_allocation_id AS CHAR),
    gross.gross_collected_amount_usd,
    -gross.gross_collected_amount_usd,
    FALSE,
    TRUE,
    FALSE,
    (gross.reporting_warning_flag = 1 OR balance.reporting_warning_flag = 1)
FROM vw_reporting_gross_collected_revenue AS gross
JOIN vw_reporting_obligation_balance AS balance
    ON balance.payment_obligation_id = gross.payment_obligation_id

UNION ALL

SELECT
    CONCAT('REFUND_REOPENING:', refund.refund_allocation_id),
    'REFUND_REOPENING',
    DATE(refund.refunded_at_beirut),
    refund.refunded_at_utc,
    refund.refunded_at_beirut,
    balance.payment_obligation_id,
    balance.obligation_number,
    balance.obligation_sequence_number,
    balance.due_date,
    balance.membership_contract_id,
    balance.contract_number,
    balance.member_id,
    balance.plan_version_id,
    balance.financial_ownership_branch_id,
    refund.refund_allocation_id,
    CAST(refund.refund_allocation_id AS CHAR),
    refund.refund_amount_usd,
    refund.refund_amount_usd,
    FALSE,
    FALSE,
    TRUE,
    (refund.reporting_warning_flag = 1 OR balance.reporting_warning_flag = 1)
FROM vw_reporting_refund AS refund
JOIN vw_reporting_obligation_balance AS balance
    ON balance.payment_obligation_id = refund.payment_obligation_id
WHERE refund.reopens_obligation_flag = 1;

-- 10. Eligible completed Refund Allocation with its recorded reason.
CREATE VIEW vw_analysis_refund AS
SELECT
    reporting.refund_allocation_id,
    reporting.refund_id,
    reporting.refund_number,
    refund.refund_reason_code,
    reporting.refund_amount_usd,
    reporting.reopens_obligation_flag,
    reporting.refunded_at_utc,
    reporting.refunded_at_beirut,
    DATE(reporting.refunded_at_beirut) AS refund_date_beirut,
    reporting.payment_id,
    reporting.payment_number,
    reporting.payment_allocation_id,
    reporting.payment_obligation_id,
    reporting.obligation_number,
    reporting.membership_contract_id,
    reporting.contract_number,
    reporting.member_id,
    reporting.plan_version_id,
    reporting.financial_ownership_branch_id,
    reporting.processing_branch_id,
    reporting.reporting_warning_flag
FROM vw_reporting_refund AS reporting
JOIN refund
    ON refund.refund_id = reporting.refund_id;
