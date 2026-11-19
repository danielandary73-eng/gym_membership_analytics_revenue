-- Gym Membership & Revenue Analytics System
-- PDM-023 Functional Test Batch 5: negative paths and protection controls
-- Prerequisite: successfully run scripts 10 through 14 in order.
-- Safety: this script writes only to gym_membership_analytics_test.

USE gym_membership_analytics_test;

SET SESSION time_zone = '+00:00';

DROP TEMPORARY TABLE IF EXISTS tmp_ft05_result;
CREATE TEMPORARY TABLE tmp_ft05_result (
    test_sequence SMALLINT UNSIGNED NOT NULL,
    validation_control VARCHAR(100) NOT NULL,
    expected_result VARCHAR(20) NOT NULL,
    actual_result VARCHAR(20) NOT NULL,
    validation_result VARCHAR(10) NOT NULL,
    PRIMARY KEY (test_sequence)
);

DROP PROCEDURE IF EXISTS sp_ft05_run_protection_tests;

DELIMITER $$

CREATE PROCEDURE sp_ft05_run_protection_tests()
BEGIN
    DECLARE v_contract_id BIGINT UNSIGNED;
    DECLARE v_member_id BIGINT UNSIGNED;
    DECLARE v_branch_id BIGINT UNSIGNED;
    DECLARE v_payment_id BIGINT UNSIGNED;
    DECLARE v_successful_attempt_id BIGINT UNSIGNED;
    DECLARE v_second_obligation_id BIGINT UNSIGNED;
    DECLARE v_second_payment_id BIGINT UNSIGNED;
    DECLARE v_second_attempt_id BIGINT UNSIGNED;
    DECLARE v_status_event_id BIGINT UNSIGNED;
    DECLARE v_allocation_count INT UNSIGNED;
    DECLARE v_check_in_id BIGINT UNSIGNED;
    DECLARE v_dummy_id BIGINT UNSIGNED;
    DECLARE v_rejected BOOLEAN DEFAULT FALSE;
    DECLARE v_bad_allocation_json JSON;
    DECLARE v_good_allocation_json JSON;

    SELECT membership_contract_id, member_id, financial_ownership_branch_id
      INTO v_contract_id, v_member_id, v_branch_id
    FROM membership_contract
    WHERE contract_number = 'FT01CON001';

    SELECT payment_id
      INTO v_payment_id
    FROM payment
    WHERE payment_number = 'FT02PAY001';

    SELECT attempt.payment_attempt_id
      INTO v_successful_attempt_id
    FROM payment_attempt AS attempt
    WHERE attempt.payment_id = v_payment_id
      AND attempt.attempt_number = 'FT02ATT002';

    SELECT payment_obligation_id
      INTO v_second_obligation_id
    FROM payment_obligation
    WHERE membership_contract_id = v_contract_id
      AND obligation_sequence_number = 2;

    -- 1. Immutable Contract update must be rejected by its history trigger.
    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected = TRUE;
        UPDATE membership_contract
        SET contract_number = 'FT05ILLEGALUPDATE'
        WHERE membership_contract_id = v_contract_id;
    END;
    INSERT INTO tmp_ft05_result VALUES (
        1, 'FT05_PROTECTED_CONTRACT_UPDATE', 'REJECTED',
        IF(v_rejected, 'REJECTED', 'ALLOWED'),
        IF(v_rejected, 'PASS', 'FAIL')
    );

    -- 2. Historical Payment deletion must be rejected.
    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected = TRUE;
        DELETE FROM payment WHERE payment_id = v_payment_id;
    END;
    INSERT INTO tmp_ft05_result VALUES (
        2, 'FT05_PROTECTED_PAYMENT_DELETE', 'REJECTED',
        IF(v_rejected, 'REJECTED', 'ALLOWED'),
        IF(v_rejected, 'PASS', 'FAIL')
    );

    -- 3. SUCCESSFUL cannot transition backward to FAILED.
    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected = TRUE;
        CALL sp_transition_payment_attempt(
            v_successful_attempt_id,
            'FAILED',
            '2026-01-12 08:00:00.000000',
            'INVALID_TEST_TRANSITION',
            v_status_event_id
        );
    END;
    INSERT INTO tmp_ft05_result VALUES (
        3, 'FT05_INVALID_PAYMENT_STATUS_TRANSITION', 'REJECTED',
        IF(v_rejected, 'REJECTED', 'ALLOWED'),
        IF(v_rejected, 'PASS', 'FAIL')
    );

    -- 4. A refund cannot exceed the successfully collected amount.
    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected = TRUE;
        CALL sp_request_refund(
            'FT05BADREFUND',
            v_payment_id,
            '2026-01-12 09:00:00.000000',
            100.00,
            'EXCESSIVE_TEST',
            v_dummy_id
        );
    END;
    INSERT INTO tmp_ft05_result VALUES (
        4, 'FT05_EXCESSIVE_REFUND', 'REJECTED',
        IF(v_rejected, 'REJECTED', 'ALLOWED'),
        IF(v_rejected, 'PASS', 'FAIL')
    );

    -- 5. An assignment beginning on the existing start date overlaps it.
    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected = TRUE;
        CALL sp_assign_member_home_branch(
            v_member_id,
            v_branch_id,
            '2025-12-01',
            NULL,
            v_dummy_id
        );
    END;
    INSERT INTO tmp_ft05_result VALUES (
        5, 'FT05_OVERLAPPING_HOME_BRANCH_ASSIGNMENT', 'REJECTED',
        IF(v_rejected, 'REJECTED', 'ALLOWED'),
        IF(v_rejected, 'PASS', 'FAIL')
    );

    -- Create a second valid Payment to test duplicate success and allocation limits.
    CALL sp_create_payment(
        'FT05PAY002',
        v_contract_id,
        '2026-02-01 08:00:00.000000',
        60.00,
        'BANK_TRANSFER',
        v_second_payment_id
    );

    CALL sp_record_payment_attempt(
        'FT05ATT001',
        v_second_payment_id,
        '2026-02-01 08:01:00.000000',
        60.00,
        'BANK_TRANSFER',
        v_branch_id,
        v_second_attempt_id
    );

    CALL sp_transition_payment_attempt(
        v_second_attempt_id,
        'SUCCESSFUL',
        '2026-02-01 08:02:00.000000',
        NULL,
        v_status_event_id
    );

    -- 6. Another Attempt cannot be added after an eligible success exists.
    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected = TRUE;
        CALL sp_record_payment_attempt(
            'FT05ATT002',
            v_second_payment_id,
            '2026-02-01 08:03:00.000000',
            60.00,
            'CARD',
            v_branch_id,
            v_dummy_id
        );
    END;
    INSERT INTO tmp_ft05_result VALUES (
        6, 'FT05_DUPLICATE_SUCCESSFUL_FUNDING_PATH', 'REJECTED',
        IF(v_rejected, 'REJECTED', 'ALLOWED'),
        IF(v_rejected, 'PASS', 'FAIL')
    );

    -- 7. Allocation total cannot exceed or disagree with collected funding.
    SET v_bad_allocation_json = JSON_ARRAY(
        JSON_OBJECT(
            'payment_obligation_id', v_second_obligation_id,
            'allocated_amount_usd', 80.00
        )
    );
    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected = TRUE;
        CALL sp_allocate_successful_payment(
            v_second_payment_id,
            '2026-02-01 08:04:00.000000',
            v_bad_allocation_json,
            v_allocation_count
        );
    END;
    INSERT INTO tmp_ft05_result VALUES (
        7, 'FT05_EXCESSIVE_PAYMENT_ALLOCATION', 'REJECTED',
        IF(v_rejected, 'REJECTED', 'ALLOWED'),
        IF(v_rejected, 'PASS', 'FAIL')
    );

    -- Finish the second Payment correctly so no test-created DQ issue remains.
    SET v_good_allocation_json = JSON_ARRAY(
        JSON_OBJECT(
            'payment_obligation_id', v_second_obligation_id,
            'allocated_amount_usd', 60.00
        )
    );
    CALL sp_allocate_successful_payment(
        v_second_payment_id,
        '2026-02-01 08:05:00.000000',
        v_good_allocation_json,
        v_allocation_count
    );
    INSERT INTO tmp_ft05_result VALUES (
        8, 'FT05_VALID_RECOVERY_ALLOCATION', '1',
        CAST(v_allocation_count AS CHAR),
        IF(v_allocation_count = 1, 'PASS', 'FAIL')
    );

    -- 9. Duplicate Check-In source data is preserved but quality-flagged.
    CALL sp_ingest_check_in(
        'FT01-CHECKIN-001',
        'FT01MEM001',
        'FT01BR',
        '2026-01-16 15:00:00.000000',
        '2026-01-16 15:00:05.000000',
        v_check_in_id
    );

    INSERT INTO tmp_ft05_result
    SELECT
        9,
        'FT05_DUPLICATE_CHECK_IN_FLAGGED',
        '1',
        CAST(COUNT(*) AS CHAR),
        IF(COUNT(*) = 1, 'PASS', 'FAIL')
    FROM check_in_quality_issue
    WHERE check_in_id = v_check_in_id
      AND issue_code = 'DUPLICATE_SOURCE_REFERENCE'
      AND resolved_at IS NULL;

    INSERT INTO tmp_ft05_result
    SELECT
        10,
        'FT05_DUPLICATE_EXCLUDED_FROM_REPORTING',
        '1',
        CAST(COUNT(*) AS CHAR),
        IF(COUNT(*) = 1, 'PASS', 'FAIL')
    FROM vw_reporting_check_in
    WHERE source_check_in_reference = 'FT01-CHECKIN-001';

    INSERT INTO tmp_ft05_result
    SELECT
        11,
        'FT05_ALL_TEST_PAYMENTS_RECONCILED',
        '0',
        CAST(COUNT(*) AS CHAR),
        IF(COUNT(*) = 0, 'PASS', 'FAIL')
    FROM vw_dq_payment_reconciliation
    WHERE payment_id IN (v_payment_id, v_second_payment_id);
END$$

DELIMITER ;

CALL sp_ft05_run_protection_tests();

SELECT
    test_sequence,
    validation_control,
    expected_result,
    actual_result,
    validation_result
FROM tmp_ft05_result
ORDER BY test_sequence;

-- Supporting evidence: two valid Payments now reconcile to USD 120 gross,
-- less the earlier USD 20 Refund, leaving USD 100 Net Collected Revenue.
SELECT
    SUM(gross_collected_amount_usd) AS gross_collected_revenue_usd
FROM vw_reporting_gross_collected_revenue
WHERE contract_number = 'FT01CON001';

SELECT
    SUM(net_collected_revenue_usd) AS net_collected_revenue_usd
FROM vw_reporting_net_collected_revenue
WHERE contract_number = 'FT01CON001';

SELECT
    obligation_number,
    original_obligation_amount_usd,
    gross_applied_amount_usd,
    reopened_amount_usd,
    outstanding_balance_usd
FROM vw_reporting_obligation_balance
WHERE contract_number = 'FT01CON001'
ORDER BY obligation_sequence_number;

DROP PROCEDURE sp_ft05_run_protection_tests;
DROP TEMPORARY TABLE tmp_ft05_result;

