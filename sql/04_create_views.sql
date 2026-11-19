-- Gym Membership & Revenue Analytics System
-- PDM-017: 25 approved validation and curated reporting views
-- Prerequisite: run 00_create_schema.sql through 03_create_triggers.sql first.

USE gym_membership_analytics;

-- 1. Plan Version period overlap and multiple-open-period detection
CREATE VIEW vw_dq_plan_version_overlap AS
SELECT
    left_version.plan_id,
    left_version.plan_version_id AS left_plan_version_id,
    right_version.plan_version_id AS right_plan_version_id,
    left_version.available_from_date AS left_available_from_date,
    left_version.available_to_date AS left_available_to_date,
    right_version.available_from_date AS right_available_from_date,
    right_version.available_to_date AS right_available_to_date,
    CASE
        WHEN left_version.available_to_date IS NULL
         AND right_version.available_to_date IS NULL
        THEN 'MULTIPLE_OPEN_PERIODS'
        ELSE 'OVERLAPPING_PERIODS'
    END AS issue_code
FROM membership_plan_version AS left_version
JOIN membership_plan_version AS right_version
    ON right_version.plan_id = left_version.plan_id
   AND right_version.plan_version_id > left_version.plan_version_id
   AND left_version.available_from_date
       <= COALESCE(right_version.available_to_date, DATE('9999-12-31'))
   AND right_version.available_from_date
       <= COALESCE(left_version.available_to_date, DATE('9999-12-31'));

-- 2. Member Home Branch assignment overlap and multiple-open-period detection
CREATE VIEW vw_dq_home_branch_assignment_overlap AS
SELECT
    left_assignment.member_id,
    left_assignment.member_branch_assignment_id AS left_assignment_id,
    right_assignment.member_branch_assignment_id AS right_assignment_id,
    left_assignment.home_branch_id AS left_home_branch_id,
    right_assignment.home_branch_id AS right_home_branch_id,
    left_assignment.effective_start_date AS left_effective_start_date,
    left_assignment.effective_end_date AS left_effective_end_date,
    right_assignment.effective_start_date AS right_effective_start_date,
    right_assignment.effective_end_date AS right_effective_end_date,
    CASE
        WHEN left_assignment.effective_end_date IS NULL
         AND right_assignment.effective_end_date IS NULL
        THEN 'MULTIPLE_OPEN_PERIODS'
        ELSE 'OVERLAPPING_PERIODS'
    END AS issue_code
FROM member_branch_assignment AS left_assignment
JOIN member_branch_assignment AS right_assignment
    ON right_assignment.member_id = left_assignment.member_id
   AND right_assignment.member_branch_assignment_id
       > left_assignment.member_branch_assignment_id
   AND left_assignment.effective_start_date
       <= COALESCE(right_assignment.effective_end_date, DATE('9999-12-31'))
   AND right_assignment.effective_start_date
       <= COALESCE(left_assignment.effective_end_date, DATE('9999-12-31'));

-- 3. Membership Status Decision initial-state, sequence, and timeline checks
CREATE VIEW vw_dq_membership_decision_integrity AS
WITH ranked_decision AS (
    SELECT
        decision.membership_status_decision_event_id,
        decision.membership_status_event_id,
        decision.decision_status_code,
        decision.decision_at,
        ROW_NUMBER() OVER (
            PARTITION BY decision.membership_status_event_id
            ORDER BY decision.decision_at, decision.membership_status_decision_event_id
        ) AS decision_sequence,
        LAG(decision.decision_status_code) OVER (
            PARTITION BY decision.membership_status_event_id
            ORDER BY decision.decision_at, decision.membership_status_decision_event_id
        ) AS previous_decision_status_code,
        LAG(decision.decision_at) OVER (
            PARTITION BY decision.membership_status_event_id
            ORDER BY decision.decision_at, decision.membership_status_decision_event_id
        ) AS previous_decision_at
    FROM membership_status_decision_event AS decision
), decision_summary AS (
    SELECT
        membership_status_event_id,
        COUNT(*) AS decision_count,
        SUM(decision_status_code = 'PENDING') AS pending_count,
        SUM(decision_status_code IN ('APPROVED', 'REJECTED')) AS terminal_count,
        MAX(CASE WHEN decision_sequence = 1 THEN decision_status_code END) AS first_status_code,
        MAX(CASE WHEN decision_sequence = 1 THEN decision_at END) AS first_decision_at
    FROM ranked_decision
    GROUP BY membership_status_event_id
)
SELECT
    status_event.membership_contract_id,
    status_event.membership_status_event_id,
    CAST(NULL AS UNSIGNED) AS membership_status_decision_event_id,
    'INVALID_INITIAL_DECISION' AS issue_code,
    CONCAT(
        'Expected one initial PENDING decision at ', status_event.recorded_at,
        '; observed count=', COALESCE(summary.decision_count, 0),
        ', pending=', COALESCE(summary.pending_count, 0),
        ', first=', COALESCE(summary.first_status_code, 'MISSING')
    ) AS issue_detail
FROM membership_status_event AS status_event
LEFT JOIN decision_summary AS summary
    ON summary.membership_status_event_id = status_event.membership_status_event_id
WHERE COALESCE(summary.decision_count, 0) = 0
   OR summary.pending_count <> 1
   OR summary.first_status_code <> 'PENDING'
   OR summary.first_decision_at <> status_event.recorded_at

UNION ALL

SELECT
    status_event.membership_contract_id,
    status_event.membership_status_event_id,
    decision.membership_status_decision_event_id,
    'INVALID_DECISION_SEQUENCE',
    CONCAT(
        'Decision sequence ', decision.decision_sequence,
        ' contains ', decision.decision_status_code,
        ' after ', COALESCE(decision.previous_decision_status_code, 'NONE')
    )
FROM ranked_decision AS decision
JOIN membership_status_event AS status_event
    ON status_event.membership_status_event_id = decision.membership_status_event_id
JOIN decision_summary AS summary
    ON summary.membership_status_event_id = decision.membership_status_event_id
WHERE summary.terminal_count > 1
   OR (decision.decision_sequence > 1 AND decision.decision_status_code = 'PENDING')
   OR (decision.decision_sequence > 2)

UNION ALL

SELECT
    status_event.membership_contract_id,
    status_event.membership_status_event_id,
    decision.membership_status_decision_event_id,
    'INVALID_TIMELINE',
    CONCAT('Decision time ', decision.decision_at, ' is outside the valid event sequence')
FROM ranked_decision AS decision
JOIN membership_status_event AS status_event
    ON status_event.membership_status_event_id = decision.membership_status_event_id
JOIN membership_contract AS contract
    ON contract.membership_contract_id = status_event.membership_contract_id
WHERE status_event.recorded_at < TIMESTAMP(contract.contract_created_date)
   OR decision.decision_at < status_event.recorded_at
   OR (
       decision.previous_decision_at IS NOT NULL
       AND decision.decision_at <= decision.previous_decision_at
   );

-- 4. Approved membership status-event validity, overlap, and reversal checks
CREATE VIEW vw_dq_membership_status_integrity AS
WITH latest_decision AS (
    SELECT
        decision.membership_status_event_id,
        decision.decision_status_code,
        ROW_NUMBER() OVER (
            PARTITION BY decision.membership_status_event_id
            ORDER BY decision.decision_at DESC,
                     decision.membership_status_decision_event_id DESC
        ) AS latest_rank
    FROM membership_status_decision_event AS decision
), approved_event AS (
    SELECT status_event.*
    FROM membership_status_event AS status_event
    JOIN latest_decision AS decision
        ON decision.membership_status_event_id = status_event.membership_status_event_id
       AND decision.latest_rank = 1
       AND decision.decision_status_code = 'APPROVED'
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
), freeze_summary AS (
    SELECT
        membership_contract_id,
        SUM(DATEDIFF(effective_end_date, effective_start_date) + 1) AS freeze_days
    FROM active_event
    WHERE event_type_code = 'FREEZE'
      AND effective_end_date IS NOT NULL
      AND effective_end_date >= effective_start_date
    GROUP BY membership_contract_id
), active_cancellation AS (
    SELECT
        membership_contract_id,
        MIN(effective_start_date) AS cancellation_date,
        COUNT(*) AS cancellation_count
    FROM active_event
    WHERE event_type_code = 'CANCELLATION'
    GROUP BY membership_contract_id
)
SELECT
    freeze_event.membership_contract_id,
    freeze_event.membership_status_event_id,
    CAST(NULL AS UNSIGNED) AS related_membership_status_event_id,
    'INVALID_FREEZE' AS issue_code,
    'Approved Freeze is outside its eligible Contract period' AS issue_detail
FROM active_event AS freeze_event
JOIN membership_contract AS contract
    ON contract.membership_contract_id = freeze_event.membership_contract_id
LEFT JOIN freeze_summary AS summary
    ON summary.membership_contract_id = freeze_event.membership_contract_id
LEFT JOIN active_cancellation AS current_cancellation
    ON current_cancellation.membership_contract_id = freeze_event.membership_contract_id
WHERE freeze_event.event_type_code = 'FREEZE'
  AND (
      freeze_event.effective_end_date IS NULL
      OR freeze_event.effective_end_date < freeze_event.effective_start_date
      OR freeze_event.effective_start_date < contract.service_start_date
      OR freeze_event.effective_start_date > DATE_ADD(
          contract.original_end_date,
          INTERVAL COALESCE(summary.freeze_days, 0) DAY
      )
      OR (
          current_cancellation.cancellation_date IS NOT NULL
          AND freeze_event.effective_start_date >= current_cancellation.cancellation_date
      )
  )

UNION ALL

SELECT
    left_freeze.membership_contract_id,
    left_freeze.membership_status_event_id,
    right_freeze.membership_status_event_id,
    'INVALID_FREEZE',
    'Approved non-reversed Freeze periods overlap'
FROM active_event AS left_freeze
JOIN active_event AS right_freeze
    ON right_freeze.membership_contract_id = left_freeze.membership_contract_id
   AND right_freeze.membership_status_event_id > left_freeze.membership_status_event_id
   AND right_freeze.event_type_code = 'FREEZE'
   AND left_freeze.effective_start_date <= right_freeze.effective_end_date
   AND right_freeze.effective_start_date <= left_freeze.effective_end_date
WHERE left_freeze.event_type_code = 'FREEZE'

UNION ALL

SELECT
    cancellation.membership_contract_id,
    cancellation.membership_status_event_id,
    CAST(NULL AS UNSIGNED),
    'INVALID_CANCELLATION',
    'Approved non-reversed Cancellation is duplicated or outside the Contract period'
FROM active_event AS cancellation
JOIN membership_contract AS contract
    ON contract.membership_contract_id = cancellation.membership_contract_id
LEFT JOIN freeze_summary AS summary
    ON summary.membership_contract_id = cancellation.membership_contract_id
JOIN active_cancellation AS cancellation_summary
    ON cancellation_summary.membership_contract_id = cancellation.membership_contract_id
WHERE cancellation.event_type_code = 'CANCELLATION'
  AND (
      cancellation_summary.cancellation_count > 1
      OR cancellation.effective_start_date < contract.service_start_date
      OR cancellation.effective_start_date > DATE_ADD(
          contract.original_end_date,
          INTERVAL COALESCE(summary.freeze_days, 0) DAY
      )
  )

UNION ALL

SELECT
    reversal.membership_contract_id,
    reversal.membership_status_event_id,
    reversal.reverses_membership_status_event_id,
    'INVALID_REVERSAL',
    'Approved Reversal has an invalid, unapproved, future, cross-Contract, or reused target'
FROM approved_event AS reversal
LEFT JOIN approved_event AS target
    ON target.membership_status_event_id = reversal.reverses_membership_status_event_id
WHERE reversal.event_type_code = 'REVERSAL'
  AND (
      target.membership_status_event_id IS NULL
      OR target.membership_contract_id <> reversal.membership_contract_id
      OR target.event_type_code NOT IN ('FREEZE', 'CANCELLATION')
      OR target.recorded_at >= reversal.recorded_at
      OR (
          SELECT COUNT(*)
          FROM approved_event AS other_reversal
          WHERE other_reversal.event_type_code = 'REVERSAL'
            AND other_reversal.reverses_membership_status_event_id
                = reversal.reverses_membership_status_event_id
      ) > 1
  )

UNION ALL

SELECT
    status_event.membership_contract_id,
    status_event.membership_status_event_id,
    CAST(NULL AS UNSIGNED),
    'INVALID_TIMELINE',
    'Status Event was recorded before its Contract creation date'
FROM membership_status_event AS status_event
JOIN membership_contract AS contract
    ON contract.membership_contract_id = status_event.membership_contract_id
WHERE status_event.recorded_at < TIMESTAMP(contract.contract_created_date);

-- 5. Contract Plan applicability, Financial Branch, and predecessor checks
CREATE VIEW vw_dq_contract_integrity AS
SELECT
    contract.membership_contract_id,
    contract.contract_number,
    'PLAN_VERSION_NOT_APPLICABLE' AS issue_code,
    CONCAT(
        'Contract date ', contract.contract_created_date,
        ' is outside Plan Version availability'
    ) AS issue_detail
FROM membership_contract AS contract
JOIN membership_plan_version AS plan_version
    ON plan_version.plan_version_id = contract.plan_version_id
WHERE contract.contract_created_date < plan_version.available_from_date
   OR (
       plan_version.available_to_date IS NOT NULL
       AND contract.contract_created_date > plan_version.available_to_date
   )

UNION ALL

SELECT
    contract.membership_contract_id,
    contract.contract_number,
    'FINANCIAL_BRANCH_MISMATCH',
    CONCAT(
        'Stored branch=', contract.financial_ownership_branch_id,
        '; effective Home Branch=',
        COALESCE(CAST(MIN(assignment.home_branch_id) AS CHAR), 'MISSING'),
        '; matching assignments=', COUNT(assignment.member_branch_assignment_id)
    )
FROM membership_contract AS contract
LEFT JOIN member_branch_assignment AS assignment
    ON assignment.member_id = contract.member_id
   AND assignment.effective_start_date <= contract.service_start_date
   AND (
       assignment.effective_end_date IS NULL
       OR assignment.effective_end_date >= contract.service_start_date
   )
GROUP BY
    contract.membership_contract_id,
    contract.contract_number,
    contract.financial_ownership_branch_id
HAVING COUNT(assignment.member_branch_assignment_id) <> 1
    OR MIN(assignment.home_branch_id) <> contract.financial_ownership_branch_id

UNION ALL

SELECT
    contract.membership_contract_id,
    contract.contract_number,
    'INVALID_PREDECESSOR',
    CONCAT(
        'Stored predecessor=',
        COALESCE(CAST(contract.previous_membership_contract_id AS CHAR), 'NONE'),
        '; expected predecessor=',
        COALESCE(CAST((
            SELECT prior.membership_contract_id
            FROM membership_contract AS prior
            WHERE prior.member_id = contract.member_id
              AND prior.service_start_date < contract.service_start_date
            ORDER BY prior.service_start_date DESC, prior.membership_contract_id DESC
            LIMIT 1
        ) AS CHAR), 'NONE')
    )
FROM membership_contract AS contract
LEFT JOIN membership_contract AS predecessor
    ON predecessor.membership_contract_id = contract.previous_membership_contract_id
WHERE NOT (
    contract.previous_membership_contract_id <=> (
        SELECT prior.membership_contract_id
        FROM membership_contract AS prior
        WHERE prior.member_id = contract.member_id
          AND prior.service_start_date < contract.service_start_date
        ORDER BY prior.service_start_date DESC, prior.membership_contract_id DESC
        LIMIT 1
    )
)
   OR contract.previous_membership_contract_id = contract.membership_contract_id
   OR (
       predecessor.membership_contract_id IS NOT NULL
       AND predecessor.member_id <> contract.member_id
   );

-- 6. Contract service-period overlap after Freeze extension and early Cancellation
CREATE VIEW vw_dq_contract_service_overlap AS
WITH latest_decision AS (
    SELECT
        decision.membership_status_event_id,
        decision.decision_status_code,
        ROW_NUMBER() OVER (
            PARTITION BY decision.membership_status_event_id
            ORDER BY decision.decision_at DESC,
                     decision.membership_status_decision_event_id DESC
        ) AS latest_rank
    FROM membership_status_decision_event AS decision
), approved_event AS (
    SELECT status_event.*
    FROM membership_status_event AS status_event
    JOIN latest_decision AS decision
        ON decision.membership_status_event_id = status_event.membership_status_event_id
       AND decision.latest_rank = 1
       AND decision.decision_status_code = 'APPROVED'
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
), event_summary AS (
    SELECT
        membership_contract_id,
        SUM(
            CASE
                WHEN event_type_code = 'FREEZE'
                 AND effective_end_date >= effective_start_date
                THEN DATEDIFF(effective_end_date, effective_start_date) + 1
                ELSE 0
            END
        ) AS freeze_days,
        MIN(CASE WHEN event_type_code = 'CANCELLATION' THEN effective_start_date END)
            AS cancellation_date
    FROM active_event
    GROUP BY membership_contract_id
), contract_period AS (
    SELECT
        contract.membership_contract_id,
        contract.contract_number,
        contract.member_id,
        contract.service_start_date,
        DATE_ADD(
            contract.original_end_date,
            INTERVAL COALESCE(summary.freeze_days, 0) DAY
        ) AS effective_end_date,
        CASE
            WHEN summary.cancellation_date IS NOT NULL
            THEN LEAST(
                DATE_ADD(
                    contract.original_end_date,
                    INTERVAL COALESCE(summary.freeze_days, 0) DAY
                ),
                DATE_SUB(summary.cancellation_date, INTERVAL 1 DAY)
            )
            ELSE DATE_ADD(
                contract.original_end_date,
                INTERVAL COALESCE(summary.freeze_days, 0) DAY
            )
        END AS valid_service_end_date
    FROM membership_contract AS contract
    LEFT JOIN event_summary AS summary
        ON summary.membership_contract_id = contract.membership_contract_id
)
SELECT
    left_contract.member_id,
    left_contract.membership_contract_id AS left_membership_contract_id,
    left_contract.contract_number AS left_contract_number,
    right_contract.membership_contract_id AS right_membership_contract_id,
    right_contract.contract_number AS right_contract_number,
    GREATEST(
        left_contract.service_start_date,
        right_contract.service_start_date
    ) AS overlap_start_date,
    LEAST(
        left_contract.valid_service_end_date,
        right_contract.valid_service_end_date
    ) AS overlap_end_date,
    'SERVICE_PERIOD_OVERLAP' AS issue_code
FROM contract_period AS left_contract
JOIN contract_period AS right_contract
    ON right_contract.member_id = left_contract.member_id
   AND right_contract.membership_contract_id > left_contract.membership_contract_id
   AND left_contract.service_start_date <= right_contract.valid_service_end_date
   AND right_contract.service_start_date <= left_contract.valid_service_end_date
WHERE left_contract.valid_service_end_date >= left_contract.service_start_date
  AND right_contract.valid_service_end_date >= right_contract.service_start_date;

-- 7. Duplicate Check-In source-reference ranking and canonical occurrence
CREATE VIEW vw_dq_check_in_duplicate_reference AS
WITH ranked_reference AS (
    SELECT
        check_in.check_in_id,
        check_in.source_check_in_reference,
        UPPER(TRIM(check_in.source_check_in_reference)) AS normalized_source_reference,
        check_in.recorded_at,
        COUNT(*) OVER (
            PARTITION BY UPPER(TRIM(check_in.source_check_in_reference))
        ) AS occurrence_count,
        ROW_NUMBER() OVER (
            PARTITION BY UPPER(TRIM(check_in.source_check_in_reference))
            ORDER BY check_in.recorded_at, check_in.check_in_id
        ) AS occurrence_rank,
        FIRST_VALUE(check_in.check_in_id) OVER (
            PARTITION BY UPPER(TRIM(check_in.source_check_in_reference))
            ORDER BY check_in.recorded_at, check_in.check_in_id
        ) AS canonical_check_in_id
    FROM check_in
    WHERE source_check_in_reference IS NOT NULL
      AND CHAR_LENGTH(TRIM(source_check_in_reference)) > 0
)
SELECT
    check_in_id,
    source_check_in_reference,
    normalized_source_reference,
    recorded_at,
    occurrence_count,
    occurrence_rank,
    canonical_check_in_id,
    (occurrence_rank = 1) AS canonical_occurrence_flag,
    'DUPLICATE_SOURCE_REFERENCE' AS issue_code
FROM ranked_reference
WHERE occurrence_count > 1;

-- 8. Stored Check-In Quality Issues compared with independently detected conditions
CREATE VIEW vw_dq_check_in_integrity AS
WITH ranked_reference AS (
    SELECT
        check_in_id,
        ROW_NUMBER() OVER (
            PARTITION BY UPPER(TRIM(source_check_in_reference))
            ORDER BY recorded_at, check_in_id
        ) AS occurrence_rank
    FROM check_in
    WHERE source_check_in_reference IS NOT NULL
      AND CHAR_LENGTH(TRIM(source_check_in_reference)) > 0
), decision_as_of AS (
    SELECT
        check_in.check_in_id,
        status_event.membership_status_event_id,
        decision.decision_status_code,
        ROW_NUMBER() OVER (
            PARTITION BY check_in.check_in_id, status_event.membership_status_event_id
            ORDER BY decision.decision_at DESC,
                     decision.membership_status_decision_event_id DESC
        ) AS latest_rank
    FROM check_in
    JOIN membership_contract AS contract
        ON contract.member_id = check_in.member_id
    JOIN membership_status_event AS status_event
        ON status_event.membership_contract_id = contract.membership_contract_id
    JOIN membership_status_decision_event AS decision
        ON decision.membership_status_event_id = status_event.membership_status_event_id
       AND decision.decision_at <= check_in.check_in_at
    WHERE check_in.check_in_at IS NOT NULL
), approved_event AS (
    SELECT
        check_in.check_in_id,
        status_event.*
    FROM check_in
    JOIN membership_contract AS contract
        ON contract.member_id = check_in.member_id
    JOIN membership_status_event AS status_event
        ON status_event.membership_contract_id = contract.membership_contract_id
    JOIN decision_as_of AS decision
        ON decision.check_in_id = check_in.check_in_id
       AND decision.membership_status_event_id = status_event.membership_status_event_id
       AND decision.latest_rank = 1
       AND decision.decision_status_code = 'APPROVED'
), active_event AS (
    SELECT approved.*
    FROM approved_event AS approved
    WHERE NOT EXISTS (
        SELECT 1
        FROM approved_event AS reversal
        WHERE reversal.check_in_id = approved.check_in_id
          AND reversal.event_type_code = 'REVERSAL'
          AND reversal.reverses_membership_status_event_id
              = approved.membership_status_event_id
    )
), contract_event_summary AS (
    SELECT
        check_in_id,
        membership_contract_id,
        SUM(
            CASE
                WHEN event_type_code = 'FREEZE'
                THEN DATEDIFF(effective_end_date, effective_start_date) + 1
                ELSE 0
            END
        ) AS freeze_days,
        MIN(CASE WHEN event_type_code = 'CANCELLATION' THEN effective_start_date END)
            AS cancellation_date
    FROM active_event
    GROUP BY check_in_id, membership_contract_id
), eligible_contract AS (
    SELECT DISTINCT
        check_in.check_in_id,
        contract.membership_contract_id
    FROM check_in
    JOIN membership_contract AS contract
        ON contract.member_id = check_in.member_id
    LEFT JOIN contract_event_summary AS summary
        ON summary.check_in_id = check_in.check_in_id
       AND summary.membership_contract_id = contract.membership_contract_id
    WHERE check_in.check_in_at IS NOT NULL
      AND DATE(CONVERT_TZ(check_in.check_in_at, '+00:00', 'Asia/Beirut'))
          BETWEEN contract.service_start_date
              AND DATE_ADD(
                  contract.original_end_date,
                  INTERVAL COALESCE(summary.freeze_days, 0) DAY
              )
      AND (
          summary.cancellation_date IS NULL
          OR DATE(CONVERT_TZ(check_in.check_in_at, '+00:00', 'Asia/Beirut'))
             < summary.cancellation_date
      )
      AND NOT EXISTS (
          SELECT 1
          FROM active_event AS freeze_event
          WHERE freeze_event.check_in_id = check_in.check_in_id
            AND freeze_event.membership_contract_id = contract.membership_contract_id
            AND freeze_event.event_type_code = 'FREEZE'
            AND DATE(CONVERT_TZ(check_in.check_in_at, '+00:00', 'Asia/Beirut'))
                BETWEEN freeze_event.effective_start_date AND freeze_event.effective_end_date
      )
      AND NOT EXISTS (
          SELECT 1
          FROM vw_dq_membership_status_integrity AS status_issue
          WHERE status_issue.membership_contract_id = contract.membership_contract_id
      )
      AND NOT EXISTS (
          SELECT 1
          FROM vw_dq_contract_integrity AS contract_issue
          WHERE contract_issue.membership_contract_id = contract.membership_contract_id
      )
      AND NOT EXISTS (
          SELECT 1
          FROM vw_dq_contract_service_overlap AS overlap_issue
          WHERE overlap_issue.left_membership_contract_id = contract.membership_contract_id
             OR overlap_issue.right_membership_contract_id = contract.membership_contract_id
      )
), detectable_issue AS (
    SELECT check_in_id, 'MISSING_SOURCE_REFERENCE' AS issue_code
    FROM check_in
    WHERE source_check_in_reference IS NULL
       OR CHAR_LENGTH(TRIM(source_check_in_reference)) = 0

    UNION ALL

    SELECT check_in_id, 'UNMATCHED_MEMBER_REFERENCE'
    FROM check_in
    WHERE member_id IS NULL

    UNION ALL

    SELECT check_in_id, 'UNMATCHED_VISITED_BRANCH_REFERENCE'
    FROM check_in
    WHERE visited_branch_id IS NULL

    UNION ALL

    SELECT check_in_id, 'MISSING_CHECK_IN_TIMESTAMP'
    FROM check_in
    WHERE check_in_at IS NULL

    UNION ALL

    SELECT check_in_id, 'DUPLICATE_SOURCE_REFERENCE'
    FROM ranked_reference
    WHERE occurrence_rank > 1

    UNION ALL

    SELECT check_in.check_in_id, 'INACTIVE_MEMBERSHIP'
    FROM check_in
    WHERE check_in.member_id IS NOT NULL
      AND check_in.check_in_at IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM eligible_contract
          WHERE eligible_contract.check_in_id = check_in.check_in_id
      )
), open_issue AS (
    SELECT *
    FROM check_in_quality_issue
    WHERE resolved_at IS NULL
)
SELECT
    detected.check_in_id,
    open_issue.check_in_quality_issue_id,
    detected.issue_code,
    'MISSING_OPEN_ISSUE' AS integrity_result,
    'Detectable blocking condition has no matching unresolved Quality Issue' AS issue_detail
FROM detectable_issue AS detected
LEFT JOIN open_issue
    ON open_issue.check_in_id = detected.check_in_id
   AND open_issue.issue_code = detected.issue_code
WHERE open_issue.check_in_quality_issue_id IS NULL

UNION ALL

SELECT
    open_issue.check_in_id,
    open_issue.check_in_quality_issue_id,
    open_issue.issue_code,
    'STALE_OPEN_ISSUE',
    'Unresolved Quality Issue no longer matches a detectable condition'
FROM open_issue
LEFT JOIN detectable_issue AS detected
    ON detected.check_in_id = open_issue.check_in_id
   AND detected.issue_code = open_issue.issue_code
WHERE detected.check_in_id IS NULL

UNION ALL

SELECT
    resolved_issue.check_in_id,
    resolved_issue.check_in_quality_issue_id,
    resolved_issue.issue_code,
    'FALSELY_RESOLVED_ISSUE',
    'Resolved Quality Issue still matches a detectable condition'
FROM check_in_quality_issue AS resolved_issue
JOIN detectable_issue AS detected
    ON detected.check_in_id = resolved_issue.check_in_id
   AND detected.issue_code = resolved_issue.issue_code
WHERE resolved_issue.resolved_at IS NOT NULL;

-- 9. Controlled eligible Check-In population for official engagement reporting
CREATE VIEW vw_reporting_check_in AS
WITH ranked_reference AS (
    SELECT
        check_in_id,
        ROW_NUMBER() OVER (
            PARTITION BY UPPER(TRIM(source_check_in_reference))
            ORDER BY recorded_at, check_in_id
        ) AS occurrence_rank
    FROM check_in
    WHERE source_check_in_reference IS NOT NULL
      AND CHAR_LENGTH(TRIM(source_check_in_reference)) > 0
), decision_as_of AS (
    SELECT
        check_in.check_in_id,
        status_event.membership_status_event_id,
        decision.decision_status_code,
        ROW_NUMBER() OVER (
            PARTITION BY check_in.check_in_id, status_event.membership_status_event_id
            ORDER BY decision.decision_at DESC,
                     decision.membership_status_decision_event_id DESC
        ) AS latest_rank
    FROM check_in
    JOIN membership_contract AS contract
        ON contract.member_id = check_in.member_id
    JOIN membership_status_event AS status_event
        ON status_event.membership_contract_id = contract.membership_contract_id
    JOIN membership_status_decision_event AS decision
        ON decision.membership_status_event_id = status_event.membership_status_event_id
       AND decision.decision_at <= check_in.check_in_at
), approved_event AS (
    SELECT
        check_in.check_in_id,
        status_event.*
    FROM check_in
    JOIN membership_contract AS contract
        ON contract.member_id = check_in.member_id
    JOIN membership_status_event AS status_event
        ON status_event.membership_contract_id = contract.membership_contract_id
    JOIN decision_as_of AS decision
        ON decision.check_in_id = check_in.check_in_id
       AND decision.membership_status_event_id = status_event.membership_status_event_id
       AND decision.latest_rank = 1
       AND decision.decision_status_code = 'APPROVED'
), active_event AS (
    SELECT approved.*
    FROM approved_event AS approved
    WHERE NOT EXISTS (
        SELECT 1
        FROM approved_event AS reversal
        WHERE reversal.check_in_id = approved.check_in_id
          AND reversal.event_type_code = 'REVERSAL'
          AND reversal.reverses_membership_status_event_id
              = approved.membership_status_event_id
    )
), contract_event_summary AS (
    SELECT
        check_in_id,
        membership_contract_id,
        SUM(
            CASE
                WHEN event_type_code = 'FREEZE'
                THEN DATEDIFF(effective_end_date, effective_start_date) + 1
                ELSE 0
            END
        ) AS freeze_days,
        MIN(CASE WHEN event_type_code = 'CANCELLATION' THEN effective_start_date END)
            AS cancellation_date
    FROM active_event
    GROUP BY check_in_id, membership_contract_id
), eligible_contract AS (
    SELECT
        check_in.check_in_id,
        contract.membership_contract_id,
        contract.contract_number,
        contract.plan_version_id,
        contract.financial_ownership_branch_id,
        ROW_NUMBER() OVER (
            PARTITION BY check_in.check_in_id
            ORDER BY contract.service_start_date DESC, contract.membership_contract_id DESC
        ) AS eligible_contract_rank
    FROM check_in
    JOIN membership_contract AS contract
        ON contract.member_id = check_in.member_id
    LEFT JOIN contract_event_summary AS summary
        ON summary.check_in_id = check_in.check_in_id
       AND summary.membership_contract_id = contract.membership_contract_id
    WHERE DATE(CONVERT_TZ(check_in.check_in_at, '+00:00', 'Asia/Beirut'))
          BETWEEN contract.service_start_date
              AND DATE_ADD(
                  contract.original_end_date,
                  INTERVAL COALESCE(summary.freeze_days, 0) DAY
              )
      AND (
          summary.cancellation_date IS NULL
          OR DATE(CONVERT_TZ(check_in.check_in_at, '+00:00', 'Asia/Beirut'))
             < summary.cancellation_date
      )
      AND NOT EXISTS (
          SELECT 1
          FROM active_event AS freeze_event
          WHERE freeze_event.check_in_id = check_in.check_in_id
            AND freeze_event.membership_contract_id = contract.membership_contract_id
            AND freeze_event.event_type_code = 'FREEZE'
            AND DATE(CONVERT_TZ(check_in.check_in_at, '+00:00', 'Asia/Beirut'))
                BETWEEN freeze_event.effective_start_date AND freeze_event.effective_end_date
      )
      AND NOT EXISTS (
          SELECT 1
          FROM vw_dq_membership_status_integrity AS status_issue
          WHERE status_issue.membership_contract_id = contract.membership_contract_id
      )
      AND NOT EXISTS (
          SELECT 1
          FROM vw_dq_contract_integrity AS contract_issue
          WHERE contract_issue.membership_contract_id = contract.membership_contract_id
      )
      AND NOT EXISTS (
          SELECT 1
          FROM vw_dq_contract_service_overlap AS overlap_issue
          WHERE overlap_issue.left_membership_contract_id = contract.membership_contract_id
             OR overlap_issue.right_membership_contract_id = contract.membership_contract_id
      )
)
SELECT
    check_in.check_in_id,
    check_in.source_check_in_reference,
    check_in.member_id,
    member.member_number,
    member.first_name,
    member.last_name,
    check_in.visited_branch_id,
    visited_branch.branch_code AS visited_branch_code,
    visited_branch.branch_name AS visited_branch_name,
    check_in.check_in_at AS check_in_at_utc,
    CONVERT_TZ(check_in.check_in_at, '+00:00', 'Asia/Beirut') AS check_in_at_beirut,
    DATE(CONVERT_TZ(check_in.check_in_at, '+00:00', 'Asia/Beirut')) AS check_in_date_beirut,
    WEEKDAY(CONVERT_TZ(check_in.check_in_at, '+00:00', 'Asia/Beirut')) + 1
        AS weekday_number_monday_1,
    HOUR(CONVERT_TZ(check_in.check_in_at, '+00:00', 'Asia/Beirut')) AS check_in_hour_beirut,
    eligible_contract.membership_contract_id,
    eligible_contract.contract_number,
    eligible_contract.plan_version_id,
    eligible_contract.financial_ownership_branch_id,
    check_in.recorded_at
FROM check_in
JOIN ranked_reference
    ON ranked_reference.check_in_id = check_in.check_in_id
   AND ranked_reference.occurrence_rank = 1
JOIN eligible_contract
    ON eligible_contract.check_in_id = check_in.check_in_id
   AND eligible_contract.eligible_contract_rank = 1
JOIN member
    ON member.member_id = check_in.member_id
JOIN branch AS visited_branch
    ON visited_branch.branch_id = check_in.visited_branch_id
WHERE check_in.check_in_at IS NOT NULL
  AND CONVERT_TZ(check_in.check_in_at, '+00:00', 'Asia/Beirut') IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM check_in_quality_issue AS quality_issue
      WHERE quality_issue.check_in_id = check_in.check_in_id
        AND quality_issue.resolved_at IS NULL
  )
  AND NOT EXISTS (
      SELECT 1
      FROM vw_dq_check_in_integrity AS integrity_issue
      WHERE integrity_issue.check_in_id = check_in.check_in_id
  );

-- 10. Contract obligation-schedule completeness and reconciliation
CREATE VIEW vw_dq_obligation_schedule AS
WITH obligation_summary AS (
    SELECT
        contract.membership_contract_id,
        contract.contract_number,
        contract.payment_schedule_type_code,
        contract.service_start_date,
        contract.historical_list_price_usd - contract.discount_amount_usd
            AS expected_revenue_usd,
        COUNT(obligation.payment_obligation_id) AS obligation_count,
        COUNT(DISTINCT obligation.obligation_sequence_number) AS distinct_sequence_count,
        COALESCE(SUM(obligation.original_obligation_amount_usd), 0.00)
            AS obligation_total_usd,
        MIN(obligation.obligation_sequence_number) AS minimum_sequence_number,
        MAX(obligation.obligation_sequence_number) AS maximum_sequence_number,
        MIN(obligation.due_date) AS first_due_date,
        SUM(
            CASE
                WHEN obligation.obligation_sequence_number = 1
                 AND obligation.due_date = contract.service_start_date
                THEN 1 ELSE 0
            END
        ) AS sequence_one_due_on_start_count,
        SUM(
            CASE
                WHEN obligation.payment_obligation_id IS NOT NULL
                 AND EXISTS (
                     SELECT 1
                     FROM payment_obligation AS earlier
                     WHERE earlier.membership_contract_id = obligation.membership_contract_id
                       AND earlier.obligation_sequence_number
                           < obligation.obligation_sequence_number
                       AND earlier.due_date > obligation.due_date
                 )
                THEN 1 ELSE 0
            END
        ) AS decreasing_due_date_count
    FROM membership_contract AS contract
    LEFT JOIN payment_obligation AS obligation
        ON obligation.membership_contract_id = contract.membership_contract_id
    GROUP BY
        contract.membership_contract_id,
        contract.contract_number,
        contract.payment_schedule_type_code,
        contract.service_start_date,
        contract.historical_list_price_usd,
        contract.discount_amount_usd
)
SELECT
    membership_contract_id,
    contract_number,
    CASE
        WHEN expected_revenue_usd = 0 AND obligation_count > 0
        THEN 'OBLIGATIONS_FOR_ZERO_EXPECTED_REVENUE'
        WHEN expected_revenue_usd > 0 AND obligation_count = 0
        THEN 'MISSING_OBLIGATION_SCHEDULE'
        WHEN payment_schedule_type_code = 'FULL'
         AND (obligation_count <> 1 OR sequence_one_due_on_start_count <> 1)
        THEN 'INVALID_FULL_SCHEDULE'
        WHEN payment_schedule_type_code = 'INSTALLMENT'
         AND (
             obligation_count < 2
             OR minimum_sequence_number <> 1
             OR maximum_sequence_number <> obligation_count
             OR distinct_sequence_count <> obligation_count
             OR decreasing_due_date_count > 0
         )
        THEN 'INVALID_INSTALLMENT_SCHEDULE'
        WHEN obligation_total_usd <> expected_revenue_usd
        THEN 'OBLIGATION_TOTAL_MISMATCH'
    END AS issue_code,
    expected_revenue_usd,
    obligation_total_usd,
    obligation_count,
    CONCAT(
        'schedule=', payment_schedule_type_code,
        '; expected=', expected_revenue_usd,
        '; obligations=', obligation_total_usd,
        '; count=', obligation_count
    ) AS issue_detail
FROM obligation_summary
WHERE (expected_revenue_usd = 0 AND obligation_count > 0)
   OR (expected_revenue_usd > 0 AND obligation_count = 0)
   OR (
       payment_schedule_type_code = 'FULL'
       AND (obligation_count <> 1 OR sequence_one_due_on_start_count <> 1)
   )
   OR (
       payment_schedule_type_code = 'INSTALLMENT'
       AND (
           obligation_count < 2
           OR minimum_sequence_number <> 1
           OR maximum_sequence_number <> obligation_count
           OR distinct_sequence_count <> obligation_count
           OR decreasing_due_date_count > 0
       )
   )
   OR obligation_total_usd <> expected_revenue_usd;

-- 11. Cancellation Adjustment target, timing, and exact-remainder checks
CREATE VIEW vw_dq_cancellation_adjustment AS
WITH latest_decision AS (
    SELECT
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
        decision.decision_at AS approved_at
    FROM membership_status_event AS status_event
    JOIN latest_decision AS decision
        ON decision.membership_status_event_id = status_event.membership_status_event_id
       AND decision.latest_rank = 1
       AND decision.decision_status_code = 'APPROVED'
), active_cancellation AS (
    SELECT approved.*
    FROM approved_event AS approved
    WHERE approved.event_type_code = 'CANCELLATION'
      AND NOT EXISTS (
          SELECT 1
          FROM approved_event AS reversal
          WHERE reversal.event_type_code = 'REVERSAL'
            AND reversal.reverses_membership_status_event_id
                = approved.membership_status_event_id
      )
), evaluated_adjustment AS (
    SELECT
        adjustment.payment_obligation_adjustment_id,
        adjustment.payment_obligation_id,
        obligation.obligation_number,
        adjustment.membership_status_event_id,
        obligation.membership_contract_id,
        adjustment.adjustment_amount_usd,
        adjustment.recorded_at,
        cancellation.membership_status_event_id AS valid_cancellation_id,
        cancellation.effective_start_date AS cancellation_date,
        cancellation.approved_at,
        obligation.due_date,
        obligation.original_obligation_amount_usd,
        COALESCE((
            SELECT SUM(prior_adjustment.adjustment_amount_usd)
            FROM payment_obligation_adjustment AS prior_adjustment
            WHERE prior_adjustment.payment_obligation_id = adjustment.payment_obligation_id
              AND (
                  prior_adjustment.recorded_at < adjustment.recorded_at
                  OR (
                      prior_adjustment.recorded_at = adjustment.recorded_at
                      AND prior_adjustment.payment_obligation_adjustment_id
                          < adjustment.payment_obligation_adjustment_id
                  )
              )
        ), 0.00) AS prior_adjustment_total_usd,
        COALESCE((
            SELECT SUM(allocation.allocated_amount_usd)
            FROM payment_allocation AS allocation
            WHERE allocation.payment_obligation_id = adjustment.payment_obligation_id
              AND allocation.recorded_at <= adjustment.recorded_at
        ), 0.00) AS prior_allocation_total_usd,
        COALESCE((
            SELECT SUM(refund_allocation.refund_allocated_amount_usd)
            FROM refund_allocation
            JOIN payment_allocation AS original_allocation
                ON original_allocation.payment_allocation_id
                    = refund_allocation.payment_allocation_id
            JOIN refund_status_event AS completed_status
                ON completed_status.refund_id = refund_allocation.refund_id
               AND completed_status.refund_status_code = 'COMPLETED'
               AND completed_status.status_at <= adjustment.recorded_at
            WHERE original_allocation.payment_obligation_id
                    = adjustment.payment_obligation_id
              AND refund_allocation.reopens_obligation_flag = 1
              AND refund_allocation.recorded_at <= adjustment.recorded_at
        ), 0.00) AS prior_reopened_total_usd
    FROM payment_obligation_adjustment AS adjustment
    JOIN payment_obligation AS obligation
        ON obligation.payment_obligation_id = adjustment.payment_obligation_id
    LEFT JOIN active_cancellation AS cancellation
        ON cancellation.membership_status_event_id = adjustment.membership_status_event_id
       AND cancellation.membership_contract_id = obligation.membership_contract_id
)
SELECT
    payment_obligation_adjustment_id,
    payment_obligation_id,
    obligation_number,
    membership_contract_id,
    membership_status_event_id,
    CASE
        WHEN valid_cancellation_id IS NULL THEN 'INVALID_CANCELLATION_TARGET'
        WHEN due_date < cancellation_date THEN 'OBLIGATION_DUE_BEFORE_CANCELLATION'
        WHEN recorded_at < approved_at THEN 'ADJUSTMENT_BEFORE_APPROVAL'
        WHEN adjustment_amount_usd <>
             GREATEST(
                 original_obligation_amount_usd
                 - prior_adjustment_total_usd
                 - prior_allocation_total_usd
                 + prior_reopened_total_usd,
                 0.00
             )
        THEN 'ADJUSTMENT_REMAINDER_MISMATCH'
    END AS issue_code,
    adjustment_amount_usd,
    GREATEST(
        original_obligation_amount_usd
        - prior_adjustment_total_usd
        - prior_allocation_total_usd
        + prior_reopened_total_usd,
        0.00
    ) AS expected_adjustment_amount_usd,
    CONCAT(
        'adjustment=', adjustment_amount_usd,
        '; expected remainder=',
        GREATEST(
            original_obligation_amount_usd
            - prior_adjustment_total_usd
            - prior_allocation_total_usd
            + prior_reopened_total_usd,
            0.00
        )
    ) AS issue_detail
FROM evaluated_adjustment
WHERE valid_cancellation_id IS NULL
   OR due_date < cancellation_date
   OR recorded_at < approved_at
   OR adjustment_amount_usd <>
      GREATEST(
          original_obligation_amount_usd
          - prior_adjustment_total_usd
          - prior_allocation_total_usd
          + prior_reopened_total_usd,
          0.00
      );

-- 12. Payment Attempt sequence, amount, status path, and eligible-outcome checks
CREATE VIEW vw_dq_payment_attempt_integrity AS
WITH ranked_status AS (
    SELECT
        status_event.payment_attempt_status_event_id,
        status_event.payment_attempt_id,
        status_event.attempt_status_code,
        status_event.status_at,
        ROW_NUMBER() OVER (
            PARTITION BY status_event.payment_attempt_id
            ORDER BY status_event.status_at,
                     status_event.payment_attempt_status_event_id
        ) AS status_sequence,
        LAG(status_event.attempt_status_code) OVER (
            PARTITION BY status_event.payment_attempt_id
            ORDER BY status_event.status_at,
                     status_event.payment_attempt_status_event_id
        ) AS previous_status_code,
        LAG(status_event.status_at) OVER (
            PARTITION BY status_event.payment_attempt_id
            ORDER BY status_event.status_at,
                     status_event.payment_attempt_status_event_id
        ) AS previous_status_at,
        ROW_NUMBER() OVER (
            PARTITION BY status_event.payment_attempt_id
            ORDER BY status_event.status_at DESC,
                     status_event.payment_attempt_status_event_id DESC
        ) AS latest_rank
    FROM payment_attempt_status_event AS status_event
), attempt_summary AS (
    SELECT
        attempt.payment_attempt_id,
        attempt.payment_id,
        attempt.attempt_number,
        attempt.attempt_sequence_number,
        attempt.attempted_at,
        attempt.attempted_amount_usd,
        payment.requested_at,
        payment.requested_amount_usd,
        COUNT(status.payment_attempt_status_event_id) AS status_count,
        SUM(status.attempt_status_code = 'PENDING') AS pending_count,
        MAX(CASE WHEN status.status_sequence = 1 THEN status.attempt_status_code END)
            AS first_status_code,
        MAX(CASE WHEN status.status_sequence = 1 THEN status.status_at END)
            AS first_status_at,
        MAX(CASE WHEN status.latest_rank = 1 THEN status.attempt_status_code END)
            AS latest_status_code
    FROM payment_attempt AS attempt
    JOIN payment
        ON payment.payment_id = attempt.payment_id
    LEFT JOIN ranked_status AS status
        ON status.payment_attempt_id = attempt.payment_attempt_id
    GROUP BY
        attempt.payment_attempt_id,
        attempt.payment_id,
        attempt.attempt_number,
        attempt.attempt_sequence_number,
        attempt.attempted_at,
        attempt.attempted_amount_usd,
        payment.requested_at,
        payment.requested_amount_usd
), payment_attempt_summary AS (
    SELECT
        payment.payment_id,
        COUNT(attempt.payment_attempt_id) AS attempt_count,
        COUNT(DISTINCT attempt.attempt_sequence_number) AS distinct_sequence_count,
        MIN(attempt.attempt_sequence_number) AS minimum_sequence_number,
        MAX(attempt.attempt_sequence_number) AS maximum_sequence_number,
        SUM(summary.latest_status_code IN ('SUCCESSFUL', 'SETTLED'))
            AS eligible_attempt_count
    FROM payment
    LEFT JOIN payment_attempt AS attempt
        ON attempt.payment_id = payment.payment_id
    LEFT JOIN attempt_summary AS summary
        ON summary.payment_attempt_id = attempt.payment_attempt_id
    GROUP BY payment.payment_id
)
SELECT
    summary.payment_id,
    summary.payment_attempt_id,
    CAST(NULL AS UNSIGNED) AS payment_attempt_status_event_id,
    'INVALID_ATTEMPT_DEFINITION' AS issue_code,
    CONCAT(
        'attempted_at=', summary.attempted_at,
        '; requested_at=', summary.requested_at,
        '; attempted amount=', summary.attempted_amount_usd,
        '; requested amount=', summary.requested_amount_usd
    ) AS issue_detail
FROM attempt_summary AS summary
WHERE summary.attempted_at < summary.requested_at
   OR summary.attempted_amount_usd > summary.requested_amount_usd

UNION ALL

SELECT
    summary.payment_id,
    summary.payment_attempt_id,
    CAST(NULL AS UNSIGNED),
    'INVALID_INITIAL_ATTEMPT_STATUS',
    CONCAT(
        'Expected one initial PENDING status at ', summary.attempted_at,
        '; observed count=', summary.status_count,
        '; pending=', summary.pending_count,
        '; first=', COALESCE(summary.first_status_code, 'MISSING')
    )
FROM attempt_summary AS summary
WHERE summary.status_count = 0
   OR summary.pending_count <> 1
   OR summary.first_status_code <> 'PENDING'
   OR summary.first_status_at <> summary.attempted_at

UNION ALL

SELECT
    attempt.payment_id,
    status.payment_attempt_id,
    status.payment_attempt_status_event_id,
    'INVALID_ATTEMPT_STATUS_SEQUENCE',
    CONCAT(
        'Invalid transition from ', COALESCE(status.previous_status_code, 'NONE'),
        ' to ', status.attempt_status_code, ' at ', status.status_at
    )
FROM ranked_status AS status
JOIN payment_attempt AS attempt
    ON attempt.payment_attempt_id = status.payment_attempt_id
WHERE (status.previous_status_at IS NOT NULL AND status.status_at <= status.previous_status_at)
   OR (
       status.status_sequence > 1
       AND NOT (
           (status.previous_status_code = 'PENDING'
            AND status.attempt_status_code IN ('SUCCESSFUL', 'FAILED', 'CANCELLED'))
           OR (status.previous_status_code = 'SUCCESSFUL'
               AND status.attempt_status_code IN ('SETTLED', 'REVERSED'))
           OR (status.previous_status_code = 'SETTLED'
               AND status.attempt_status_code = 'REVERSED')
       )
   )

UNION ALL

SELECT
    payment_summary.payment_id,
    CAST(NULL AS UNSIGNED),
    CAST(NULL AS UNSIGNED),
    'INVALID_ATTEMPT_SEQUENCE',
    CONCAT(
        'count=', payment_summary.attempt_count,
        '; distinct=', payment_summary.distinct_sequence_count,
        '; min=', COALESCE(payment_summary.minimum_sequence_number, 0),
        '; max=', COALESCE(payment_summary.maximum_sequence_number, 0)
    )
FROM payment_attempt_summary AS payment_summary
WHERE payment_summary.attempt_count > 0
  AND (
      payment_summary.minimum_sequence_number <> 1
      OR payment_summary.maximum_sequence_number <> payment_summary.attempt_count
      OR payment_summary.distinct_sequence_count <> payment_summary.attempt_count
  )

UNION ALL

SELECT
    payment_summary.payment_id,
    CAST(NULL AS UNSIGNED),
    CAST(NULL AS UNSIGNED),
    'MULTIPLE_ELIGIBLE_ATTEMPTS',
    CONCAT('Current eligible attempt count=', payment_summary.eligible_attempt_count)
FROM payment_attempt_summary AS payment_summary
WHERE payment_summary.eligible_attempt_count > 1;

-- 13. Payment funding, Contract lineage, Allocation total, and ceiling checks
CREATE VIEW vw_dq_payment_reconciliation AS
WITH latest_attempt_status AS (
    SELECT
        attempt.payment_attempt_id,
        attempt.payment_id,
        attempt.attempted_amount_usd,
        status_event.attempt_status_code,
        ROW_NUMBER() OVER (
            PARTITION BY attempt.payment_attempt_id
            ORDER BY status_event.status_at DESC,
                     status_event.payment_attempt_status_event_id DESC
        ) AS latest_rank
    FROM payment_attempt AS attempt
    LEFT JOIN payment_attempt_status_event AS status_event
        ON status_event.payment_attempt_id = attempt.payment_attempt_id
), eligible_attempt_summary AS (
    SELECT
        payment.payment_id,
        SUM(
            CASE
                WHEN attempt.latest_rank = 1
                 AND attempt.attempt_status_code IN ('SUCCESSFUL', 'SETTLED')
                THEN 1 ELSE 0
            END
        ) AS eligible_attempt_count,
        MAX(
            CASE
                WHEN attempt.latest_rank = 1
                 AND attempt.attempt_status_code IN ('SUCCESSFUL', 'SETTLED')
                THEN attempt.attempted_amount_usd
            END
        ) AS eligible_received_amount_usd,
        MAX(
            CASE
                WHEN attempt.latest_rank = 1
                 AND attempt.attempt_status_code IN ('SUCCESSFUL', 'SETTLED')
                THEN attempt.payment_attempt_id
            END
        ) AS eligible_payment_attempt_id
    FROM payment
    LEFT JOIN latest_attempt_status AS attempt
        ON attempt.payment_id = payment.payment_id
       AND attempt.latest_rank = 1
    GROUP BY payment.payment_id
), allocation_summary AS (
    SELECT
        payment.payment_id,
        COUNT(allocation.payment_allocation_id) AS allocation_count,
        COALESCE(SUM(allocation.allocated_amount_usd), 0.00) AS allocation_total_usd
    FROM payment
    LEFT JOIN payment_allocation AS allocation
        ON allocation.payment_id = payment.payment_id
    GROUP BY payment.payment_id
), payment_summary AS (
    SELECT
        payment.payment_id,
        payment.payment_number,
        payment.membership_contract_id,
        payment.requested_amount_usd,
        attempt.eligible_attempt_count,
        attempt.eligible_received_amount_usd,
        attempt.eligible_payment_attempt_id,
        allocation.allocation_count,
        allocation.allocation_total_usd
    FROM payment
    JOIN eligible_attempt_summary AS attempt
        ON attempt.payment_id = payment.payment_id
    JOIN allocation_summary AS allocation
        ON allocation.payment_id = payment.payment_id
), latest_refund_status AS (
    SELECT
        status_event.refund_id,
        status_event.refund_status_code,
        ROW_NUMBER() OVER (
            PARTITION BY status_event.refund_id
            ORDER BY status_event.status_at DESC, status_event.refund_status_event_id DESC
        ) AS latest_rank
    FROM refund_status_event AS status_event
), reopened_refund AS (
    SELECT
        original_allocation.payment_obligation_id,
        SUM(refund_allocation.refund_allocated_amount_usd) AS reopened_amount_usd
    FROM refund_allocation
    JOIN latest_refund_status AS refund_status
        ON refund_status.refund_id = refund_allocation.refund_id
       AND refund_status.latest_rank = 1
       AND refund_status.refund_status_code = 'COMPLETED'
    JOIN payment_allocation AS original_allocation
        ON original_allocation.payment_allocation_id = refund_allocation.payment_allocation_id
    WHERE refund_allocation.reopens_obligation_flag = 1
    GROUP BY original_allocation.payment_obligation_id
), obligation_allocation AS (
    SELECT
        obligation.payment_obligation_id,
        obligation.obligation_number,
        obligation.original_obligation_amount_usd,
        COALESCE(SUM(adjustment.adjustment_amount_usd), 0.00) AS adjustment_total_usd,
        COALESCE((
            SELECT SUM(allocation.allocated_amount_usd)
            FROM payment_allocation AS allocation
            WHERE allocation.payment_obligation_id = obligation.payment_obligation_id
        ), 0.00) AS allocation_total_usd,
        COALESCE(reopened.reopened_amount_usd, 0.00) AS reopened_amount_usd
    FROM payment_obligation AS obligation
    LEFT JOIN payment_obligation_adjustment AS adjustment
        ON adjustment.payment_obligation_id = obligation.payment_obligation_id
    LEFT JOIN reopened_refund AS reopened
        ON reopened.payment_obligation_id = obligation.payment_obligation_id
    GROUP BY
        obligation.payment_obligation_id,
        obligation.obligation_number,
        obligation.original_obligation_amount_usd,
        reopened.reopened_amount_usd
)
SELECT
    summary.payment_id,
    summary.payment_number,
    CAST(NULL AS UNSIGNED) AS payment_allocation_id,
    CAST(NULL AS UNSIGNED) AS payment_obligation_id,
    'PAYMENT_FUNDING_MISMATCH' AS issue_code,
    CONCAT(
        'eligible attempts=', summary.eligible_attempt_count,
        '; received=', COALESCE(summary.eligible_received_amount_usd, 0.00),
        '; allocated=', summary.allocation_total_usd
    ) AS issue_detail
FROM payment_summary AS summary
WHERE (summary.allocation_count > 0 OR summary.eligible_attempt_count > 0)
  AND (
      summary.eligible_attempt_count <> 1
      OR summary.allocation_count = 0
      OR summary.allocation_total_usd <> summary.eligible_received_amount_usd
  )

UNION ALL

SELECT
    payment.payment_id,
    payment.payment_number,
    allocation.payment_allocation_id,
    allocation.payment_obligation_id,
    'ALLOCATION_CONTRACT_MISMATCH',
    CONCAT(
        'Payment Contract=', payment.membership_contract_id,
        '; Obligation Contract=', obligation.membership_contract_id
    )
FROM payment_allocation AS allocation
JOIN payment
    ON payment.payment_id = allocation.payment_id
JOIN payment_obligation AS obligation
    ON obligation.payment_obligation_id = allocation.payment_obligation_id
WHERE payment.membership_contract_id <> obligation.membership_contract_id

UNION ALL

SELECT
    payment.payment_id,
    payment.payment_number,
    allocation.payment_allocation_id,
    allocation.payment_obligation_id,
    'OBLIGATION_ALLOCATION_EXCEEDED',
    CONCAT(
        'Allocated=', obligation_summary.allocation_total_usd,
        '; collectible=',
        GREATEST(
            obligation_summary.original_obligation_amount_usd
            - obligation_summary.adjustment_total_usd
            + obligation_summary.reopened_amount_usd,
            0.00
        )
    )
FROM payment_allocation AS allocation
JOIN payment
    ON payment.payment_id = allocation.payment_id
JOIN obligation_allocation AS obligation_summary
    ON obligation_summary.payment_obligation_id = allocation.payment_obligation_id
WHERE obligation_summary.allocation_total_usd >
      GREATEST(
          obligation_summary.original_obligation_amount_usd
          - obligation_summary.adjustment_total_usd
          + obligation_summary.reopened_amount_usd,
          0.00
      );

-- 14. Refund initial status, transition, and terminal-state checks
CREATE VIEW vw_dq_refund_status_integrity AS
WITH ranked_status AS (
    SELECT
        status_event.refund_status_event_id,
        status_event.refund_id,
        status_event.refund_status_code,
        status_event.status_at,
        ROW_NUMBER() OVER (
            PARTITION BY status_event.refund_id
            ORDER BY status_event.status_at, status_event.refund_status_event_id
        ) AS status_sequence,
        LAG(status_event.refund_status_code) OVER (
            PARTITION BY status_event.refund_id
            ORDER BY status_event.status_at, status_event.refund_status_event_id
        ) AS previous_status_code,
        LAG(status_event.status_at) OVER (
            PARTITION BY status_event.refund_id
            ORDER BY status_event.status_at, status_event.refund_status_event_id
        ) AS previous_status_at
    FROM refund_status_event AS status_event
), refund_summary AS (
    SELECT
        refund.refund_id,
        refund.refund_number,
        refund.requested_at,
        COUNT(status.refund_status_event_id) AS status_count,
        SUM(status.refund_status_code = 'PENDING') AS pending_count,
        MAX(CASE WHEN status.status_sequence = 1 THEN status.refund_status_code END)
            AS first_status_code,
        MAX(CASE WHEN status.status_sequence = 1 THEN status.status_at END)
            AS first_status_at
    FROM refund
    LEFT JOIN ranked_status AS status
        ON status.refund_id = refund.refund_id
    GROUP BY refund.refund_id, refund.refund_number, refund.requested_at
)
SELECT
    summary.refund_id,
    summary.refund_number,
    CAST(NULL AS UNSIGNED) AS refund_status_event_id,
    'INVALID_INITIAL_REFUND_STATUS' AS issue_code,
    CONCAT(
        'Expected one initial PENDING at ', summary.requested_at,
        '; count=', summary.status_count,
        '; pending=', summary.pending_count,
        '; first=', COALESCE(summary.first_status_code, 'MISSING')
    ) AS issue_detail
FROM refund_summary AS summary
WHERE summary.status_count = 0
   OR summary.pending_count <> 1
   OR summary.first_status_code <> 'PENDING'
   OR summary.first_status_at <> summary.requested_at

UNION ALL

SELECT
    refund.refund_id,
    refund.refund_number,
    status.refund_status_event_id,
    'INVALID_REFUND_STATUS_SEQUENCE',
    CONCAT(
        'Invalid transition from ', COALESCE(status.previous_status_code, 'NONE'),
        ' to ', status.refund_status_code, ' at ', status.status_at
    )
FROM ranked_status AS status
JOIN refund
    ON refund.refund_id = status.refund_id
WHERE (status.previous_status_at IS NOT NULL AND status.status_at <= status.previous_status_at)
   OR (
       status.status_sequence > 1
       AND NOT (
           status.previous_status_code = 'PENDING'
           AND status.refund_status_code IN ('COMPLETED', 'FAILED', 'CANCELLED')
       )
   );

-- 15. Refund completion, source-Payment, allocation, and ceiling reconciliation
CREATE VIEW vw_dq_refund_reconciliation AS
WITH latest_refund_status AS (
    SELECT
        status_event.refund_id,
        status_event.refund_status_code,
        status_event.status_at,
        ROW_NUMBER() OVER (
            PARTITION BY status_event.refund_id
            ORDER BY status_event.status_at DESC, status_event.refund_status_event_id DESC
        ) AS latest_rank
    FROM refund_status_event AS status_event
), completed_refund AS (
    SELECT
        refund.*,
        status.status_at AS completed_at
    FROM refund
    JOIN latest_refund_status AS status
        ON status.refund_id = refund.refund_id
       AND status.latest_rank = 1
       AND status.refund_status_code = 'COMPLETED'
), latest_attempt_status AS (
    SELECT
        attempt.payment_attempt_id,
        attempt.payment_id,
        attempt.attempted_amount_usd,
        status_event.attempt_status_code,
        ROW_NUMBER() OVER (
            PARTITION BY attempt.payment_attempt_id
            ORDER BY status_event.status_at DESC,
                     status_event.payment_attempt_status_event_id DESC
        ) AS latest_rank
    FROM payment_attempt AS attempt
    LEFT JOIN payment_attempt_status_event AS status_event
        ON status_event.payment_attempt_id = attempt.payment_attempt_id
), payment_funding AS (
    SELECT
        payment.payment_id,
        SUM(
            CASE
                WHEN attempt.latest_rank = 1
                 AND attempt.attempt_status_code IN ('SUCCESSFUL', 'SETTLED')
                THEN 1 ELSE 0
            END
        ) AS eligible_attempt_count,
        MAX(
            CASE
                WHEN attempt.latest_rank = 1
                 AND attempt.attempt_status_code IN ('SUCCESSFUL', 'SETTLED')
                THEN attempt.attempted_amount_usd
            END
        ) AS eligible_received_amount_usd
    FROM payment
    LEFT JOIN latest_attempt_status AS attempt
        ON attempt.payment_id = payment.payment_id
       AND attempt.latest_rank = 1
    GROUP BY payment.payment_id
), refund_summary AS (
    SELECT
        completed.refund_id,
        completed.refund_number,
        completed.payment_id,
        completed.refund_amount_usd,
        completed.completed_at,
        COUNT(allocation.refund_allocation_id) AS allocation_count,
        COALESCE(SUM(allocation.refund_allocated_amount_usd), 0.00)
            AS allocation_total_usd
    FROM completed_refund AS completed
    LEFT JOIN refund_allocation AS allocation
        ON allocation.refund_id = completed.refund_id
    GROUP BY
        completed.refund_id,
        completed.refund_number,
        completed.payment_id,
        completed.refund_amount_usd,
        completed.completed_at
), payment_refund_summary AS (
    SELECT
        completed.payment_id,
        SUM(completed.refund_amount_usd) AS completed_refund_total_usd
    FROM completed_refund AS completed
    GROUP BY completed.payment_id
), allocation_refund_summary AS (
    SELECT
        original_allocation.payment_allocation_id,
        original_allocation.allocated_amount_usd,
        COALESCE(SUM(
            CASE
                WHEN completed_refund.refund_id IS NOT NULL
                THEN refund_allocation.refund_allocated_amount_usd
                ELSE 0.00
            END
        ), 0.00)
            AS completed_refund_allocation_total_usd
    FROM payment_allocation AS original_allocation
    LEFT JOIN refund_allocation
        ON refund_allocation.payment_allocation_id
            = original_allocation.payment_allocation_id
    LEFT JOIN completed_refund
        ON completed_refund.refund_id = refund_allocation.refund_id
    GROUP BY
        original_allocation.payment_allocation_id,
        original_allocation.allocated_amount_usd
)
SELECT
    summary.refund_id,
    summary.refund_number,
    CAST(NULL AS UNSIGNED) AS refund_allocation_id,
    CAST(NULL AS UNSIGNED) AS payment_allocation_id,
    'REFUND_ALLOCATION_MISMATCH' AS issue_code,
    CONCAT(
        'Refund=', summary.refund_amount_usd,
        '; allocation total=', summary.allocation_total_usd,
        '; allocation count=', summary.allocation_count
    ) AS issue_detail
FROM refund_summary AS summary
WHERE summary.allocation_count = 0
   OR summary.allocation_total_usd <> summary.refund_amount_usd

UNION ALL

SELECT
    completed.refund_id,
    completed.refund_number,
    refund_allocation.refund_allocation_id,
    refund_allocation.payment_allocation_id,
    'REFUND_PAYMENT_MISMATCH',
    CONCAT(
        'Refund Payment=', completed.payment_id,
        '; original Allocation Payment=', original_allocation.payment_id
    )
FROM completed_refund AS completed
JOIN refund_allocation
    ON refund_allocation.refund_id = completed.refund_id
JOIN payment_allocation AS original_allocation
    ON original_allocation.payment_allocation_id = refund_allocation.payment_allocation_id
WHERE original_allocation.payment_id <> completed.payment_id

UNION ALL

SELECT
    completed.refund_id,
    completed.refund_number,
    CAST(NULL AS UNSIGNED),
    CAST(NULL AS UNSIGNED),
    'PAYMENT_REFUND_CEILING_EXCEEDED',
    CONCAT(
        'Completed refunds=', payment_refund.completed_refund_total_usd,
        '; eligible received=', COALESCE(funding.eligible_received_amount_usd, 0.00),
        '; eligible attempts=', funding.eligible_attempt_count
    )
FROM completed_refund AS completed
JOIN payment_refund_summary AS payment_refund
    ON payment_refund.payment_id = completed.payment_id
LEFT JOIN payment_funding AS funding
    ON funding.payment_id = completed.payment_id
WHERE COALESCE(funding.eligible_attempt_count, 0) <> 1
   OR payment_refund.completed_refund_total_usd
      > COALESCE(funding.eligible_received_amount_usd, 0.00)

UNION ALL

SELECT
    refund.refund_id,
    refund.refund_number,
    CAST(NULL AS UNSIGNED),
    CAST(NULL AS UNSIGNED),
    'INVALID_REFUND_REQUEST',
    CONCAT(
        'requested_at=', refund.requested_at,
        '; eligible attempts=', COALESCE(funding.eligible_attempt_count, 0),
        '; refund=', refund.refund_amount_usd,
        '; eligible received=', COALESCE(funding.eligible_received_amount_usd, 0.00)
    )
FROM refund
JOIN payment
    ON payment.payment_id = refund.payment_id
LEFT JOIN payment_funding AS funding
    ON funding.payment_id = refund.payment_id
WHERE refund.requested_at < payment.requested_at
   OR COALESCE(funding.eligible_attempt_count, 0) <> 1
   OR refund.refund_amount_usd > COALESCE(funding.eligible_received_amount_usd, 0.00)
   OR EXISTS (
       SELECT 1
       FROM vw_dq_payment_reconciliation AS payment_issue
       WHERE payment_issue.payment_id = refund.payment_id
   )

UNION ALL

SELECT
    completed.refund_id,
    completed.refund_number,
    refund_allocation.refund_allocation_id,
    refund_allocation.payment_allocation_id,
    'INVALID_REFUND_ALLOCATION_TIMELINE',
    CONCAT(
        'allocation recorded=', refund_allocation.recorded_at,
        '; requested=', completed.requested_at,
        '; completed=', completed.completed_at
    )
FROM completed_refund AS completed
JOIN refund_allocation
    ON refund_allocation.refund_id = completed.refund_id
WHERE refund_allocation.recorded_at < completed.requested_at
   OR refund_allocation.recorded_at > completed.completed_at

UNION ALL

SELECT
    completed.refund_id,
    completed.refund_number,
    refund_allocation.refund_allocation_id,
    refund_allocation.payment_allocation_id,
    'ALLOCATION_REFUND_CEILING_EXCEEDED',
    CONCAT(
        'Completed allocation refunds=',
        allocation_summary.completed_refund_allocation_total_usd,
        '; original allocation=', allocation_summary.allocated_amount_usd
    )
FROM completed_refund AS completed
JOIN refund_allocation
    ON refund_allocation.refund_id = completed.refund_id
JOIN allocation_refund_summary AS allocation_summary
    ON allocation_summary.payment_allocation_id = refund_allocation.payment_allocation_id
WHERE allocation_summary.completed_refund_allocation_total_usd
      > allocation_summary.allocated_amount_usd

UNION ALL

SELECT
    refund.refund_id,
    refund.refund_number,
    allocation.refund_allocation_id,
    allocation.payment_allocation_id,
    'ALLOCATION_ON_NONCOMPLETED_REFUND',
    'Refund Allocation exists while the Refund is not currently Completed'
FROM refund
JOIN refund_allocation AS allocation
    ON allocation.refund_id = refund.refund_id
LEFT JOIN completed_refund
    ON completed_refund.refund_id = refund.refund_id
WHERE completed_refund.refund_id IS NULL;

-- 16. Canonical financial issue feed normalized from all approved financial checks
CREATE VIEW vw_dq_financial_source_issue AS
SELECT
    'CONTRACT' AS affected_source_domain_code,
    contract_issue.contract_number AS affected_source_record_reference,
    CASE
        WHEN contract_issue.issue_code = 'FINANCIAL_BRANCH_MISMATCH'
        THEN 'INVALID_BRANCH'
        WHEN contract_issue.issue_code = 'INVALID_PREDECESSOR'
        THEN 'ORPHAN_REFERENCE'
        ELSE 'INVALID_STATUS'
    END AS exception_type_code,
    'CRITICAL' AS severity_code,
    contract.historical_list_price_usd - contract.discount_amount_usd
        AS affected_amount_usd,
    UTC_TIMESTAMP(6) AS detected_at,
    contract_issue.issue_code AS source_issue_code,
    contract_issue.issue_detail
FROM vw_dq_contract_integrity AS contract_issue
JOIN membership_contract AS contract
    ON contract.membership_contract_id = contract_issue.membership_contract_id

UNION ALL

SELECT
    'CONTRACT' AS affected_source_domain_code,
    schedule.contract_number AS affected_source_record_reference,
    'RECONCILIATION_DIFFERENCE' AS exception_type_code,
    'CRITICAL' AS severity_code,
    ABS(schedule.expected_revenue_usd - schedule.obligation_total_usd)
        AS affected_amount_usd,
    UTC_TIMESTAMP(6) AS detected_at,
    schedule.issue_code AS source_issue_code,
    schedule.issue_detail
FROM vw_dq_obligation_schedule AS schedule

UNION ALL

SELECT
    'OBLIGATION_ADJUSTMENT',
    CAST(adjustment.payment_obligation_adjustment_id AS CHAR),
    CASE
        WHEN adjustment.issue_code = 'INVALID_CANCELLATION_TARGET'
        THEN 'ORPHAN_REFERENCE'
        ELSE 'RECONCILIATION_DIFFERENCE'
    END,
    'CRITICAL',
    ABS(adjustment.adjustment_amount_usd - adjustment.expected_adjustment_amount_usd),
    UTC_TIMESTAMP(6),
    adjustment.issue_code,
    adjustment.issue_detail
FROM vw_dq_cancellation_adjustment AS adjustment

UNION ALL

SELECT
    CASE WHEN attempt.payment_attempt_id IS NULL THEN 'PAYMENT' ELSE 'PAYMENT_ATTEMPT' END,
    CASE
        WHEN attempt.payment_attempt_id IS NULL THEN payment.payment_number
        ELSE COALESCE(payment_attempt.attempt_number, CAST(attempt.payment_attempt_id AS CHAR))
    END,
    CASE
        WHEN attempt.issue_code = 'INVALID_ATTEMPT_DEFINITION'
        THEN 'INVALID_AMOUNT'
        ELSE 'INVALID_STATUS'
    END,
    'CRITICAL',
    0.00,
    UTC_TIMESTAMP(6),
    attempt.issue_code,
    attempt.issue_detail
FROM vw_dq_payment_attempt_integrity AS attempt
JOIN payment
    ON payment.payment_id = attempt.payment_id
LEFT JOIN payment_attempt
    ON payment_attempt.payment_attempt_id = attempt.payment_attempt_id

UNION ALL

SELECT
    CASE
        WHEN reconciliation.payment_allocation_id IS NOT NULL
        THEN 'PAYMENT_ALLOCATION'
        ELSE 'PAYMENT'
    END,
    CASE
        WHEN reconciliation.payment_allocation_id IS NOT NULL
        THEN CAST(reconciliation.payment_allocation_id AS CHAR)
        ELSE reconciliation.payment_number
    END,
    CASE
        WHEN reconciliation.issue_code = 'ALLOCATION_CONTRACT_MISMATCH'
        THEN 'ORPHAN_REFERENCE'
        WHEN reconciliation.issue_code = 'OBLIGATION_ALLOCATION_EXCEEDED'
        THEN 'EXCESSIVE_ALLOCATION'
        ELSE 'RECONCILIATION_DIFFERENCE'
    END,
    'CRITICAL',
    0.00,
    UTC_TIMESTAMP(6),
    reconciliation.issue_code,
    reconciliation.issue_detail
FROM vw_dq_payment_reconciliation AS reconciliation

UNION ALL

SELECT
    'REFUND',
    refund_status.refund_number,
    'INVALID_STATUS',
    'CRITICAL',
    0.00,
    UTC_TIMESTAMP(6),
    refund_status.issue_code,
    refund_status.issue_detail
FROM vw_dq_refund_status_integrity AS refund_status

UNION ALL

SELECT
    CASE
        WHEN reconciliation.refund_allocation_id IS NOT NULL
        THEN 'REFUND_ALLOCATION'
        ELSE 'REFUND'
    END,
    CASE
        WHEN reconciliation.refund_allocation_id IS NOT NULL
        THEN CAST(reconciliation.refund_allocation_id AS CHAR)
        ELSE reconciliation.refund_number
    END,
    CASE
        WHEN reconciliation.issue_code IN (
            'PAYMENT_REFUND_CEILING_EXCEEDED',
            'ALLOCATION_REFUND_CEILING_EXCEEDED'
        ) THEN 'EXCESSIVE_REFUND'
        WHEN reconciliation.issue_code = 'REFUND_PAYMENT_MISMATCH'
        THEN 'ORPHAN_REFERENCE'
        ELSE 'RECONCILIATION_DIFFERENCE'
    END,
    'CRITICAL',
    0.00,
    UTC_TIMESTAMP(6),
    reconciliation.issue_code,
    reconciliation.issue_detail
FROM vw_dq_refund_reconciliation AS reconciliation;

-- 17. Financial Exception identity, workflow, disposition, and resolution checks
CREATE VIEW vw_dq_financial_exception_integrity AS
WITH ranked_status AS (
    SELECT
        status_event.financial_exception_status_event_id,
        status_event.financial_exception_id,
        status_event.exception_status_code,
        status_event.status_at,
        status_event.reporting_disposition_code,
        status_event.review_note,
        status_event.resolution_note,
        ROW_NUMBER() OVER (
            PARTITION BY status_event.financial_exception_id
            ORDER BY status_event.status_at,
                     status_event.financial_exception_status_event_id
        ) AS status_sequence,
        LAG(status_event.exception_status_code) OVER (
            PARTITION BY status_event.financial_exception_id
            ORDER BY status_event.status_at,
                     status_event.financial_exception_status_event_id
        ) AS previous_status_code,
        LAG(status_event.status_at) OVER (
            PARTITION BY status_event.financial_exception_id
            ORDER BY status_event.status_at,
                     status_event.financial_exception_status_event_id
        ) AS previous_status_at,
        ROW_NUMBER() OVER (
            PARTITION BY status_event.financial_exception_id
            ORDER BY status_event.status_at DESC,
                     status_event.financial_exception_status_event_id DESC
        ) AS latest_rank
    FROM financial_exception_status_event AS status_event
), exception_summary AS (
    SELECT
        exception_record.financial_exception_id,
        exception_record.exception_number,
        exception_record.severity_code,
        exception_record.detected_at,
        COUNT(status.financial_exception_status_event_id) AS status_count,
        SUM(status.exception_status_code = 'OPEN') AS open_count,
        MAX(CASE WHEN status.status_sequence = 1 THEN status.exception_status_code END)
            AS first_status_code,
        MAX(CASE WHEN status.status_sequence = 1 THEN status.status_at END)
            AS first_status_at,
        MAX(CASE WHEN status.latest_rank = 1 THEN status.exception_status_code END)
            AS latest_status_code,
        MAX(CASE WHEN status.latest_rank = 1 THEN status.reporting_disposition_code END)
            AS latest_disposition_code
    FROM financial_exception AS exception_record
    LEFT JOIN ranked_status AS status
        ON status.financial_exception_id = exception_record.financial_exception_id
    GROUP BY
        exception_record.financial_exception_id,
        exception_record.exception_number,
        exception_record.severity_code,
        exception_record.detected_at
), unresolved_identity AS (
    SELECT
        exception_record.affected_source_domain_code,
        exception_record.affected_source_record_reference,
        exception_record.exception_type_code,
        COUNT(*) AS unresolved_count,
        COUNT(DISTINCT exception_record.affected_amount_usd) AS distinct_amount_count
    FROM financial_exception AS exception_record
    JOIN exception_summary AS summary
        ON summary.financial_exception_id = exception_record.financial_exception_id
    WHERE summary.latest_status_code IN ('OPEN', 'UNDER_REVIEW')
    GROUP BY
        exception_record.affected_source_domain_code,
        exception_record.affected_source_record_reference,
        exception_record.exception_type_code
)
SELECT
    summary.financial_exception_id,
    summary.exception_number,
    CAST(NULL AS UNSIGNED) AS financial_exception_status_event_id,
    'INVALID_INITIAL_EXCEPTION_STATUS' AS issue_code,
    CONCAT(
        'Expected initial OPEN at ', summary.detected_at,
        '; count=', summary.status_count,
        '; open=', summary.open_count,
        '; first=', COALESCE(summary.first_status_code, 'MISSING')
    ) AS issue_detail
FROM exception_summary AS summary
WHERE summary.status_count = 0
   OR summary.open_count < 1
   OR summary.first_status_code <> 'OPEN'
   OR summary.first_status_at <> summary.detected_at

UNION ALL

SELECT
    exception_record.financial_exception_id,
    exception_record.exception_number,
    status.financial_exception_status_event_id,
    'INVALID_EXCEPTION_STATUS_SEQUENCE',
    CONCAT(
        'Invalid transition from ', COALESCE(status.previous_status_code, 'NONE'),
        ' to ', status.exception_status_code, ' at ', status.status_at
    )
FROM ranked_status AS status
JOIN financial_exception AS exception_record
    ON exception_record.financial_exception_id = status.financial_exception_id
WHERE (status.previous_status_at IS NOT NULL AND status.status_at <= status.previous_status_at)
   OR (
       status.status_sequence > 1
       AND NOT (
           (status.previous_status_code = 'OPEN'
            AND status.exception_status_code IN ('OPEN', 'UNDER_REVIEW', 'RESOLVED'))
           OR (status.previous_status_code = 'UNDER_REVIEW'
               AND status.exception_status_code IN ('UNDER_REVIEW', 'RESOLVED'))
       )
   )

UNION ALL

SELECT
    exception_record.financial_exception_id,
    exception_record.exception_number,
    status.financial_exception_status_event_id,
    'INVALID_EXCEPTION_DISPOSITION',
    CONCAT(
        'severity=', exception_record.severity_code,
        '; status=', status.exception_status_code,
        '; disposition=', status.reporting_disposition_code
    )
FROM ranked_status AS status
JOIN financial_exception AS exception_record
    ON exception_record.financial_exception_id = status.financial_exception_id
WHERE (status.exception_status_code IN ('OPEN', 'UNDER_REVIEW')
       AND status.reporting_disposition_code = 'ELIGIBLE')
   OR (status.exception_status_code IN ('OPEN', 'UNDER_REVIEW')
       AND exception_record.severity_code = 'CRITICAL'
       AND status.reporting_disposition_code <> 'EXCLUDED')
   OR (status.exception_status_code IN ('OPEN', 'UNDER_REVIEW')
       AND exception_record.severity_code = 'WARNING'
       AND status.reporting_disposition_code = 'INCLUDED_WITH_WARNING'
       AND (status.review_note IS NULL OR CHAR_LENGTH(TRIM(status.review_note)) = 0))
   OR (status.exception_status_code = 'RESOLVED'
       AND (status.resolution_note IS NULL OR CHAR_LENGTH(TRIM(status.resolution_note)) = 0))

UNION ALL

SELECT
    exception_record.financial_exception_id,
    exception_record.exception_number,
    CAST(NULL AS UNSIGNED),
    'DUPLICATE_UNRESOLVED_EXCEPTION',
    CONCAT('Matching unresolved identity count=', identity_summary.unresolved_count)
FROM financial_exception AS exception_record
JOIN exception_summary AS summary
    ON summary.financial_exception_id = exception_record.financial_exception_id
JOIN unresolved_identity AS identity_summary
    ON identity_summary.affected_source_domain_code
        = exception_record.affected_source_domain_code
   AND identity_summary.affected_source_record_reference
        = exception_record.affected_source_record_reference
   AND identity_summary.exception_type_code = exception_record.exception_type_code
WHERE summary.latest_status_code IN ('OPEN', 'UNDER_REVIEW')
  AND identity_summary.unresolved_count > 1

UNION ALL

SELECT
    exception_record.financial_exception_id,
    exception_record.exception_number,
    CAST(NULL AS UNSIGNED),
    'INCONSISTENT_ACTIVE_AFFECTED_AMOUNT',
    'Matching unresolved Exception identities contain inconsistent affected amounts'
FROM financial_exception AS exception_record
JOIN exception_summary AS summary
    ON summary.financial_exception_id = exception_record.financial_exception_id
JOIN unresolved_identity AS identity_summary
    ON identity_summary.affected_source_domain_code
        = exception_record.affected_source_domain_code
   AND identity_summary.affected_source_record_reference
        = exception_record.affected_source_record_reference
   AND identity_summary.exception_type_code = exception_record.exception_type_code
WHERE summary.latest_status_code IN ('OPEN', 'UNDER_REVIEW')
  AND identity_summary.distinct_amount_count > 1

UNION ALL

SELECT
    exception_record.financial_exception_id,
    exception_record.exception_number,
    status.financial_exception_status_event_id,
    'ELIGIBLE_RESOLUTION_STILL_FAILS_VALIDATION',
    'Resolved Exception was made Eligible while its canonical source issue still exists'
FROM ranked_status AS status
JOIN financial_exception AS exception_record
    ON exception_record.financial_exception_id = status.financial_exception_id
WHERE status.latest_rank = 1
  AND status.exception_status_code = 'RESOLVED'
  AND status.reporting_disposition_code = 'ELIGIBLE'
  AND EXISTS (
      SELECT 1
      FROM vw_dq_financial_source_issue AS source_issue
      WHERE source_issue.affected_source_domain_code
                = exception_record.affected_source_domain_code
        AND source_issue.affected_source_record_reference
                = exception_record.affected_source_record_reference
        AND source_issue.exception_type_code = exception_record.exception_type_code
  );

-- 18. Time-effective Exception dispositions with derived Financial Branch attribution
CREATE VIEW vw_reporting_financial_source_disposition AS
WITH source_branch AS (
    SELECT 'CONTRACT' AS source_domain_code,
           contract.contract_number AS source_reference,
           contract.financial_ownership_branch_id
    FROM membership_contract AS contract

    UNION ALL

    SELECT 'OBLIGATION', obligation.obligation_number,
           contract.financial_ownership_branch_id
    FROM payment_obligation AS obligation
    JOIN membership_contract AS contract
        ON contract.membership_contract_id = obligation.membership_contract_id

    UNION ALL

    SELECT 'OBLIGATION_ADJUSTMENT', CAST(adjustment.payment_obligation_adjustment_id AS CHAR),
           contract.financial_ownership_branch_id
    FROM payment_obligation_adjustment AS adjustment
    JOIN payment_obligation AS obligation
        ON obligation.payment_obligation_id = adjustment.payment_obligation_id
    JOIN membership_contract AS contract
        ON contract.membership_contract_id = obligation.membership_contract_id

    UNION ALL

    SELECT 'PAYMENT', payment.payment_number,
           contract.financial_ownership_branch_id
    FROM payment
    JOIN membership_contract AS contract
        ON contract.membership_contract_id = payment.membership_contract_id

    UNION ALL

    SELECT 'PAYMENT_ATTEMPT', attempt.attempt_number,
           contract.financial_ownership_branch_id
    FROM payment_attempt AS attempt
    JOIN payment
        ON payment.payment_id = attempt.payment_id
    JOIN membership_contract AS contract
        ON contract.membership_contract_id = payment.membership_contract_id

    UNION ALL

    SELECT 'PAYMENT_ALLOCATION', CAST(allocation.payment_allocation_id AS CHAR),
           contract.financial_ownership_branch_id
    FROM payment_allocation AS allocation
    JOIN payment
        ON payment.payment_id = allocation.payment_id
    JOIN membership_contract AS contract
        ON contract.membership_contract_id = payment.membership_contract_id

    UNION ALL

    SELECT 'REFUND', refund.refund_number,
           contract.financial_ownership_branch_id
    FROM refund
    JOIN payment
        ON payment.payment_id = refund.payment_id
    JOIN membership_contract AS contract
        ON contract.membership_contract_id = payment.membership_contract_id

    UNION ALL

    SELECT 'REFUND_ALLOCATION', CAST(refund_allocation.refund_allocation_id AS CHAR),
           contract.financial_ownership_branch_id
    FROM refund_allocation
    JOIN refund
        ON refund.refund_id = refund_allocation.refund_id
    JOIN payment
        ON payment.payment_id = refund.payment_id
    JOIN membership_contract AS contract
        ON contract.membership_contract_id = payment.membership_contract_id
), effective_status AS (
    SELECT
        status_event.*,
        LEAD(status_event.status_at) OVER (
            PARTITION BY status_event.financial_exception_id
            ORDER BY status_event.status_at,
                     status_event.financial_exception_status_event_id
        ) AS effective_to
    FROM financial_exception_status_event AS status_event
)
SELECT
    exception_record.financial_exception_id,
    exception_record.exception_number,
    exception_record.affected_source_domain_code,
    exception_record.affected_source_record_reference,
    exception_record.exception_type_code,
    exception_record.severity_code,
    exception_record.affected_amount_usd,
    exception_record.detected_at,
    status.financial_exception_status_event_id,
    status.exception_status_code,
    status.status_at AS effective_from,
    status.effective_to,
    status.assigned_owner_code,
    status.reporting_disposition_code,
    status.review_note,
    status.resolution_note,
    source_branch.financial_ownership_branch_id,
    CASE
        WHEN source_branch.financial_ownership_branch_id IS NULL THEN 'NOT_ATTRIBUTABLE'
        ELSE 'ATTRIBUTED'
    END AS branch_attribution_status
FROM financial_exception AS exception_record
JOIN effective_status AS status
    ON status.financial_exception_id = exception_record.financial_exception_id
LEFT JOIN source_branch
    ON source_branch.source_domain_code = exception_record.affected_source_domain_code
   AND source_branch.source_reference = exception_record.affected_source_record_reference;

-- 19. Reproducible Financial Exception workflow facts for operational reporting
CREATE VIEW vw_reporting_financial_exception AS
SELECT
    disposition.financial_exception_id,
    disposition.exception_number,
    disposition.affected_source_domain_code,
    disposition.affected_source_record_reference,
    disposition.exception_type_code,
    disposition.severity_code,
    disposition.affected_amount_usd,
    disposition.detected_at,
    disposition.financial_exception_status_event_id,
    disposition.exception_status_code,
    disposition.effective_from,
    disposition.effective_to,
    disposition.assigned_owner_code,
    disposition.reporting_disposition_code,
    disposition.review_note,
    disposition.resolution_note,
    disposition.financial_ownership_branch_id,
    disposition.branch_attribution_status,
    (disposition.exception_status_code IN ('OPEN', 'UNDER_REVIEW'))
        AS unresolved_flag
FROM vw_reporting_financial_source_disposition AS disposition;

-- 20. Current exception KPIs with source-level amount deduplication
CREATE VIEW vw_reporting_financial_exception_summary AS
WITH latest_exception AS (
    SELECT
        reporting.*,
        ROW_NUMBER() OVER (
            PARTITION BY reporting.financial_exception_id
            ORDER BY reporting.effective_from DESC,
                     reporting.financial_exception_status_event_id DESC
        ) AS latest_rank
    FROM vw_reporting_financial_exception AS reporting
), unresolved_source AS (
    SELECT
        affected_source_domain_code,
        affected_source_record_reference,
        MAX(severity_code = 'CRITICAL') AS has_critical_flag,
        MAX(severity_code = 'WARNING') AS has_warning_flag,
        MAX(
            CASE WHEN severity_code = 'CRITICAL' THEN affected_amount_usd END
        ) AS critical_amount_usd,
        MAX(
            CASE WHEN severity_code = 'WARNING' THEN affected_amount_usd END
        ) AS warning_amount_usd
    FROM latest_exception
    WHERE latest_rank = 1
      AND unresolved_flag = 1
    GROUP BY affected_source_domain_code, affected_source_record_reference
), totals AS (
    SELECT
        (SELECT COUNT(*) FROM financial_exception) AS financial_exception_count,
        (
            SELECT COUNT(*)
            FROM latest_exception
            WHERE latest_rank = 1 AND unresolved_flag = 1
        ) AS unresolved_financial_exception_count,
        (
            SELECT COUNT(*)
            FROM latest_exception
            WHERE latest_rank = 1
              AND unresolved_flag = 1
              AND severity_code = 'CRITICAL'
        ) AS unresolved_critical_exception_count,
        (
            SELECT COUNT(*)
            FROM latest_exception
            WHERE latest_rank = 1
              AND unresolved_flag = 1
              AND severity_code = 'WARNING'
        ) AS unresolved_warning_exception_count,
        COALESCE((
            SELECT SUM(
                CASE
                    WHEN has_critical_flag = 1 THEN COALESCE(critical_amount_usd, 0.00)
                    ELSE COALESCE(warning_amount_usd, 0.00)
                END
            )
            FROM unresolved_source
        ), 0.00) AS financially_affected_amount_usd
)
SELECT
    UTC_TIMESTAMP(6) AS measured_at,
    financial_exception_count,
    unresolved_financial_exception_count,
    unresolved_critical_exception_count,
    unresolved_warning_exception_count,
    financially_affected_amount_usd
FROM totals;

-- 21. Fully reconciled collected amounts by original Payment Allocation
CREATE VIEW vw_reporting_gross_collected_revenue AS
WITH ranked_attempt_status AS (
    SELECT
        attempt.payment_attempt_id,
        attempt.attempt_number,
        attempt.payment_id,
        attempt.attempted_amount_usd,
        attempt.payment_method_code,
        attempt.processing_branch_id,
        status_event.attempt_status_code,
        status_event.status_at,
        ROW_NUMBER() OVER (
            PARTITION BY attempt.payment_attempt_id
            ORDER BY status_event.status_at DESC,
                     status_event.payment_attempt_status_event_id DESC
        ) AS latest_rank,
        MIN(
            CASE
                WHEN status_event.attempt_status_code IN ('SUCCESSFUL', 'SETTLED')
                THEN status_event.status_at
            END
        ) OVER (PARTITION BY attempt.payment_attempt_id) AS collected_at
    FROM payment_attempt AS attempt
    JOIN payment_attempt_status_event AS status_event
        ON status_event.payment_attempt_id = attempt.payment_attempt_id
), eligible_attempt AS (
    SELECT *
    FROM ranked_attempt_status
    WHERE latest_rank = 1
      AND attempt_status_code IN ('SUCCESSFUL', 'SETTLED')
), eligible_payment AS (
    SELECT
        payment.payment_id,
        MAX(attempt.payment_attempt_id) AS payment_attempt_id,
        MAX(attempt.attempt_number) AS attempt_number,
        MAX(attempt.attempted_amount_usd) AS received_amount_usd,
        MAX(attempt.payment_method_code) AS payment_method_code,
        MAX(attempt.processing_branch_id) AS processing_branch_id,
        MAX(attempt.collected_at) AS collected_at,
        COUNT(attempt.payment_attempt_id) AS eligible_attempt_count
    FROM payment
    JOIN eligible_attempt AS attempt
        ON attempt.payment_id = payment.payment_id
    GROUP BY payment.payment_id
    HAVING COUNT(attempt.payment_attempt_id) = 1
), allocation_summary AS (
    SELECT
        payment_id,
        COUNT(*) AS allocation_count,
        SUM(allocated_amount_usd) AS allocated_amount_usd
    FROM payment_allocation
    GROUP BY payment_id
), gross_line AS (
    SELECT
        allocation.payment_allocation_id,
        allocation.allocated_amount_usd AS gross_collected_amount_usd,
        eligible.collected_at AS collected_at_utc,
        CONVERT_TZ(eligible.collected_at, '+00:00', 'Asia/Beirut')
            AS collected_at_beirut,
        payment.payment_id,
        payment.payment_number,
        eligible.payment_attempt_id,
        eligible.attempt_number,
        eligible.payment_method_code,
        eligible.processing_branch_id,
        obligation.payment_obligation_id,
        obligation.obligation_number,
        contract.membership_contract_id,
        contract.contract_number,
        contract.member_id,
        contract.plan_version_id,
        contract.financial_ownership_branch_id
    FROM eligible_payment AS eligible
    JOIN allocation_summary AS payment_allocation_summary
        ON payment_allocation_summary.payment_id = eligible.payment_id
       AND payment_allocation_summary.allocated_amount_usd = eligible.received_amount_usd
    JOIN payment
        ON payment.payment_id = eligible.payment_id
    JOIN payment_allocation AS allocation
        ON allocation.payment_id = payment.payment_id
    JOIN payment_obligation AS obligation
        ON obligation.payment_obligation_id = allocation.payment_obligation_id
       AND obligation.membership_contract_id = payment.membership_contract_id
    JOIN membership_contract AS contract
        ON contract.membership_contract_id = payment.membership_contract_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM vw_dq_payment_reconciliation AS issue
        WHERE issue.payment_id = payment.payment_id
    )
      AND NOT EXISTS (
          SELECT 1
          FROM vw_dq_financial_source_issue AS source_issue
          WHERE (source_issue.affected_source_domain_code = 'CONTRACT'
                 AND source_issue.affected_source_record_reference = contract.contract_number)
             OR (source_issue.affected_source_domain_code = 'OBLIGATION'
                 AND source_issue.affected_source_record_reference = obligation.obligation_number)
             OR (source_issue.affected_source_domain_code = 'PAYMENT'
                 AND source_issue.affected_source_record_reference = payment.payment_number)
             OR (source_issue.affected_source_domain_code = 'PAYMENT_ATTEMPT'
                 AND source_issue.affected_source_record_reference = eligible.attempt_number)
             OR (source_issue.affected_source_domain_code = 'PAYMENT_ALLOCATION'
                 AND source_issue.affected_source_record_reference
                     = CAST(allocation.payment_allocation_id AS CHAR))
      )
), disposition_summary AS (
    SELECT
        gross_line.payment_allocation_id,
        MAX(
            CASE disposition.reporting_disposition_code
                WHEN 'EXCLUDED' THEN 2
                WHEN 'INCLUDED_WITH_WARNING' THEN 1
                ELSE 0
            END
        ) AS worst_disposition_rank
    FROM gross_line
    LEFT JOIN vw_reporting_financial_source_disposition AS disposition
        ON disposition.effective_from <= UTC_TIMESTAMP(6)
       AND (
           disposition.effective_to IS NULL
           OR disposition.effective_to > UTC_TIMESTAMP(6)
       )
       AND (
           (disposition.affected_source_domain_code = 'CONTRACT'
            AND disposition.affected_source_record_reference = gross_line.contract_number)
           OR (disposition.affected_source_domain_code = 'OBLIGATION'
               AND disposition.affected_source_record_reference = gross_line.obligation_number)
           OR (disposition.affected_source_domain_code = 'PAYMENT'
               AND disposition.affected_source_record_reference = gross_line.payment_number)
           OR (disposition.affected_source_domain_code = 'PAYMENT_ATTEMPT'
               AND disposition.affected_source_record_reference = gross_line.attempt_number)
           OR (disposition.affected_source_domain_code = 'PAYMENT_ALLOCATION'
               AND disposition.affected_source_record_reference
                   = CAST(gross_line.payment_allocation_id AS CHAR))
       )
    GROUP BY gross_line.payment_allocation_id
)
SELECT
    gross_line.*,
    (COALESCE(disposition.worst_disposition_rank, 0) = 1) AS reporting_warning_flag
FROM gross_line
LEFT JOIN disposition_summary AS disposition
    ON disposition.payment_allocation_id = gross_line.payment_allocation_id
WHERE COALESCE(disposition.worst_disposition_rank, 0) < 2;

-- 22. Fully reconciled completed Refund amounts by Refund Allocation
CREATE VIEW vw_reporting_refund AS
WITH ranked_refund_status AS (
    SELECT
        status_event.refund_id,
        status_event.refund_status_code,
        status_event.status_at,
        ROW_NUMBER() OVER (
            PARTITION BY status_event.refund_id
            ORDER BY status_event.status_at DESC, status_event.refund_status_event_id DESC
        ) AS latest_rank,
        MIN(
            CASE WHEN status_event.refund_status_code = 'COMPLETED'
                 THEN status_event.status_at END
        ) OVER (PARTITION BY status_event.refund_id) AS completed_at
    FROM refund_status_event AS status_event
), completed_refund AS (
    SELECT
        refund.*,
        status.completed_at
    FROM refund
    JOIN ranked_refund_status AS status
        ON status.refund_id = refund.refund_id
       AND status.latest_rank = 1
       AND status.refund_status_code = 'COMPLETED'
), refund_line AS (
    SELECT
        refund_allocation.refund_allocation_id,
        refund_allocation.refund_allocated_amount_usd AS refund_amount_usd,
        refund_allocation.reopens_obligation_flag,
        completed.completed_at AS refunded_at_utc,
        CONVERT_TZ(completed.completed_at, '+00:00', 'Asia/Beirut')
            AS refunded_at_beirut,
        completed.refund_id,
        completed.refund_number,
        gross.payment_id,
        gross.payment_number,
        gross.payment_attempt_id,
        gross.attempt_number,
        gross.payment_allocation_id,
        gross.payment_obligation_id,
        gross.obligation_number,
        gross.membership_contract_id,
        gross.contract_number,
        gross.member_id,
        gross.plan_version_id,
        gross.financial_ownership_branch_id,
        gross.processing_branch_id,
        gross.reporting_warning_flag AS gross_reporting_warning_flag
    FROM completed_refund AS completed
    JOIN refund_allocation
        ON refund_allocation.refund_id = completed.refund_id
    JOIN vw_reporting_gross_collected_revenue AS gross
        ON gross.payment_allocation_id = refund_allocation.payment_allocation_id
       AND gross.payment_id = completed.payment_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM vw_dq_refund_reconciliation AS issue
        WHERE issue.refund_id = completed.refund_id
    )
      AND NOT EXISTS (
          SELECT 1
          FROM vw_dq_financial_source_issue AS source_issue
          WHERE (source_issue.affected_source_domain_code = 'REFUND'
                 AND source_issue.affected_source_record_reference = completed.refund_number)
             OR (source_issue.affected_source_domain_code = 'REFUND_ALLOCATION'
                 AND source_issue.affected_source_record_reference
                     = CAST(refund_allocation.refund_allocation_id AS CHAR))
      )
), disposition_summary AS (
    SELECT
        refund_line.refund_allocation_id,
        MAX(
            CASE disposition.reporting_disposition_code
                WHEN 'EXCLUDED' THEN 2
                WHEN 'INCLUDED_WITH_WARNING' THEN 1
                ELSE 0
            END
        ) AS worst_disposition_rank
    FROM refund_line
    LEFT JOIN vw_reporting_financial_source_disposition AS disposition
        ON disposition.effective_from <= UTC_TIMESTAMP(6)
       AND (
           disposition.effective_to IS NULL
           OR disposition.effective_to > UTC_TIMESTAMP(6)
       )
       AND (
           (disposition.affected_source_domain_code = 'CONTRACT'
            AND disposition.affected_source_record_reference = refund_line.contract_number)
           OR (disposition.affected_source_domain_code = 'OBLIGATION'
               AND disposition.affected_source_record_reference = refund_line.obligation_number)
           OR (disposition.affected_source_domain_code = 'PAYMENT'
               AND disposition.affected_source_record_reference = refund_line.payment_number)
           OR (disposition.affected_source_domain_code = 'PAYMENT_ATTEMPT'
               AND disposition.affected_source_record_reference = refund_line.attempt_number)
           OR (disposition.affected_source_domain_code = 'PAYMENT_ALLOCATION'
               AND disposition.affected_source_record_reference
                   = CAST(refund_line.payment_allocation_id AS CHAR))
           OR (disposition.affected_source_domain_code = 'REFUND'
               AND disposition.affected_source_record_reference = refund_line.refund_number)
           OR (disposition.affected_source_domain_code = 'REFUND_ALLOCATION'
               AND disposition.affected_source_record_reference
                   = CAST(refund_line.refund_allocation_id AS CHAR))
       )
    GROUP BY refund_line.refund_allocation_id
)
SELECT
    refund_line.*,
    (
        refund_line.gross_reporting_warning_flag = 1
        OR COALESCE(disposition.worst_disposition_rank, 0) = 1
    ) AS reporting_warning_flag
FROM refund_line
LEFT JOIN disposition_summary AS disposition
    ON disposition.refund_allocation_id = refund_line.refund_allocation_id
WHERE COALESCE(disposition.worst_disposition_rank, 0) < 2;

-- 23. Current collectible, applied, reopened, and outstanding Obligation balances
CREATE VIEW vw_reporting_obligation_balance AS
WITH current_disposition AS (
    SELECT *
    FROM vw_reporting_financial_source_disposition
    WHERE effective_from <= UTC_TIMESTAMP(6)
      AND (effective_to IS NULL OR effective_to > UTC_TIMESTAMP(6))
), obligation_line AS (
    SELECT
        obligation.*,
        contract.contract_number,
        contract.member_id,
        contract.plan_version_id,
        contract.financial_ownership_branch_id
    FROM payment_obligation AS obligation
    JOIN membership_contract AS contract
        ON contract.membership_contract_id = obligation.membership_contract_id
), obligation_disposition AS (
    SELECT
        obligation.payment_obligation_id,
        MAX(
            CASE disposition.reporting_disposition_code
                WHEN 'EXCLUDED' THEN 2
                WHEN 'INCLUDED_WITH_WARNING' THEN 1
                ELSE 0
            END
        ) AS worst_disposition_rank
    FROM obligation_line AS obligation
    LEFT JOIN current_disposition AS disposition
        ON (disposition.affected_source_domain_code = 'CONTRACT'
            AND disposition.affected_source_record_reference = obligation.contract_number)
        OR (disposition.affected_source_domain_code = 'OBLIGATION'
            AND disposition.affected_source_record_reference = obligation.obligation_number)
    GROUP BY obligation.payment_obligation_id
), eligible_adjustment AS (
    SELECT
        adjustment.payment_obligation_adjustment_id,
        adjustment.payment_obligation_id,
        adjustment.adjustment_amount_usd,
        MAX(
            CASE disposition.reporting_disposition_code
                WHEN 'EXCLUDED' THEN 2
                WHEN 'INCLUDED_WITH_WARNING' THEN 1
                ELSE 0
            END
        ) AS worst_disposition_rank
    FROM payment_obligation_adjustment AS adjustment
    JOIN obligation_line AS obligation
        ON obligation.payment_obligation_id = adjustment.payment_obligation_id
    LEFT JOIN current_disposition AS disposition
        ON (disposition.affected_source_domain_code = 'CONTRACT'
            AND disposition.affected_source_record_reference = obligation.contract_number)
        OR (disposition.affected_source_domain_code = 'OBLIGATION'
            AND disposition.affected_source_record_reference = obligation.obligation_number)
        OR (disposition.affected_source_domain_code = 'OBLIGATION_ADJUSTMENT'
            AND disposition.affected_source_record_reference
                = CAST(adjustment.payment_obligation_adjustment_id AS CHAR))
    WHERE NOT EXISTS (
        SELECT 1
        FROM vw_dq_financial_source_issue AS source_issue
        WHERE source_issue.affected_source_domain_code = 'OBLIGATION_ADJUSTMENT'
          AND source_issue.affected_source_record_reference
              = CAST(adjustment.payment_obligation_adjustment_id AS CHAR)
    )
    GROUP BY
        adjustment.payment_obligation_adjustment_id,
        adjustment.payment_obligation_id,
        adjustment.adjustment_amount_usd
), adjustment_summary AS (
    SELECT
        payment_obligation_id,
        SUM(adjustment_amount_usd) AS adjustment_amount_usd,
        MAX(worst_disposition_rank = 1) AS reporting_warning_flag
    FROM eligible_adjustment
    WHERE worst_disposition_rank < 2
    GROUP BY payment_obligation_id
), applied_summary AS (
    SELECT
        payment_obligation_id,
        SUM(gross_collected_amount_usd) AS applied_amount_usd,
        MAX(reporting_warning_flag) AS reporting_warning_flag
    FROM vw_reporting_gross_collected_revenue
    GROUP BY payment_obligation_id
), reopened_summary AS (
    SELECT
        payment_obligation_id,
        SUM(
            CASE WHEN reopens_obligation_flag = 1 THEN refund_amount_usd ELSE 0.00 END
        ) AS reopened_amount_usd,
        MAX(reporting_warning_flag) AS reporting_warning_flag
    FROM vw_reporting_refund
    GROUP BY payment_obligation_id
)
SELECT
    obligation.payment_obligation_id,
    obligation.obligation_number,
    obligation.membership_contract_id,
    obligation.contract_number,
    obligation.member_id,
    obligation.plan_version_id,
    obligation.financial_ownership_branch_id,
    obligation.obligation_sequence_number,
    obligation.due_date,
    obligation.original_obligation_amount_usd,
    COALESCE(adjustment.adjustment_amount_usd, 0.00) AS adjustment_amount_usd,
    GREATEST(
        obligation.original_obligation_amount_usd
        - COALESCE(adjustment.adjustment_amount_usd, 0.00),
        0.00
    ) AS collectible_obligation_amount_usd,
    COALESCE(applied.applied_amount_usd, 0.00) AS gross_applied_amount_usd,
    COALESCE(reopened.reopened_amount_usd, 0.00) AS reopened_amount_usd,
    COALESCE(applied.applied_amount_usd, 0.00)
        - COALESCE(reopened.reopened_amount_usd, 0.00) AS net_applied_amount_usd,
    GREATEST(
        obligation.original_obligation_amount_usd
        - COALESCE(adjustment.adjustment_amount_usd, 0.00)
        - COALESCE(applied.applied_amount_usd, 0.00)
        + COALESCE(reopened.reopened_amount_usd, 0.00),
        0.00
    ) AS outstanding_balance_usd,
    (
        COALESCE(obligation_disposition.worst_disposition_rank, 0) = 1
        OR COALESCE(adjustment.reporting_warning_flag, 0) = 1
        OR COALESCE(applied.reporting_warning_flag, 0) = 1
        OR COALESCE(reopened.reporting_warning_flag, 0) = 1
    ) AS reporting_warning_flag
FROM obligation_line AS obligation
JOIN obligation_disposition AS obligation_disposition
    ON obligation_disposition.payment_obligation_id = obligation.payment_obligation_id
LEFT JOIN adjustment_summary AS adjustment
    ON adjustment.payment_obligation_id = obligation.payment_obligation_id
LEFT JOIN applied_summary AS applied
    ON applied.payment_obligation_id = obligation.payment_obligation_id
LEFT JOIN reopened_summary AS reopened
    ON reopened.payment_obligation_id = obligation.payment_obligation_id
WHERE COALESCE(obligation_disposition.worst_disposition_rank, 0) < 2
  AND NOT EXISTS (
      SELECT 1
      FROM vw_dq_financial_source_issue AS source_issue
      WHERE (source_issue.affected_source_domain_code = 'CONTRACT'
             AND source_issue.affected_source_record_reference = obligation.contract_number)
         OR (source_issue.affected_source_domain_code = 'OBLIGATION'
             AND source_issue.affected_source_record_reference = obligation.obligation_number)
  );

-- 24. Transaction-date Net Collected Revenue ledger (Gross minus Refund)
CREATE VIEW vw_reporting_net_collected_revenue AS
SELECT
    CONCAT('PAYMENT_ALLOCATION:', gross.payment_allocation_id) AS revenue_transaction_key,
    'GROSS_COLLECTION' AS revenue_transaction_type,
    gross.collected_at_utc AS transaction_at_utc,
    gross.collected_at_beirut AS transaction_at_beirut,
    DATE(gross.collected_at_beirut) AS transaction_date_beirut,
    gross.gross_collected_amount_usd AS gross_collected_amount_usd,
    0.00 AS refund_amount_usd,
    gross.gross_collected_amount_usd AS net_collected_revenue_usd,
    gross.payment_allocation_id,
    CAST(NULL AS UNSIGNED) AS refund_allocation_id,
    gross.payment_id,
    gross.payment_number,
    gross.membership_contract_id,
    gross.contract_number,
    gross.member_id,
    gross.plan_version_id,
    gross.financial_ownership_branch_id,
    gross.processing_branch_id,
    gross.reporting_warning_flag
FROM vw_reporting_gross_collected_revenue AS gross

UNION ALL

SELECT
    CONCAT('REFUND_ALLOCATION:', refund.refund_allocation_id),
    'REFUND',
    refund.refunded_at_utc,
    refund.refunded_at_beirut,
    DATE(refund.refunded_at_beirut),
    0.00,
    refund.refund_amount_usd,
    -refund.refund_amount_usd,
    refund.payment_allocation_id,
    refund.refund_allocation_id,
    refund.payment_id,
    refund.payment_number,
    refund.membership_contract_id,
    refund.contract_number,
    refund.member_id,
    refund.plan_version_id,
    refund.financial_ownership_branch_id,
    refund.processing_branch_id,
    refund.reporting_warning_flag
FROM vw_reporting_refund AS refund;

-- 25. Current financial release gate with required Critical and Warning disclosure
CREATE VIEW vw_dq_financial_release_readiness AS
WITH latest_exception AS (
    SELECT
        reporting.*,
        ROW_NUMBER() OVER (
            PARTITION BY reporting.financial_exception_id
            ORDER BY reporting.effective_from DESC,
                     reporting.financial_exception_status_event_id DESC
        ) AS latest_rank
    FROM vw_reporting_financial_exception AS reporting
), unresolved_source AS (
    SELECT
        affected_source_domain_code,
        affected_source_record_reference,
        MAX(severity_code = 'CRITICAL') AS has_critical_flag,
        MAX(severity_code = 'WARNING') AS has_warning_flag,
        MAX(
            CASE WHEN severity_code = 'CRITICAL' THEN affected_amount_usd END
        ) AS critical_amount_usd,
        MAX(
            CASE WHEN severity_code = 'WARNING' THEN affected_amount_usd END
        ) AS warning_amount_usd
    FROM latest_exception
    WHERE latest_rank = 1
      AND unresolved_flag = 1
    GROUP BY affected_source_domain_code, affected_source_record_reference
)
SELECT
    UTC_TIMESTAMP(6) AS evaluated_at,
    COALESCE(SUM(has_critical_flag), 0) AS unresolved_critical_source_count,
    COALESCE(SUM(has_warning_flag), 0) AS unresolved_warning_source_count,
    COALESCE(SUM(
        CASE WHEN has_critical_flag = 1 THEN COALESCE(critical_amount_usd, 0.00)
             ELSE 0.00 END
    ), 0.00) AS unresolved_critical_amount_usd,
    COALESCE(SUM(
        CASE WHEN has_warning_flag = 1 THEN COALESCE(warning_amount_usd, 0.00)
             ELSE 0.00 END
    ), 0.00) AS unresolved_warning_amount_usd,
    CASE WHEN COALESCE(SUM(has_critical_flag), 0) > 0 THEN 'BLOCKED' ELSE 'READY' END
        AS release_readiness_code
FROM unresolved_source;
