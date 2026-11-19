-- Gym Membership & Revenue Analytics System
-- PDM-015 structural validation for the schema foundation

USE gym_membership_analytics;

SELECT
    control_name,
    expected_count,
    actual_count,
    CASE WHEN actual_count = expected_count THEN 'PASS' ELSE 'FAIL' END AS result
FROM (
    SELECT
        'BASE_TABLES' AS control_name,
        21 AS expected_count,
        COUNT(*) AS actual_count
    FROM information_schema.tables
    WHERE table_schema = 'gym_membership_analytics'
      AND table_type = 'BASE TABLE'

    UNION ALL

    SELECT
        'COLUMNS',
        131,
        COUNT(*)
    FROM information_schema.columns AS columns_metadata
    INNER JOIN information_schema.tables AS tables_metadata
        ON tables_metadata.table_schema = columns_metadata.table_schema
       AND tables_metadata.table_name = columns_metadata.table_name
       AND tables_metadata.table_type = 'BASE TABLE'
    WHERE columns_metadata.table_schema = 'gym_membership_analytics'

    UNION ALL

    SELECT
        'PRIMARY_KEYS',
        21,
        COUNT(*)
    FROM information_schema.table_constraints
    WHERE constraint_schema = 'gym_membership_analytics'
      AND constraint_type = 'PRIMARY KEY'

    UNION ALL

    SELECT
        'UNIQUE_CONSTRAINTS',
        24,
        COUNT(*)
    FROM information_schema.table_constraints
    WHERE constraint_schema = 'gym_membership_analytics'
      AND constraint_type = 'UNIQUE'

    UNION ALL

    SELECT
        'FOREIGN_KEYS',
        27,
        COUNT(*)
    FROM information_schema.table_constraints
    WHERE constraint_schema = 'gym_membership_analytics'
      AND constraint_type = 'FOREIGN KEY'

    UNION ALL

    SELECT
        'CHECK_CONSTRAINTS',
        74,
        COUNT(*)
    FROM information_schema.table_constraints
    WHERE constraint_schema = 'gym_membership_analytics'
      AND constraint_type = 'CHECK'

    UNION ALL

    SELECT
        'APPROVED_NONUNIQUE_INDEXES',
        14,
        COUNT(DISTINCT index_name)
    FROM information_schema.statistics
    WHERE table_schema = 'gym_membership_analytics'
      AND index_name IN (
          'ix_member_branch_assignment_home_branch',
          'ix_membership_contract_plan_version',
          'ix_membership_contract_financial_ownership_branch',
          'ix_membership_status_event_contract',
          'ix_check_in_member',
          'ix_check_in_visited_branch',
          'ix_payment_obligation_adjustment_status_event',
          'ix_payment_contract',
          'ix_payment_allocation_obligation',
          'ix_payment_attempt_processing_branch',
          'ix_refund_payment',
          'ix_refund_allocation_payment_allocation',
          'ix_check_in_source_reference',
          'ix_financial_exception_source_type_detected'
      )
) AS structural_controls
ORDER BY control_name;

-- This result set must be empty: every table must have its approved one-column primary key.
WITH expected_primary_key AS (
    SELECT 'branch' AS table_name, 'branch_id' AS column_name
    UNION ALL SELECT 'membership_plan', 'plan_id'
    UNION ALL SELECT 'membership_plan_version', 'plan_version_id'
    UNION ALL SELECT 'member', 'member_id'
    UNION ALL SELECT 'member_branch_assignment', 'member_branch_assignment_id'
    UNION ALL SELECT 'membership_contract', 'membership_contract_id'
    UNION ALL SELECT 'membership_status_event', 'membership_status_event_id'
    UNION ALL SELECT 'membership_status_decision_event', 'membership_status_decision_event_id'
    UNION ALL SELECT 'check_in', 'check_in_id'
    UNION ALL SELECT 'check_in_quality_issue', 'check_in_quality_issue_id'
    UNION ALL SELECT 'payment_obligation', 'payment_obligation_id'
    UNION ALL SELECT 'payment_obligation_adjustment', 'payment_obligation_adjustment_id'
    UNION ALL SELECT 'payment', 'payment_id'
    UNION ALL SELECT 'payment_allocation', 'payment_allocation_id'
    UNION ALL SELECT 'payment_attempt', 'payment_attempt_id'
    UNION ALL SELECT 'payment_attempt_status_event', 'payment_attempt_status_event_id'
    UNION ALL SELECT 'refund', 'refund_id'
    UNION ALL SELECT 'refund_status_event', 'refund_status_event_id'
    UNION ALL SELECT 'refund_allocation', 'refund_allocation_id'
    UNION ALL SELECT 'financial_exception', 'financial_exception_id'
    UNION ALL SELECT 'financial_exception_status_event', 'financial_exception_status_event_id'
), actual_primary_key AS (
    SELECT
        table_name,
        MIN(column_name) AS column_name,
        COUNT(*) AS primary_key_column_count
    FROM information_schema.key_column_usage
    WHERE constraint_schema = 'gym_membership_analytics'
      AND constraint_name = 'PRIMARY'
    GROUP BY table_name
)
SELECT
    expected.table_name,
    expected.column_name AS expected_primary_key_column,
    actual.column_name AS actual_primary_key_column,
    COALESCE(actual.primary_key_column_count, 0) AS actual_primary_key_column_count
FROM expected_primary_key AS expected
LEFT JOIN actual_primary_key AS actual
    ON actual.table_name = expected.table_name
WHERE actual.table_name IS NULL
   OR actual.column_name <> expected.column_name
   OR actual.primary_key_column_count <> 1
ORDER BY expected.table_name;

-- This result set must be empty: every table must use InnoDB and the approved collation.
SELECT table_name, engine, table_collation
FROM information_schema.tables
WHERE table_schema = 'gym_membership_analytics'
  AND table_type = 'BASE TABLE'
  AND (
      engine <> 'InnoDB'
      OR table_collation <> 'utf8mb4_0900_ai_ci'
  )
ORDER BY table_name;

-- This result set must be empty: no foreign key may cascade or nullify history.
SELECT constraint_name, update_rule, delete_rule
FROM information_schema.referential_constraints
WHERE constraint_schema = 'gym_membership_analytics'
  AND (
      update_rule <> 'RESTRICT'
      OR delete_rule <> 'RESTRICT'
  )
ORDER BY constraint_name;
