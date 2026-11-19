-- Gym Membership & Revenue Analytics System
-- SQLA-003C: materialized Obligation activity ledger
-- Prerequisite: scripts 21 and 23 completed; script 98 previously passed.

USE gym_membership_analytics;

DROP VIEW IF EXISTS vw_analysis_obligation_activity;
DROP TEMPORARY TABLE IF EXISTS tmp_mart_obligation_balance;
DROP TABLE IF EXISTS mart_analysis_obligation_activity;

-- Stabilize the approved current balance population once for all four ledger
-- branches. InnoDB avoids the MySQL Windows internal #sql temporary-table bug.
CREATE TEMPORARY TABLE tmp_mart_obligation_balance
ENGINE = InnoDB
AS
SELECT *
FROM vw_reporting_obligation_balance;

ALTER TABLE tmp_mart_obligation_balance
    ADD PRIMARY KEY (payment_obligation_id);

CREATE TABLE mart_analysis_obligation_activity (
    obligation_activity_key VARCHAR(64) NOT NULL,
    obligation_activity_type_code VARCHAR(32) NOT NULL,
    activity_date DATE NOT NULL,
    activity_at_utc DATETIME(6) NULL,
    activity_at_beirut DATETIME(6) NULL,
    payment_obligation_id BIGINT UNSIGNED NOT NULL,
    obligation_number VARCHAR(30) NOT NULL,
    obligation_sequence_number SMALLINT UNSIGNED NOT NULL,
    due_date DATE NOT NULL,
    membership_contract_id BIGINT UNSIGNED NOT NULL,
    contract_number VARCHAR(30) NOT NULL,
    member_id BIGINT UNSIGNED NOT NULL,
    plan_version_id BIGINT UNSIGNED NOT NULL,
    financial_ownership_branch_id BIGINT UNSIGNED NOT NULL,
    source_record_id BIGINT UNSIGNED NOT NULL,
    source_record_reference VARCHAR(64) NOT NULL,
    activity_amount_usd DECIMAL(12, 2) NOT NULL,
    balance_effect_amount_usd DECIMAL(12, 2) NOT NULL,
    cancelled_amount_flag TINYINT(1) NOT NULL,
    gross_application_flag TINYINT(1) NOT NULL,
    refund_reopening_flag TINYINT(1) NOT NULL,
    reporting_warning_flag TINYINT(1) NOT NULL,
    CONSTRAINT pk_mart_analysis_obligation_activity
        PRIMARY KEY (obligation_activity_key),
    INDEX ix_mart_obligation_activity_obligation
        (payment_obligation_id, activity_date),
    INDEX ix_mart_obligation_activity_contract
        (membership_contract_id, activity_date),
    INDEX ix_mart_obligation_activity_type_date
        (obligation_activity_type_code, activity_date)
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- 1. Original Obligation amount.
INSERT INTO mart_analysis_obligation_activity
SELECT
    CONCAT('OBLIGATION:', balance.payment_obligation_id),
    'ORIGINAL_OBLIGATION',
    contract.contract_created_date,
    NULL,
    NULL,
    balance.payment_obligation_id,
    balance.obligation_number,
    balance.obligation_sequence_number,
    balance.due_date,
    balance.membership_contract_id,
    balance.contract_number,
    balance.member_id,
    balance.plan_version_id,
    balance.financial_ownership_branch_id,
    balance.payment_obligation_id,
    balance.obligation_number,
    balance.original_obligation_amount_usd,
    balance.original_obligation_amount_usd,
    FALSE, FALSE, FALSE,
    balance.reporting_warning_flag
FROM tmp_mart_obligation_balance AS balance
JOIN mart_analysis_membership_contract AS contract
    ON contract.membership_contract_id = balance.membership_contract_id;

-- 2. Approved Cancellation adjustment.
INSERT INTO mart_analysis_obligation_activity
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
    TRUE, FALSE, FALSE,
    balance.reporting_warning_flag
FROM payment_obligation_adjustment AS adjustment
JOIN tmp_mart_obligation_balance AS balance
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
  );

-- 3. Gross successful Payment application.
INSERT INTO mart_analysis_obligation_activity
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
    FALSE, TRUE, FALSE,
    (gross.reporting_warning_flag = 1 OR balance.reporting_warning_flag = 1)
FROM vw_reporting_gross_collected_revenue AS gross
JOIN tmp_mart_obligation_balance AS balance
    ON balance.payment_obligation_id = gross.payment_obligation_id;

-- 4. Completed Refund that reopens the Obligation.
INSERT INTO mart_analysis_obligation_activity
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
    FALSE, FALSE, TRUE,
    (refund.reporting_warning_flag = 1 OR balance.reporting_warning_flag = 1)
FROM vw_reporting_refund AS refund
JOIN tmp_mart_obligation_balance AS balance
    ON balance.payment_obligation_id = refund.payment_obligation_id
WHERE refund.reopens_obligation_flag = 1;

CREATE VIEW vw_analysis_obligation_activity AS
SELECT
    obligation_activity_key, obligation_activity_type_code, activity_date,
    activity_at_utc, activity_at_beirut, payment_obligation_id,
    obligation_number, obligation_sequence_number, due_date,
    membership_contract_id, contract_number, member_id, plan_version_id,
    financial_ownership_branch_id, source_record_id,
    source_record_reference, activity_amount_usd, balance_effect_amount_usd,
    cancelled_amount_flag, gross_application_flag, refund_reopening_flag,
    reporting_warning_flag
FROM mart_analysis_obligation_activity;

DROP TEMPORARY TABLE tmp_mart_obligation_balance;
ANALYZE TABLE mart_analysis_obligation_activity;

SELECT
    'SQLA003_OBLIGATION_ACTIVITY_MART_BUILD' AS build_control,
    COUNT(*) AS activity_rows,
    COUNT(DISTINCT obligation_activity_key) AS distinct_activity_rows,
    CASE WHEN COUNT(*) > 0
           AND COUNT(*) = COUNT(DISTINCT obligation_activity_key)
         THEN 'COMPLETE' ELSE 'FAIL' END AS build_result,
    'Run 22_extend_analysis_grants.sql next' AS next_step
FROM mart_analysis_obligation_activity;
