-- Gym Membership & Revenue Analytics System
-- PDM-023 Functional Test Batch 4: Financial Exception workflow and release gate
-- Prerequisite: successfully run scripts 10 through 13 in order.
-- Safety: this script writes only to gym_membership_analytics_test.

USE gym_membership_analytics_test;

SET SESSION time_zone = '+00:00';

SELECT payment_id
  INTO @ft_payment_id
FROM payment
WHERE payment_number = 'FT02PAY001';

-- Open a controlled Critical exception against the Payment reporting source.
CALL sp_open_financial_exception(
    'FT04FEX001',
    'PAYMENT',
    'FT02PAY001',
    'RECONCILIATION_DIFFERENCE',
    'CRITICAL',
    60.00,
    '2026-01-11 11:00:00.000000',
    'FINANCE_CONTROL',
    @ft_financial_exception_id
);

-- Capture the blocked state before moving the workflow forward.
SELECT COUNT(*)
  INTO @ft_gross_rows_while_open
FROM vw_reporting_gross_collected_revenue
WHERE payment_id = @ft_payment_id;

SELECT
    unresolved_critical_source_count,
    unresolved_critical_amount_usd
  INTO
    @ft_open_critical_count,
    @ft_open_critical_amount
FROM vw_dq_financial_release_readiness;

CALL sp_update_financial_exception_workflow(
    @ft_financial_exception_id,
    'UNDER_REVIEW',
    '2026-01-11 12:00:00.000000',
    'FINANCE_CONTROL',
    'EXCLUDED',
    'Payment and allocation were independently reconciled to the successful attempt.',
    @ft_under_review_status_id
);

CALL sp_resolve_financial_exception(
    @ft_financial_exception_id,
    '2026-01-11 13:00:00.000000',
    'FINANCE_CONTROL',
    'ELIGIBLE',
    'Verified one eligible successful attempt, one USD 60 allocation, and no source integrity issue.',
    @ft_resolved_status_id
);

-- The release gate must complete without raising GYM-DQ-010 after resolution.
CALL sp_assert_financial_release_ready(
    @ft_unresolved_critical_count,
    @ft_unresolved_warning_count,
    @ft_unresolved_critical_amount,
    @ft_unresolved_warning_amount
);

-- Every row below must return PASS.
SELECT
    'FT04_EXCEPTION_CREATED' AS validation_control,
    1 AS expected_result,
    COUNT(*) AS actual_result,
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS validation_result
FROM financial_exception
WHERE financial_exception_id = @ft_financial_exception_id
  AND severity_code = 'CRITICAL'
  AND affected_source_domain_code = 'PAYMENT'

UNION ALL

SELECT
    'FT04_OPEN_EXCEPTION_BLOCKED_REPORTING', 0, @ft_gross_rows_while_open,
    CASE WHEN @ft_gross_rows_while_open = 0 THEN 'PASS' ELSE 'FAIL' END

UNION ALL

SELECT
    'FT04_OPEN_CRITICAL_SOURCE_COUNT', 1, @ft_open_critical_count,
    CASE WHEN @ft_open_critical_count = 1 THEN 'PASS' ELSE 'FAIL' END

UNION ALL

SELECT
    'FT04_OPEN_CRITICAL_AMOUNT', 60.00, @ft_open_critical_amount,
    CASE WHEN @ft_open_critical_amount = 60.00 THEN 'PASS' ELSE 'FAIL' END

UNION ALL

SELECT
    'FT04_THREE_STATUS_EVENTS', 3, COUNT(*),
    CASE WHEN COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END
FROM financial_exception_status_event
WHERE financial_exception_id = @ft_financial_exception_id

UNION ALL

SELECT
    'FT04_LATEST_STATUS_RESOLVED', 1, COUNT(*),
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM financial_exception_status_event AS status_event
WHERE status_event.financial_exception_status_event_id = (
    SELECT latest_status.financial_exception_status_event_id
    FROM financial_exception_status_event AS latest_status
    WHERE latest_status.financial_exception_id = @ft_financial_exception_id
    ORDER BY latest_status.status_at DESC,
             latest_status.financial_exception_status_event_id DESC
    LIMIT 1
)
  AND status_event.exception_status_code = 'RESOLVED'
  AND status_event.reporting_disposition_code = 'ELIGIBLE'
  AND status_event.resolution_note IS NOT NULL

UNION ALL

SELECT
    'FT04_EXCEPTION_INTEGRITY_ISSUES', 0, COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM vw_dq_financial_exception_integrity
WHERE financial_exception_id = @ft_financial_exception_id

UNION ALL

SELECT
    'FT04_REPORTING_RESTORED', 60.00,
    COALESCE(SUM(gross_collected_amount_usd), 0.00),
    CASE WHEN COALESCE(SUM(gross_collected_amount_usd), 0.00) = 60.00
         THEN 'PASS' ELSE 'FAIL' END
FROM vw_reporting_gross_collected_revenue
WHERE payment_id = @ft_payment_id

UNION ALL

SELECT
    'FT04_NET_REVENUE_RESTORED', 40.00,
    COALESCE(SUM(net_collected_revenue_usd), 0.00),
    CASE WHEN COALESCE(SUM(net_collected_revenue_usd), 0.00) = 40.00
         THEN 'PASS' ELSE 'FAIL' END
FROM vw_reporting_net_collected_revenue
WHERE payment_id = @ft_payment_id

UNION ALL

SELECT
    'FT04_RELEASE_CRITICAL_COUNT', 0, @ft_unresolved_critical_count,
    CASE WHEN @ft_unresolved_critical_count = 0 THEN 'PASS' ELSE 'FAIL' END

UNION ALL

SELECT
    'FT04_RELEASE_WARNING_COUNT', 0, @ft_unresolved_warning_count,
    CASE WHEN @ft_unresolved_warning_count = 0 THEN 'PASS' ELSE 'FAIL' END;

-- Detail evidence for manual review.
SELECT
    exception_record.exception_number,
    exception_record.affected_source_domain_code,
    exception_record.affected_source_record_reference,
    exception_record.severity_code,
    status_event.exception_status_code,
    status_event.reporting_disposition_code,
    status_event.status_at,
    status_event.review_note,
    status_event.resolution_note
FROM financial_exception AS exception_record
JOIN financial_exception_status_event AS status_event
    ON status_event.financial_exception_id = exception_record.financial_exception_id
WHERE exception_record.financial_exception_id = @ft_financial_exception_id
ORDER BY status_event.status_at;

SELECT *
FROM vw_dq_financial_release_readiness;

