-- Gym Membership & Revenue Analytics System
-- PDM-019: Payment request, Attempt workflow, and successful allocation procedures
-- Prerequisite: run 00_create_schema.sql through
-- 05_create_membership_check_in_procedures.sql first.

USE gym_membership_analytics;

DELIMITER $$

CREATE PROCEDURE sp_create_payment(
    IN p_payment_number VARCHAR(30),
    IN p_membership_contract_id BIGINT UNSIGNED,
    IN p_requested_at DATETIME(6),
    IN p_requested_amount_usd DECIMAL(12,2),
    IN p_intended_payment_method_code VARCHAR(20),
    OUT p_payment_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_locked_contract_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_not_found BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_payment_id = NULL;
    SET p_intended_payment_method_code = UPPER(TRIM(p_intended_payment_method_code));

    IF p_payment_number IS NULL
       OR CHAR_LENGTH(TRIM(p_payment_number)) = 0
       OR p_membership_contract_id IS NULL
       OR p_requested_at IS NULL
       OR p_requested_amount_usd IS NULL
       OR p_requested_amount_usd <= 0
       OR p_intended_payment_method_code IS NULL
       OR p_intended_payment_method_code NOT IN ('CASH', 'CARD', 'BANK_TRANSFER') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-006: Invalid Payment request';
    END IF;

    START TRANSACTION;

    SET v_not_found = FALSE;
    SELECT membership_contract_id
      INTO v_locked_contract_id
    FROM membership_contract
    WHERE membership_contract_id = p_membership_contract_id
    FOR UPDATE;

    IF v_not_found OR v_locked_contract_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-006: Membership Contract does not exist';
    END IF;

    INSERT INTO payment (
        payment_number,
        membership_contract_id,
        requested_at,
        requested_amount_usd,
        intended_payment_method_code
    )
    VALUES (
        UPPER(TRIM(p_payment_number)),
        p_membership_contract_id,
        p_requested_at,
        p_requested_amount_usd,
        p_intended_payment_method_code
    );

    SET p_payment_id = LAST_INSERT_ID();
    COMMIT;
END$$

CREATE PROCEDURE sp_record_payment_attempt(
    IN p_attempt_number VARCHAR(30),
    IN p_payment_id BIGINT UNSIGNED,
    IN p_attempted_at DATETIME(6),
    IN p_attempted_amount_usd DECIMAL(12,2),
    IN p_payment_method_code VARCHAR(20),
    IN p_processing_branch_id BIGINT UNSIGNED,
    OUT p_payment_attempt_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_locked_payment_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_requested_at DATETIME(6) DEFAULT NULL;
    DECLARE v_requested_amount_usd DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_locked_branch_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_attempt_sequence_number INT UNSIGNED DEFAULT NULL;
    DECLARE v_eligible_attempt_count INT DEFAULT 0;
    DECLARE v_allocation_count INT DEFAULT 0;
    DECLARE v_attempt_issue_count INT DEFAULT 0;
    DECLARE v_not_found BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_payment_attempt_id = NULL;
    SET p_payment_method_code = UPPER(TRIM(p_payment_method_code));

    IF p_attempt_number IS NULL
       OR CHAR_LENGTH(TRIM(p_attempt_number)) = 0
       OR p_payment_id IS NULL
       OR p_attempted_at IS NULL
       OR p_attempted_amount_usd IS NULL
       OR p_attempted_amount_usd <= 0
       OR p_payment_method_code IS NULL
       OR p_payment_method_code NOT IN ('CASH', 'CARD', 'BANK_TRANSFER')
       OR p_processing_branch_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-007: Invalid Payment Attempt definition';
    END IF;

    START TRANSACTION;

    SET v_not_found = FALSE;
    SELECT payment_id, requested_at, requested_amount_usd
      INTO v_locked_payment_id, v_requested_at, v_requested_amount_usd
    FROM payment
    WHERE payment_id = p_payment_id
    FOR UPDATE;

    IF v_not_found OR v_locked_payment_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-007: Payment does not exist';
    END IF;

    IF p_attempted_at < v_requested_at
       OR p_attempted_amount_usd > v_requested_amount_usd THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-007: Attempt time or amount exceeds Payment request';
    END IF;

    SET v_not_found = FALSE;
    SELECT branch_id
      INTO v_locked_branch_id
    FROM branch
    WHERE branch_id = p_processing_branch_id
    FOR UPDATE;

    IF v_not_found OR v_locked_branch_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-007: Processing Branch does not exist';
    END IF;

    SELECT COUNT(*)
      INTO v_allocation_count
    FROM payment_allocation
    WHERE payment_id = p_payment_id;

    IF v_allocation_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-007: Allocated Payment cannot receive another Attempt';
    END IF;

    SELECT COUNT(*)
      INTO v_eligible_attempt_count
    FROM payment_attempt AS attempt
    JOIN payment_attempt_status_event AS latest_status
        ON latest_status.payment_attempt_status_event_id = (
            SELECT status_event.payment_attempt_status_event_id
            FROM payment_attempt_status_event AS status_event
            WHERE status_event.payment_attempt_id = attempt.payment_attempt_id
            ORDER BY status_event.status_at DESC,
                     status_event.payment_attempt_status_event_id DESC
            LIMIT 1
        )
    WHERE attempt.payment_id = p_payment_id
      AND latest_status.attempt_status_code IN ('SUCCESSFUL', 'SETTLED');

    IF v_eligible_attempt_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-009: Another eligible successful Attempt exists';
    END IF;

    SELECT COALESCE(MAX(attempt_sequence_number), 0) + 1
      INTO v_attempt_sequence_number
    FROM payment_attempt
    WHERE payment_id = p_payment_id;

    IF v_attempt_sequence_number > 65535 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-007: Payment Attempt sequence limit exceeded';
    END IF;

    INSERT INTO payment_attempt (
        attempt_number,
        payment_id,
        attempt_sequence_number,
        attempted_at,
        attempted_amount_usd,
        payment_method_code,
        processing_branch_id
    )
    VALUES (
        UPPER(TRIM(p_attempt_number)),
        p_payment_id,
        v_attempt_sequence_number,
        p_attempted_at,
        p_attempted_amount_usd,
        p_payment_method_code,
        p_processing_branch_id
    );

    SET p_payment_attempt_id = LAST_INSERT_ID();

    INSERT INTO payment_attempt_status_event (
        payment_attempt_id,
        attempt_status_code,
        status_at,
        reason_code
    )
    VALUES (
        p_payment_attempt_id,
        'PENDING',
        p_attempted_at,
        NULL
    );

    SELECT COUNT(*)
      INTO v_attempt_issue_count
    FROM vw_dq_payment_attempt_integrity
    WHERE payment_id = p_payment_id;

    IF v_attempt_issue_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-007: Payment Attempt failed integrity validation';
    END IF;

    COMMIT;
END$$

CREATE PROCEDURE sp_transition_payment_attempt(
    IN p_payment_attempt_id BIGINT UNSIGNED,
    IN p_attempt_status_code VARCHAR(20),
    IN p_status_at DATETIME(6),
    IN p_reason_code VARCHAR(50),
    OUT p_payment_attempt_status_event_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_payment_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_locked_payment_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_locked_attempt_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_latest_status_code VARCHAR(20) DEFAULT NULL;
    DECLARE v_latest_status_at DATETIME(6) DEFAULT NULL;
    DECLARE v_other_eligible_count INT DEFAULT 0;
    DECLARE v_attempt_issue_count INT DEFAULT 0;
    DECLARE v_not_found BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_payment_attempt_status_event_id = NULL;
    SET p_attempt_status_code = UPPER(TRIM(p_attempt_status_code));
    SET p_reason_code = NULLIF(UPPER(TRIM(p_reason_code)), '');

    IF p_payment_attempt_id IS NULL
       OR p_status_at IS NULL
       OR p_attempt_status_code IS NULL
       OR p_attempt_status_code NOT IN (
           'SUCCESSFUL', 'SETTLED', 'FAILED', 'CANCELLED', 'REVERSED'
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-008: Invalid Payment Attempt status transition';
    END IF;

    START TRANSACTION;

    SET v_not_found = FALSE;
    SELECT payment_id
      INTO v_payment_id
    FROM payment_attempt
    WHERE payment_attempt_id = p_payment_attempt_id;

    IF v_not_found OR v_payment_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-008: Payment Attempt does not exist';
    END IF;

    SET v_not_found = FALSE;
    SELECT payment_id
      INTO v_locked_payment_id
    FROM payment
    WHERE payment_id = v_payment_id
    FOR UPDATE;

    IF v_not_found OR v_locked_payment_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-008: Parent Payment does not exist';
    END IF;

    SET v_not_found = FALSE;
    SELECT payment_attempt_id
      INTO v_locked_attempt_id
    FROM payment_attempt
    WHERE payment_attempt_id = p_payment_attempt_id
      AND payment_id = v_locked_payment_id
    FOR UPDATE;

    IF v_not_found OR v_locked_attempt_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-008: Payment Attempt changed during transition';
    END IF;

    SET v_not_found = FALSE;
    SELECT attempt_status_code, status_at
      INTO v_latest_status_code, v_latest_status_at
    FROM payment_attempt_status_event
    WHERE payment_attempt_id = p_payment_attempt_id
    ORDER BY status_at DESC, payment_attempt_status_event_id DESC
    LIMIT 1
    FOR UPDATE;

    IF v_not_found OR v_latest_status_code IS NULL
       OR p_status_at <= v_latest_status_at THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-008: Invalid Payment Attempt status timeline';
    END IF;

    IF NOT (
        (v_latest_status_code = 'PENDING'
         AND p_attempt_status_code IN ('SUCCESSFUL', 'FAILED', 'CANCELLED'))
        OR (v_latest_status_code = 'SUCCESSFUL'
            AND p_attempt_status_code IN ('SETTLED', 'REVERSED'))
        OR (v_latest_status_code = 'SETTLED'
            AND p_attempt_status_code = 'REVERSED')
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-008: Invalid Payment Attempt status transition';
    END IF;

    IF p_attempt_status_code = 'SUCCESSFUL' THEN
        SELECT COUNT(*)
          INTO v_other_eligible_count
        FROM payment_attempt AS attempt
        JOIN payment_attempt_status_event AS latest_status
            ON latest_status.payment_attempt_status_event_id = (
                SELECT status_event.payment_attempt_status_event_id
                FROM payment_attempt_status_event AS status_event
                WHERE status_event.payment_attempt_id = attempt.payment_attempt_id
                ORDER BY status_event.status_at DESC,
                         status_event.payment_attempt_status_event_id DESC
                LIMIT 1
            )
        WHERE attempt.payment_id = v_payment_id
          AND attempt.payment_attempt_id <> p_payment_attempt_id
          AND latest_status.attempt_status_code IN ('SUCCESSFUL', 'SETTLED');

        IF v_other_eligible_count > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-FIN-009: Another eligible successful Attempt exists';
        END IF;
    END IF;

    INSERT INTO payment_attempt_status_event (
        payment_attempt_id,
        attempt_status_code,
        status_at,
        reason_code
    )
    VALUES (
        p_payment_attempt_id,
        p_attempt_status_code,
        p_status_at,
        p_reason_code
    );

    SET p_payment_attempt_status_event_id = LAST_INSERT_ID();

    SELECT COUNT(*)
      INTO v_attempt_issue_count
    FROM vw_dq_payment_attempt_integrity
    WHERE payment_id = v_payment_id;

    IF v_attempt_issue_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-008: Attempt transition failed integrity validation';
    END IF;

    COMMIT;
END$$

CREATE PROCEDURE sp_allocate_successful_payment(
    IN p_payment_id BIGINT UNSIGNED,
    IN p_recorded_at DATETIME(6),
    IN p_allocation_json JSON,
    OUT p_inserted_allocation_count INT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_not_found BOOLEAN DEFAULT FALSE;
    DECLARE v_payment_obligation_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_locked_obligation_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_schedule_amount_usd DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_original_amount_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_adjustment_total_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_allocation_total_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_reopened_total_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_remaining_amount_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_membership_contract_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_schedule_count INT DEFAULT 0;
    DECLARE v_distinct_obligation_count INT DEFAULT 0;
    DECLARE v_invalid_schedule_count INT DEFAULT 0;
    DECLARE v_matching_obligation_count INT DEFAULT 0;
    DECLARE v_existing_allocation_count INT DEFAULT 0;
    DECLARE v_eligible_attempt_count INT DEFAULT 0;
    DECLARE v_eligible_payment_attempt_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_locked_payment_attempt_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_eligible_amount_usd DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_collected_at DATETIME(6) DEFAULT NULL;
    DECLARE v_schedule_total_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_payment_issue_count INT DEFAULT 0;

    DECLARE allocation_cursor CURSOR FOR
        SELECT
            schedule.payment_obligation_id,
            schedule.allocated_amount_usd
        FROM JSON_TABLE(
            p_allocation_json,
            '$[*]' COLUMNS (
                payment_obligation_id BIGINT UNSIGNED
                    PATH '$.payment_obligation_id' NULL ON EMPTY NULL ON ERROR,
                allocated_amount_usd DECIMAL(12,2)
                    PATH '$.allocated_amount_usd' NULL ON EMPTY NULL ON ERROR
            )
        ) AS schedule
        ORDER BY schedule.payment_obligation_id;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        BEGIN
            SET v_done = TRUE;
            SET v_not_found = TRUE;
        END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_inserted_allocation_count = 0;

    IF p_payment_id IS NULL
       OR p_recorded_at IS NULL
       OR p_allocation_json IS NULL
       OR JSON_TYPE(p_allocation_json) <> 'ARRAY'
       OR JSON_LENGTH(p_allocation_json) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-010: Allocation set is required';
    END IF;

    SELECT
        COUNT(*),
        COUNT(DISTINCT schedule.payment_obligation_id),
        COALESCE(SUM(schedule.allocated_amount_usd), 0.00),
        SUM(
            schedule.payment_obligation_id IS NULL
            OR schedule.allocated_amount_usd IS NULL
            OR schedule.allocated_amount_usd <= 0
        )
      INTO
        v_schedule_count,
        v_distinct_obligation_count,
        v_schedule_total_usd,
        v_invalid_schedule_count
    FROM JSON_TABLE(
        p_allocation_json,
        '$[*]' COLUMNS (
            payment_obligation_id BIGINT UNSIGNED
                PATH '$.payment_obligation_id' NULL ON EMPTY NULL ON ERROR,
            allocated_amount_usd DECIMAL(12,2)
                PATH '$.allocated_amount_usd' NULL ON EMPTY NULL ON ERROR
        )
    ) AS schedule;

    IF v_schedule_count <> JSON_LENGTH(p_allocation_json)
       OR v_distinct_obligation_count <> v_schedule_count
       OR v_invalid_schedule_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-010: Invalid or duplicate Allocation entry';
    END IF;

    START TRANSACTION;

    SET v_not_found = FALSE;
    SELECT membership_contract_id
      INTO v_membership_contract_id
    FROM payment
    WHERE payment_id = p_payment_id
    FOR UPDATE;

    IF v_not_found OR v_membership_contract_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-010: Payment does not exist';
    END IF;

    SELECT COUNT(*)
      INTO v_existing_allocation_count
    FROM payment_allocation
    WHERE payment_id = p_payment_id;

    IF v_existing_allocation_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-010: Payment already has Allocations';
    END IF;

    SELECT
        COUNT(*),
        MAX(ranked.payment_attempt_id),
        MAX(ranked.attempted_amount_usd),
        MAX(ranked.collected_at)
      INTO
        v_eligible_attempt_count,
        v_eligible_payment_attempt_id,
        v_eligible_amount_usd,
        v_collected_at
    FROM (
        SELECT
            attempt.payment_attempt_id,
            attempt.attempted_amount_usd,
            status_event.attempt_status_code,
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
        WHERE attempt.payment_id = p_payment_id
    ) AS ranked
    WHERE ranked.latest_rank = 1
      AND ranked.attempt_status_code IN ('SUCCESSFUL', 'SETTLED');

    IF v_eligible_attempt_count <> 1
       OR v_eligible_payment_attempt_id IS NULL
       OR v_eligible_amount_usd IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-010: Payment requires one eligible funding Attempt';
    END IF;

    SET v_not_found = FALSE;
    SELECT payment_attempt_id
      INTO v_locked_payment_attempt_id
    FROM payment_attempt
    WHERE payment_attempt_id = v_eligible_payment_attempt_id
      AND payment_id = p_payment_id
    FOR UPDATE;

    IF v_not_found OR v_locked_payment_attempt_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-010: Funding Attempt changed during allocation';
    END IF;

    IF p_recorded_at < v_collected_at
       OR v_schedule_total_usd <> v_eligible_amount_usd THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-011: Allocation total or time does not match funding';
    END IF;

    SELECT COUNT(*)
      INTO v_matching_obligation_count
    FROM JSON_TABLE(
        p_allocation_json,
        '$[*]' COLUMNS (
            payment_obligation_id BIGINT UNSIGNED
                PATH '$.payment_obligation_id' NULL ON EMPTY NULL ON ERROR
        )
    ) AS schedule
    JOIN payment_obligation AS obligation
        ON obligation.payment_obligation_id = schedule.payment_obligation_id
       AND obligation.membership_contract_id = v_membership_contract_id;

    IF v_matching_obligation_count <> v_schedule_count THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-010: Allocation Contract or funding mismatch';
    END IF;

    SET v_done = FALSE;
    SET v_not_found = FALSE;
    OPEN allocation_cursor;

    allocation_loop: LOOP
        FETCH allocation_cursor
         INTO v_payment_obligation_id, v_schedule_amount_usd;

        IF v_done THEN
            LEAVE allocation_loop;
        END IF;

        SET v_locked_obligation_id = NULL;
        SET v_not_found = FALSE;
        SELECT payment_obligation_id, original_obligation_amount_usd
          INTO v_locked_obligation_id, v_original_amount_usd
        FROM payment_obligation
        WHERE payment_obligation_id = v_payment_obligation_id
          AND membership_contract_id = v_membership_contract_id
        FOR UPDATE;

        IF v_not_found OR v_locked_obligation_id IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-FIN-010: Allocation Obligation changed during locking';
        END IF;

        SELECT COALESCE(SUM(adjustment_amount_usd), 0.00)
          INTO v_adjustment_total_usd
        FROM payment_obligation_adjustment
        WHERE payment_obligation_id = v_payment_obligation_id;

        SELECT COALESCE(SUM(allocated_amount_usd), 0.00)
          INTO v_allocation_total_usd
        FROM payment_allocation
        WHERE payment_obligation_id = v_payment_obligation_id;

        SELECT COALESCE(SUM(refund_allocation.refund_allocated_amount_usd), 0.00)
          INTO v_reopened_total_usd
        FROM refund_allocation
        JOIN payment_allocation AS original_allocation
            ON original_allocation.payment_allocation_id
                = refund_allocation.payment_allocation_id
        JOIN refund_status_event AS latest_refund_status
            ON latest_refund_status.refund_status_event_id = (
                SELECT status_event.refund_status_event_id
                FROM refund_status_event AS status_event
                WHERE status_event.refund_id = refund_allocation.refund_id
                ORDER BY status_event.status_at DESC,
                         status_event.refund_status_event_id DESC
                LIMIT 1
            )
        WHERE original_allocation.payment_obligation_id = v_payment_obligation_id
          AND refund_allocation.reopens_obligation_flag = 1
          AND latest_refund_status.refund_status_code = 'COMPLETED';

        SET v_remaining_amount_usd = GREATEST(
            v_original_amount_usd
            - v_adjustment_total_usd
            - v_allocation_total_usd
            + v_reopened_total_usd,
            0.00
        );

        IF v_schedule_amount_usd > v_remaining_amount_usd THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-FIN-011: Allocation exceeds Obligation balance';
        END IF;
    END LOOP;

    CLOSE allocation_cursor;

    INSERT INTO payment_allocation (
        payment_id,
        payment_obligation_id,
        allocated_amount_usd,
        recorded_at
    )
    SELECT
        p_payment_id,
        schedule.payment_obligation_id,
        schedule.allocated_amount_usd,
        p_recorded_at
    FROM JSON_TABLE(
        p_allocation_json,
        '$[*]' COLUMNS (
            payment_obligation_id BIGINT UNSIGNED
                PATH '$.payment_obligation_id' ERROR ON EMPTY ERROR ON ERROR,
            allocated_amount_usd DECIMAL(12,2)
                PATH '$.allocated_amount_usd' ERROR ON EMPTY ERROR ON ERROR
        )
    ) AS schedule
    ORDER BY schedule.payment_obligation_id;

    SET p_inserted_allocation_count = ROW_COUNT();

    SELECT COUNT(*)
      INTO v_payment_issue_count
    FROM vw_dq_payment_reconciliation
    WHERE payment_id = p_payment_id;

    IF v_payment_issue_count > 0
       OR p_inserted_allocation_count <> v_schedule_count THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-011: Payment Allocation failed reconciliation';
    END IF;

    COMMIT;
END$$

DELIMITER ;
