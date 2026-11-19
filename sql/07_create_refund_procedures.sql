-- Gym Membership & Revenue Analytics System
-- PDM-020: Refund request, terminal transition, and atomic completion procedures
-- Prerequisite: run 00_create_schema.sql through 06_create_payment_procedures.sql first.

USE gym_membership_analytics;

DELIMITER $$

CREATE PROCEDURE sp_request_refund(
    IN p_refund_number VARCHAR(30),
    IN p_payment_id BIGINT UNSIGNED,
    IN p_requested_at DATETIME(6),
    IN p_refund_amount_usd DECIMAL(12,2),
    IN p_refund_reason_code VARCHAR(50),
    OUT p_refund_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_locked_payment_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_payment_requested_at DATETIME(6) DEFAULT NULL;
    DECLARE v_eligible_attempt_count INT DEFAULT 0;
    DECLARE v_eligible_amount_usd DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_collected_at DATETIME(6) DEFAULT NULL;
    DECLARE v_allocation_count INT DEFAULT 0;
    DECLARE v_allocation_total_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_payment_issue_count INT DEFAULT 0;
    DECLARE v_refund_issue_count INT DEFAULT 0;
    DECLARE v_not_found BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_refund_id = NULL;
    SET p_refund_reason_code = UPPER(TRIM(p_refund_reason_code));

    IF p_refund_number IS NULL
       OR CHAR_LENGTH(TRIM(p_refund_number)) = 0
       OR p_payment_id IS NULL
       OR p_requested_at IS NULL
       OR p_refund_amount_usd IS NULL
       OR p_refund_amount_usd <= 0
       OR p_refund_reason_code IS NULL
       OR CHAR_LENGTH(p_refund_reason_code) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-001: Invalid Refund request or original Payment';
    END IF;

    START TRANSACTION;

    SET v_not_found = FALSE;
    SELECT payment_id, requested_at
      INTO v_locked_payment_id, v_payment_requested_at
    FROM payment
    WHERE payment_id = p_payment_id
    FOR UPDATE;

    IF v_not_found OR v_locked_payment_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-001: Original Payment does not exist';
    END IF;

    SELECT
        COUNT(*),
        MAX(ranked.attempted_amount_usd),
        MAX(ranked.collected_at)
      INTO
        v_eligible_attempt_count,
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

    SELECT COUNT(*), COALESCE(SUM(allocated_amount_usd), 0.00)
      INTO v_allocation_count, v_allocation_total_usd
    FROM payment_allocation
    WHERE payment_id = p_payment_id;

    SELECT COUNT(*)
      INTO v_payment_issue_count
    FROM vw_dq_payment_reconciliation
    WHERE payment_id = p_payment_id;

    IF v_eligible_attempt_count <> 1
       OR v_eligible_amount_usd IS NULL
       OR v_allocation_count = 0
       OR v_allocation_total_usd <> v_eligible_amount_usd
       OR v_payment_issue_count > 0
       OR p_requested_at < v_payment_requested_at
       OR p_requested_at < v_collected_at
       OR p_refund_amount_usd > v_eligible_amount_usd THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-001: Invalid Refund request or original Payment';
    END IF;

    INSERT INTO refund (
        refund_number,
        payment_id,
        requested_at,
        refund_amount_usd,
        refund_reason_code
    )
    VALUES (
        UPPER(TRIM(p_refund_number)),
        p_payment_id,
        p_requested_at,
        p_refund_amount_usd,
        p_refund_reason_code
    );

    SET p_refund_id = LAST_INSERT_ID();

    INSERT INTO refund_status_event (
        refund_id,
        refund_status_code,
        status_at,
        status_reason_code
    )
    VALUES (
        p_refund_id,
        'PENDING',
        p_requested_at,
        NULL
    );

    SELECT COUNT(*)
      INTO v_refund_issue_count
    FROM vw_dq_refund_status_integrity
    WHERE refund_id = p_refund_id;

    IF v_refund_issue_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-002: Invalid initial Refund status';
    END IF;

    COMMIT;
END$$

CREATE PROCEDURE sp_transition_refund(
    IN p_refund_id BIGINT UNSIGNED,
    IN p_refund_status_code VARCHAR(20),
    IN p_status_at DATETIME(6),
    IN p_status_reason_code VARCHAR(50),
    OUT p_refund_status_event_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_locked_refund_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_latest_status_code VARCHAR(20) DEFAULT NULL;
    DECLARE v_latest_status_at DATETIME(6) DEFAULT NULL;
    DECLARE v_refund_issue_count INT DEFAULT 0;
    DECLARE v_not_found BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_refund_status_event_id = NULL;
    SET p_refund_status_code = UPPER(TRIM(p_refund_status_code));
    SET p_status_reason_code = NULLIF(UPPER(TRIM(p_status_reason_code)), '');

    IF p_refund_id IS NULL
       OR p_status_at IS NULL
       OR p_refund_status_code IS NULL
       OR p_refund_status_code NOT IN ('FAILED', 'CANCELLED') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-003: Invalid Refund status transition';
    END IF;

    START TRANSACTION;

    SET v_not_found = FALSE;
    SELECT refund_id
      INTO v_locked_refund_id
    FROM refund
    WHERE refund_id = p_refund_id
    FOR UPDATE;

    IF v_not_found OR v_locked_refund_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-003: Refund does not exist';
    END IF;

    SET v_not_found = FALSE;
    SELECT refund_status_code, status_at
      INTO v_latest_status_code, v_latest_status_at
    FROM refund_status_event
    WHERE refund_id = p_refund_id
    ORDER BY status_at DESC, refund_status_event_id DESC
    LIMIT 1
    FOR UPDATE;

    IF v_not_found
       OR v_latest_status_code <> 'PENDING'
       OR p_status_at <= v_latest_status_at THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-003: Invalid Refund status transition';
    END IF;

    INSERT INTO refund_status_event (
        refund_id,
        refund_status_code,
        status_at,
        status_reason_code
    )
    VALUES (
        p_refund_id,
        p_refund_status_code,
        p_status_at,
        p_status_reason_code
    );

    SET p_refund_status_event_id = LAST_INSERT_ID();

    SELECT COUNT(*)
      INTO v_refund_issue_count
    FROM vw_dq_refund_status_integrity
    WHERE refund_id = p_refund_id;

    IF v_refund_issue_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-003: Refund transition failed integrity validation';
    END IF;

    COMMIT;
END$$

CREATE PROCEDURE sp_complete_refund(
    IN p_refund_id BIGINT UNSIGNED,
    IN p_completed_at DATETIME(6),
    IN p_refund_allocation_json JSON,
    OUT p_inserted_refund_allocation_count INT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_not_found BOOLEAN DEFAULT FALSE;
    DECLARE v_locked_refund_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_payment_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_refund_amount_usd DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_latest_refund_status_code VARCHAR(20) DEFAULT NULL;
    DECLARE v_latest_refund_status_at DATETIME(6) DEFAULT NULL;
    DECLARE v_locked_payment_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_eligible_attempt_count INT DEFAULT 0;
    DECLARE v_eligible_amount_usd DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_payment_allocation_count INT DEFAULT 0;
    DECLARE v_payment_allocation_total_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_payment_issue_count INT DEFAULT 0;
    DECLARE v_existing_refund_allocation_count INT DEFAULT 0;
    DECLARE v_schedule_count INT DEFAULT 0;
    DECLARE v_distinct_source_count INT DEFAULT 0;
    DECLARE v_invalid_schedule_count INT DEFAULT 0;
    DECLARE v_matching_source_count INT DEFAULT 0;
    DECLARE v_schedule_total_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_completed_payment_refund_total_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_payment_allocation_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_locked_payment_allocation_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_source_allocated_amount_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_schedule_refund_amount_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_completed_source_refund_total_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_refund_status_event_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_refund_issue_count INT DEFAULT 0;

    DECLARE refund_allocation_cursor CURSOR FOR
        SELECT
            schedule.payment_allocation_id,
            schedule.refund_allocated_amount_usd
        FROM JSON_TABLE(
            p_refund_allocation_json,
            '$[*]' COLUMNS (
                payment_allocation_id BIGINT UNSIGNED
                    PATH '$.payment_allocation_id' NULL ON EMPTY NULL ON ERROR,
                refund_allocated_amount_usd DECIMAL(12,2)
                    PATH '$.refund_allocated_amount_usd' NULL ON EMPTY NULL ON ERROR
            )
        ) AS schedule
        ORDER BY schedule.payment_allocation_id;

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

    SET p_inserted_refund_allocation_count = 0;

    IF p_refund_id IS NULL
       OR p_completed_at IS NULL
       OR p_refund_allocation_json IS NULL
       OR JSON_TYPE(p_refund_allocation_json) <> 'ARRAY'
       OR JSON_LENGTH(p_refund_allocation_json) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-004: Refund allocations do not reconcile';
    END IF;

    SELECT
        COUNT(*),
        COUNT(DISTINCT schedule.payment_allocation_id),
        COALESCE(SUM(schedule.refund_allocated_amount_usd), 0.00),
        SUM(
            schedule.payment_allocation_id IS NULL
            OR schedule.refund_allocated_amount_usd IS NULL
            OR schedule.refund_allocated_amount_usd <= 0
            OR schedule.reopens_obligation_flag IS NULL
            OR schedule.reopens_obligation_flag NOT IN (0, 1)
        )
      INTO
        v_schedule_count,
        v_distinct_source_count,
        v_schedule_total_usd,
        v_invalid_schedule_count
    FROM JSON_TABLE(
        p_refund_allocation_json,
        '$[*]' COLUMNS (
            payment_allocation_id BIGINT UNSIGNED
                PATH '$.payment_allocation_id' NULL ON EMPTY NULL ON ERROR,
            refund_allocated_amount_usd DECIMAL(12,2)
                PATH '$.refund_allocated_amount_usd' NULL ON EMPTY NULL ON ERROR,
            reopens_obligation_flag TINYINT UNSIGNED
                PATH '$.reopens_obligation_flag' NULL ON EMPTY NULL ON ERROR
        )
    ) AS schedule;

    IF v_schedule_count <> JSON_LENGTH(p_refund_allocation_json)
       OR v_distinct_source_count <> v_schedule_count
       OR v_invalid_schedule_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-006: Invalid obligation-reopening treatment';
    END IF;

    START TRANSACTION;

    SET v_not_found = FALSE;
    SELECT refund_id, payment_id, refund_amount_usd
      INTO v_locked_refund_id, v_payment_id, v_refund_amount_usd
    FROM refund
    WHERE refund_id = p_refund_id
    FOR UPDATE;

    IF v_not_found OR v_locked_refund_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-004: Refund does not exist';
    END IF;

    SET v_not_found = FALSE;
    SELECT refund_status_code, status_at
      INTO v_latest_refund_status_code, v_latest_refund_status_at
    FROM refund_status_event
    WHERE refund_id = p_refund_id
    ORDER BY status_at DESC, refund_status_event_id DESC
    LIMIT 1
    FOR UPDATE;

    IF v_not_found
       OR v_latest_refund_status_code <> 'PENDING'
       OR p_completed_at <= v_latest_refund_status_at THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-003: Invalid Refund status transition';
    END IF;

    IF v_schedule_total_usd <> v_refund_amount_usd THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-004: Refund allocations do not reconcile';
    END IF;

    SET v_not_found = FALSE;
    SELECT payment_id
      INTO v_locked_payment_id
    FROM payment
    WHERE payment_id = v_payment_id
    FOR UPDATE;

    IF v_not_found OR v_locked_payment_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-001: Original Payment does not exist';
    END IF;

    SELECT
        COUNT(*),
        MAX(ranked.attempted_amount_usd)
      INTO
        v_eligible_attempt_count,
        v_eligible_amount_usd
    FROM (
        SELECT
            attempt.payment_attempt_id,
            attempt.attempted_amount_usd,
            status_event.attempt_status_code,
            ROW_NUMBER() OVER (
                PARTITION BY attempt.payment_attempt_id
                ORDER BY status_event.status_at DESC,
                         status_event.payment_attempt_status_event_id DESC
            ) AS latest_rank
        FROM payment_attempt AS attempt
        JOIN payment_attempt_status_event AS status_event
            ON status_event.payment_attempt_id = attempt.payment_attempt_id
        WHERE attempt.payment_id = v_payment_id
    ) AS ranked
    WHERE ranked.latest_rank = 1
      AND ranked.attempt_status_code IN ('SUCCESSFUL', 'SETTLED');

    SELECT COUNT(*), COALESCE(SUM(allocated_amount_usd), 0.00)
      INTO v_payment_allocation_count, v_payment_allocation_total_usd
    FROM payment_allocation
    WHERE payment_id = v_payment_id;

    SELECT COUNT(*)
      INTO v_payment_issue_count
    FROM vw_dq_payment_reconciliation
    WHERE payment_id = v_payment_id;

    IF v_eligible_attempt_count <> 1
       OR v_eligible_amount_usd IS NULL
       OR v_payment_allocation_count = 0
       OR v_payment_allocation_total_usd <> v_eligible_amount_usd
       OR v_payment_issue_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-001: Invalid Refund request or original Payment';
    END IF;

    SELECT COUNT(*)
      INTO v_existing_refund_allocation_count
    FROM refund_allocation
    WHERE refund_id = p_refund_id;

    IF v_existing_refund_allocation_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-004: Refund already has Allocations';
    END IF;

    SELECT COUNT(*)
      INTO v_matching_source_count
    FROM JSON_TABLE(
        p_refund_allocation_json,
        '$[*]' COLUMNS (
            payment_allocation_id BIGINT UNSIGNED
                PATH '$.payment_allocation_id' NULL ON EMPTY NULL ON ERROR
        )
    ) AS schedule
    JOIN payment_allocation AS original_allocation
        ON original_allocation.payment_allocation_id = schedule.payment_allocation_id
       AND original_allocation.payment_id = v_payment_id;

    IF v_matching_source_count <> v_schedule_count THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-004: Refund source Allocation does not match Payment';
    END IF;

    SELECT COALESCE(SUM(existing_refund.refund_amount_usd), 0.00)
      INTO v_completed_payment_refund_total_usd
    FROM refund AS existing_refund
    JOIN refund_status_event AS latest_status
        ON latest_status.refund_status_event_id = (
            SELECT status_event.refund_status_event_id
            FROM refund_status_event AS status_event
            WHERE status_event.refund_id = existing_refund.refund_id
            ORDER BY status_event.status_at DESC,
                     status_event.refund_status_event_id DESC
            LIMIT 1
        )
    WHERE existing_refund.payment_id = v_payment_id
      AND existing_refund.refund_id <> p_refund_id
      AND latest_status.refund_status_code = 'COMPLETED';

    IF v_completed_payment_refund_total_usd + v_refund_amount_usd
       > v_eligible_amount_usd THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-005: Refund exceeds refundable amount';
    END IF;

    SET v_done = FALSE;
    SET v_not_found = FALSE;
    OPEN refund_allocation_cursor;

    refund_allocation_loop: LOOP
        FETCH refund_allocation_cursor
         INTO v_payment_allocation_id, v_schedule_refund_amount_usd;

        IF v_done THEN
            LEAVE refund_allocation_loop;
        END IF;

        SET v_locked_payment_allocation_id = NULL;
        SET v_not_found = FALSE;
        SELECT payment_allocation_id, allocated_amount_usd
          INTO v_locked_payment_allocation_id, v_source_allocated_amount_usd
        FROM payment_allocation
        WHERE payment_allocation_id = v_payment_allocation_id
          AND payment_id = v_payment_id
        FOR UPDATE;

        IF v_not_found OR v_locked_payment_allocation_id IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-REF-004: Source Allocation changed during locking';
        END IF;

        SELECT COALESCE(SUM(existing.refund_allocated_amount_usd), 0.00)
          INTO v_completed_source_refund_total_usd
        FROM refund_allocation AS existing
        JOIN refund_status_event AS latest_status
            ON latest_status.refund_status_event_id = (
                SELECT status_event.refund_status_event_id
                FROM refund_status_event AS status_event
                WHERE status_event.refund_id = existing.refund_id
                ORDER BY status_event.status_at DESC,
                         status_event.refund_status_event_id DESC
                LIMIT 1
            )
        WHERE existing.payment_allocation_id = v_payment_allocation_id
          AND existing.refund_id <> p_refund_id
          AND latest_status.refund_status_code = 'COMPLETED';

        IF v_completed_source_refund_total_usd + v_schedule_refund_amount_usd
           > v_source_allocated_amount_usd THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-REF-005: Refund Allocation exceeds source amount';
        END IF;
    END LOOP;

    CLOSE refund_allocation_cursor;

    INSERT INTO refund_allocation (
        refund_id,
        payment_allocation_id,
        refund_allocated_amount_usd,
        reopens_obligation_flag,
        recorded_at
    )
    SELECT
        p_refund_id,
        schedule.payment_allocation_id,
        schedule.refund_allocated_amount_usd,
        schedule.reopens_obligation_flag,
        p_completed_at
    FROM JSON_TABLE(
        p_refund_allocation_json,
        '$[*]' COLUMNS (
            payment_allocation_id BIGINT UNSIGNED
                PATH '$.payment_allocation_id' ERROR ON EMPTY ERROR ON ERROR,
            refund_allocated_amount_usd DECIMAL(12,2)
                PATH '$.refund_allocated_amount_usd' ERROR ON EMPTY ERROR ON ERROR,
            reopens_obligation_flag TINYINT UNSIGNED
                PATH '$.reopens_obligation_flag' ERROR ON EMPTY ERROR ON ERROR
        )
    ) AS schedule
    ORDER BY schedule.payment_allocation_id;

    SET p_inserted_refund_allocation_count = ROW_COUNT();

    INSERT INTO refund_status_event (
        refund_id,
        refund_status_code,
        status_at,
        status_reason_code
    )
    VALUES (
        p_refund_id,
        'COMPLETED',
        p_completed_at,
        NULL
    );

    SET v_refund_status_event_id = LAST_INSERT_ID();

    SELECT COUNT(*)
      INTO v_refund_issue_count
    FROM (
        SELECT refund_id
        FROM vw_dq_refund_status_integrity
        WHERE refund_id = p_refund_id

        UNION ALL

        SELECT refund_id
        FROM vw_dq_refund_reconciliation
        WHERE refund_id = p_refund_id
    ) AS issue;

    IF p_inserted_refund_allocation_count <> v_schedule_count
       OR v_refund_status_event_id IS NULL
       OR v_refund_issue_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-REF-004: Completed Refund failed reconciliation';
    END IF;

    COMMIT;
END$$

DELIMITER ;
