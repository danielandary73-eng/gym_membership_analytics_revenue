-- Gym Membership & Revenue Analytics System
-- SQLA-003A: materialized reporting mart for stable Power BI performance
-- Prerequisite: run 21_create_analysis_views.sql after the approved synthetic load.
-- The source dataset is deterministic and immutable. Rerun 21, then this script,
-- whenever the approved analytical dataset is deliberately rebuilt.

USE gym_membership_analytics;

-- Remove wrappers before replacing their physical cache tables.
DROP VIEW IF EXISTS vw_analysis_membership_daily_snapshot;

DROP TABLE IF EXISTS mart_analysis_membership_daily_snapshot;
DROP TABLE IF EXISTS mart_analysis_membership_contract;

-- Materialize the Contract fact directly from the already validated source
-- population. Script 98 must have passed before this build, so repeating the
-- quadratic data-quality anti-joins here would add cost without adding a new
-- control. The analytical business rules remain identical to view 21.
CREATE TABLE mart_analysis_membership_contract
ENGINE = InnoDB
AS
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
    FROM membership_contract AS contract
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

ALTER TABLE mart_analysis_membership_contract
    ADD CONSTRAINT pk_mart_analysis_membership_contract
        PRIMARY KEY (membership_contract_id),
    ADD CONSTRAINT uk_mart_analysis_membership_contract_number
        UNIQUE (contract_number),
    ADD INDEX ix_mart_contract_member_start
        (member_id, service_start_date),
    ADD INDEX ix_mart_contract_previous
        (previous_membership_contract_id),
    ADD INDEX ix_mart_contract_reporting
        (financial_ownership_branch_id, plan_version_id, service_start_date),
    ADD INDEX ix_mart_contract_effective_end
        (effective_end_date);

-- Build the daily snapshot from the cached Contract fact. This avoids expanding
-- the expensive Contract transformation once for every Contract/date row.
CREATE TABLE mart_analysis_membership_daily_snapshot
ENGINE = InnoDB
AS
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
        AND reporting_date.calendar_date BETWEEN contract.service_start_date
            AND contract.effective_end_date
        AND DATEDIFF(contract.effective_end_date, reporting_date.calendar_date)
            BETWEEN 1 AND 30
        AND renewal.membership_contract_id IS NULL
    ) AS expiring_1_30_day_flag,
    (
        (contract.cancellation_effective_date IS NULL
         OR contract.cancellation_effective_date > reporting_date.calendar_date)
        AND reporting_date.calendar_date BETWEEN contract.service_start_date
            AND contract.effective_end_date
        AND DATEDIFF(contract.effective_end_date, reporting_date.calendar_date)
            BETWEEN 31 AND 60
        AND renewal.membership_contract_id IS NULL
    ) AS expiring_31_60_day_flag
FROM vw_analysis_date AS reporting_date
CROSS JOIN mart_analysis_membership_contract AS contract
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
LEFT JOIN mart_analysis_membership_contract AS renewal
    ON renewal.previous_membership_contract_id = contract.membership_contract_id
   AND renewal.contract_classification_code = 'DIRECT_RENEWAL'
WHERE reporting_date.opening_anchor_flag = 1
   OR reporting_date.reporting_scope_flag = 1;

ALTER TABLE mart_analysis_membership_daily_snapshot
    ADD CONSTRAINT pk_mart_analysis_membership_daily_snapshot
        PRIMARY KEY (snapshot_date, membership_contract_id),
    ADD INDEX ix_mart_snapshot_contract
        (membership_contract_id, snapshot_date),
    ADD INDEX ix_mart_snapshot_branch_status
        (snapshot_date, home_branch_id, membership_status_code),
    ADD INDEX ix_mart_snapshot_plan_status
        (snapshot_date, plan_version_id, membership_status_code),
    ADD INDEX ix_mart_snapshot_expiry
        (snapshot_date, expiring_1_30_day_flag, expiring_31_60_day_flag);

-- Replace the two costly public views with stable read-only wrappers. Their
-- names and ordered column contracts remain unchanged for Power BI.
DROP VIEW IF EXISTS vw_analysis_membership_contract;

CREATE VIEW vw_analysis_membership_contract AS
SELECT
    membership_contract_id, contract_number, member_id, member_number,
    plan_version_id, plan_id, plan_code, plan_name,
    financial_ownership_branch_id, financial_ownership_branch_code,
    financial_ownership_branch_name, home_branch_at_start_id,
    home_branch_at_start_code, home_branch_at_start_name,
    previous_membership_contract_id, previous_contract_number,
    contract_classification_code, contract_created_date, service_start_date,
    original_end_date, approved_freeze_days, effective_end_date,
    cancellation_effective_date, historical_list_price_usd,
    discount_amount_usd, expected_revenue_usd, payment_schedule_type_code
FROM mart_analysis_membership_contract;

CREATE VIEW vw_analysis_membership_daily_snapshot AS
SELECT
    snapshot_date, membership_contract_id, contract_number, member_id,
    member_number, plan_version_id, plan_id, plan_code, plan_name,
    home_branch_id, home_branch_code, home_branch_name,
    financial_ownership_branch_id, service_start_date, effective_end_date,
    cancellation_effective_date, membership_status_code,
    active_contract_flag, live_contract_flag, active_member_flag,
    live_member_flag, days_to_effective_end, expiring_1_30_day_flag,
    expiring_31_60_day_flag
FROM mart_analysis_membership_daily_snapshot;

ANALYZE TABLE
    mart_analysis_membership_contract,
    mart_analysis_membership_daily_snapshot;

SELECT
    'SQLA003_MART_BUILD' AS build_control,
    (SELECT COUNT(*) FROM mart_analysis_membership_contract) AS contract_rows,
    (SELECT COUNT(*) FROM mart_analysis_membership_daily_snapshot) AS snapshot_rows,
    CASE
        WHEN (SELECT COUNT(*) FROM mart_analysis_membership_contract) > 0
         AND (SELECT COUNT(*) FROM mart_analysis_membership_daily_snapshot) > 0
        THEN 'COMPLETE' ELSE 'FAIL'
    END AS build_result,
    'Run 22_extend_analysis_grants.sql next' AS next_step;
