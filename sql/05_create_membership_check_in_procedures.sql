-- Gym Membership & Revenue Analytics System
-- PDM-018: temporal, membership, cancellation-adjustment, and Check-In procedures
-- Prerequisite: run 00_create_schema.sql through 04_create_views.sql first.

USE gym_membership_analytics;

DELIMITER $$

CREATE PROCEDURE sp_create_membership_plan_version(
    IN p_plan_id BIGINT UNSIGNED,
    IN p_plan_name VARCHAR(100),
    IN p_standard_duration_months SMALLINT UNSIGNED,
    IN p_standard_price_usd DECIMAL(12,2),
    IN p_available_from_date DATE,
    IN p_available_to_date DATE,
    OUT p_plan_version_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_locked_plan_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_overlap_count INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_plan_version_id = NULL;

    IF p_plan_id IS NULL
       OR p_plan_name IS NULL
       OR CHAR_LENGTH(TRIM(p_plan_name)) = 0
       OR p_standard_duration_months IS NULL
       OR p_standard_duration_months = 0
       OR p_standard_price_usd IS NULL
       OR p_standard_price_usd < 0
       OR p_available_from_date IS NULL
       OR (p_available_to_date IS NOT NULL
           AND p_available_to_date < p_available_from_date) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-TMP-001: Invalid Plan Version definition';
    END IF;

    START TRANSACTION;

    SELECT plan_id
      INTO v_locked_plan_id
    FROM membership_plan
    WHERE plan_id = p_plan_id
    FOR UPDATE;

    IF v_locked_plan_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-TMP-001: Membership Plan does not exist';
    END IF;

    UPDATE membership_plan_version
    SET available_to_date = DATE_SUB(p_available_from_date, INTERVAL 1 DAY)
    WHERE plan_id = p_plan_id
      AND available_to_date IS NULL
      AND available_from_date < p_available_from_date;

    SELECT COUNT(*)
      INTO v_overlap_count
    FROM membership_plan_version
    WHERE plan_id = p_plan_id
      AND available_from_date <= COALESCE(p_available_to_date, DATE('9999-12-31'))
      AND p_available_from_date <= COALESCE(available_to_date, DATE('9999-12-31'));

    IF v_overlap_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-TMP-001: Plan version periods overlap';
    END IF;

    INSERT INTO membership_plan_version (
        plan_id,
        plan_name,
        standard_duration_months,
        standard_price_usd,
        available_from_date,
        available_to_date
    )
    VALUES (
        p_plan_id,
        TRIM(p_plan_name),
        p_standard_duration_months,
        p_standard_price_usd,
        p_available_from_date,
        p_available_to_date
    );

    SET p_plan_version_id = LAST_INSERT_ID();
    COMMIT;
END$$

CREATE PROCEDURE sp_ingest_check_in(
    IN p_source_check_in_reference VARCHAR(100),
    IN p_member_number VARCHAR(20),
    IN p_visited_branch_code VARCHAR(10),
    IN p_check_in_at DATETIME(6),
    IN p_recorded_at DATETIME(6),
    OUT p_check_in_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_member_count INT DEFAULT 0;
    DECLARE v_member_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_branch_count INT DEFAULT 0;
    DECLARE v_visited_branch_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_duplicate_count INT DEFAULT 0;
    DECLARE v_inactive_issue_needed INT DEFAULT 0;
    DECLARE v_lock_name VARCHAR(64) DEFAULT NULL;
    DECLARE v_lock_acquired INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        IF v_lock_acquired = 1 THEN
            DO RELEASE_LOCK(v_lock_name);
        END IF;
        RESIGNAL;
    END;

    SET p_check_in_id = NULL;

    IF p_recorded_at IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-ENG-001: Check-In receipt timestamp is required';
    END IF;

    IF p_check_in_at IS NOT NULL
       AND CONVERT_TZ(p_check_in_at, '+00:00', 'Asia/Beirut') IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-ENG-001: Asia/Beirut time-zone data is unavailable';
    END IF;

    START TRANSACTION;

    IF p_source_check_in_reference IS NOT NULL
       AND CHAR_LENGTH(TRIM(p_source_check_in_reference)) > 0 THEN
        SET v_lock_name = CONCAT(
            'gym_ci_',
            LEFT(SHA2(UPPER(TRIM(p_source_check_in_reference)), 256), 56)
        );
        SET v_lock_acquired = GET_LOCK(v_lock_name, 10);

        IF v_lock_acquired <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-ENG-001: Check-In source lock could not be acquired';
        END IF;

        SELECT COUNT(*)
          INTO v_duplicate_count
        FROM check_in
        WHERE UPPER(TRIM(source_check_in_reference))
                = UPPER(TRIM(p_source_check_in_reference));
    END IF;

    IF p_member_number IS NOT NULL
       AND CHAR_LENGTH(TRIM(p_member_number)) > 0 THEN
        SELECT COUNT(*), MIN(member_id)
          INTO v_member_count, v_member_id
        FROM member
        WHERE member_number = UPPER(TRIM(p_member_number));
    END IF;

    IF p_visited_branch_code IS NOT NULL
       AND CHAR_LENGTH(TRIM(p_visited_branch_code)) > 0 THEN
        SELECT COUNT(*), MIN(branch_id)
          INTO v_branch_count, v_visited_branch_id
        FROM branch
        WHERE branch_code = UPPER(TRIM(p_visited_branch_code));
    END IF;

    INSERT INTO check_in (
        source_check_in_reference,
        member_id,
        visited_branch_id,
        check_in_at,
        recorded_at
    )
    VALUES (
        NULLIF(TRIM(p_source_check_in_reference), ''),
        CASE WHEN v_member_count = 1 THEN v_member_id ELSE NULL END,
        CASE WHEN v_branch_count = 1 THEN v_visited_branch_id ELSE NULL END,
        p_check_in_at,
        p_recorded_at
    );

    SET p_check_in_id = LAST_INSERT_ID();

    IF p_source_check_in_reference IS NULL
       OR CHAR_LENGTH(TRIM(p_source_check_in_reference)) = 0 THEN
        INSERT INTO check_in_quality_issue (
            check_in_id, issue_code, detected_at, resolved_at, resolution_note
        ) VALUES (
            p_check_in_id, 'MISSING_SOURCE_REFERENCE', p_recorded_at, NULL, NULL
        );
    END IF;

    IF p_member_number IS NULL
       OR CHAR_LENGTH(TRIM(p_member_number)) = 0
       OR v_member_count <> 1 THEN
        INSERT INTO check_in_quality_issue (
            check_in_id, issue_code, detected_at, resolved_at, resolution_note
        ) VALUES (
            p_check_in_id, 'UNMATCHED_MEMBER_REFERENCE', p_recorded_at, NULL, NULL
        );
    END IF;

    IF p_visited_branch_code IS NULL
       OR CHAR_LENGTH(TRIM(p_visited_branch_code)) = 0
       OR v_branch_count <> 1 THEN
        INSERT INTO check_in_quality_issue (
            check_in_id, issue_code, detected_at, resolved_at, resolution_note
        ) VALUES (
            p_check_in_id, 'UNMATCHED_VISITED_BRANCH_REFERENCE', p_recorded_at, NULL, NULL
        );
    END IF;

    IF p_check_in_at IS NULL THEN
        INSERT INTO check_in_quality_issue (
            check_in_id, issue_code, detected_at, resolved_at, resolution_note
        ) VALUES (
            p_check_in_id, 'MISSING_CHECK_IN_TIMESTAMP', p_recorded_at, NULL, NULL
        );
    END IF;

    IF v_duplicate_count > 0 THEN
        INSERT INTO check_in_quality_issue (
            check_in_id, issue_code, detected_at, resolved_at, resolution_note
        )
        SELECT
            duplicate_reference.check_in_id,
            'DUPLICATE_SOURCE_REFERENCE',
            p_recorded_at,
            NULL,
            NULL
        FROM vw_dq_check_in_duplicate_reference AS duplicate_reference
        WHERE duplicate_reference.normalized_source_reference
                = UPPER(TRIM(p_source_check_in_reference))
          AND duplicate_reference.occurrence_rank > 1
          AND NOT EXISTS (
              SELECT 1
              FROM check_in_quality_issue AS existing_issue
              WHERE existing_issue.check_in_id = duplicate_reference.check_in_id
                AND existing_issue.issue_code = 'DUPLICATE_SOURCE_REFERENCE'
                AND existing_issue.resolved_at IS NULL
          );
    END IF;

    IF v_member_count = 1 AND p_check_in_at IS NOT NULL THEN
        SELECT COUNT(*)
          INTO v_inactive_issue_needed
        FROM vw_dq_check_in_integrity
        WHERE check_in_id = p_check_in_id
          AND issue_code = 'INACTIVE_MEMBERSHIP'
          AND integrity_result = 'MISSING_OPEN_ISSUE';

        IF v_inactive_issue_needed > 0 THEN
            INSERT INTO check_in_quality_issue (
                check_in_id, issue_code, detected_at, resolved_at, resolution_note
            ) VALUES (
                p_check_in_id, 'INACTIVE_MEMBERSHIP', p_recorded_at, NULL, NULL
            );
        END IF;
    END IF;

    COMMIT;

    IF v_lock_acquired = 1 THEN
        DO RELEASE_LOCK(v_lock_name);
    END IF;
END$$

CREATE PROCEDURE sp_resolve_check_in_quality_issue(
    IN p_check_in_quality_issue_id BIGINT UNSIGNED,
    IN p_corrected_source_reference VARCHAR(100),
    IN p_corrected_member_number VARCHAR(20),
    IN p_corrected_visited_branch_code VARCHAR(10),
    IN p_corrected_check_in_at DATETIME(6),
    IN p_resolved_at DATETIME(6),
    IN p_resolution_note VARCHAR(500)
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_check_in_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_locked_check_in_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_locked_issue_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_issue_code VARCHAR(50) DEFAULT NULL;
    DECLARE v_detected_at DATETIME(6) DEFAULT NULL;
    DECLARE v_existing_resolved_at DATETIME(6) DEFAULT NULL;
    DECLARE v_member_count INT DEFAULT 0;
    DECLARE v_member_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_branch_count INT DEFAULT 0;
    DECLARE v_branch_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_source_duplicate_count INT DEFAULT 0;
    DECLARE v_stale_issue_count INT DEFAULT 0;
    DECLARE v_new_untracked_issue_count INT DEFAULT 0;
    DECLARE v_lock_name VARCHAR(64) DEFAULT NULL;
    DECLARE v_lock_acquired INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @gym_allow_check_in_correction = NULL;
        SET @gym_allow_check_in_issue_resolution = NULL;
        ROLLBACK;
        IF v_lock_acquired = 1 THEN
            DO RELEASE_LOCK(v_lock_name);
        END IF;
        RESIGNAL;
    END;

    IF p_check_in_quality_issue_id IS NULL
       OR p_resolved_at IS NULL
       OR p_resolution_note IS NULL
       OR CHAR_LENGTH(TRIM(p_resolution_note)) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-ENG-005: Resolution time and evidence are required';
    END IF;

    SELECT check_in_id
      INTO v_check_in_id
    FROM check_in_quality_issue
    WHERE check_in_quality_issue_id = p_check_in_quality_issue_id;

    IF v_check_in_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-ENG-005: Check-In Quality Issue does not exist';
    END IF;

    IF p_corrected_source_reference IS NOT NULL
       AND CHAR_LENGTH(TRIM(p_corrected_source_reference)) > 0 THEN
        SET v_lock_name = CONCAT(
            'gym_ci_',
            LEFT(SHA2(UPPER(TRIM(p_corrected_source_reference)), 256), 56)
        );
        SET v_lock_acquired = GET_LOCK(v_lock_name, 10);

        IF v_lock_acquired <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-ENG-005: Check-In source lock could not be acquired';
        END IF;

        SELECT COUNT(*)
          INTO v_source_duplicate_count
        FROM check_in
        WHERE UPPER(TRIM(source_check_in_reference))
                = UPPER(TRIM(p_corrected_source_reference))
          AND check_in_id <> v_check_in_id;

        IF v_source_duplicate_count > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-ENG-005: Corrected source reference is already used';
        END IF;
    END IF;

    START TRANSACTION;

    SELECT check_in_id
      INTO v_locked_check_in_id
    FROM check_in
    WHERE check_in_id = v_check_in_id
    FOR UPDATE;

    SELECT
        check_in_quality_issue_id,
        issue_code,
        detected_at,
        resolved_at
      INTO
        v_locked_issue_id,
        v_issue_code,
        v_detected_at,
        v_existing_resolved_at
    FROM check_in_quality_issue
    WHERE check_in_quality_issue_id = p_check_in_quality_issue_id
      AND check_in_id = v_locked_check_in_id
    FOR UPDATE;

    IF v_locked_issue_id IS NULL OR v_existing_resolved_at IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-ENG-005: Quality Issue is missing or already resolved';
    END IF;

    IF p_resolved_at < v_detected_at THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-ENG-005: Resolution time precedes detection';
    END IF;

    IF (
        v_issue_code IN ('MISSING_SOURCE_REFERENCE', 'DUPLICATE_SOURCE_REFERENCE')
        AND (
            p_corrected_member_number IS NOT NULL
            OR p_corrected_visited_branch_code IS NOT NULL
            OR p_corrected_check_in_at IS NOT NULL
        )
    ) OR (
        v_issue_code = 'UNMATCHED_MEMBER_REFERENCE'
        AND (
            p_corrected_source_reference IS NOT NULL
            OR p_corrected_visited_branch_code IS NOT NULL
            OR p_corrected_check_in_at IS NOT NULL
        )
    ) OR (
        v_issue_code = 'UNMATCHED_VISITED_BRANCH_REFERENCE'
        AND (
            p_corrected_source_reference IS NOT NULL
            OR p_corrected_member_number IS NOT NULL
            OR p_corrected_check_in_at IS NOT NULL
        )
    ) OR (
        v_issue_code = 'MISSING_CHECK_IN_TIMESTAMP'
        AND (
            p_corrected_source_reference IS NOT NULL
            OR p_corrected_member_number IS NOT NULL
            OR p_corrected_visited_branch_code IS NOT NULL
        )
    ) OR (
        v_issue_code = 'INACTIVE_MEMBERSHIP'
        AND (
            p_corrected_source_reference IS NOT NULL
            OR p_corrected_visited_branch_code IS NOT NULL
        )
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-ENG-005: Correction does not match selected issue';
    END IF;

    IF p_corrected_member_number IS NOT NULL THEN
        SELECT COUNT(*), MIN(member_id)
          INTO v_member_count, v_member_id
        FROM member
        WHERE member_number = UPPER(TRIM(p_corrected_member_number));

        IF v_member_count <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-ENG-005: Corrected Member reference is unresolved';
        END IF;
    END IF;

    IF p_corrected_visited_branch_code IS NOT NULL THEN
        SELECT COUNT(*), MIN(branch_id)
          INTO v_branch_count, v_branch_id
        FROM branch
        WHERE branch_code = UPPER(TRIM(p_corrected_visited_branch_code));

        IF v_branch_count <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-ENG-005: Corrected Visited Branch reference is unresolved';
        END IF;
    END IF;

    IF p_corrected_check_in_at IS NOT NULL
       AND CONVERT_TZ(p_corrected_check_in_at, '+00:00', 'Asia/Beirut') IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-ENG-005: Asia/Beirut time-zone data is unavailable';
    END IF;

    IF p_corrected_source_reference IS NOT NULL
       OR p_corrected_member_number IS NOT NULL
       OR p_corrected_visited_branch_code IS NOT NULL
       OR p_corrected_check_in_at IS NOT NULL THEN
        SET @gym_allow_check_in_correction = 1;

        UPDATE check_in
        SET source_check_in_reference = CASE
                WHEN p_corrected_source_reference IS NOT NULL
                THEN NULLIF(TRIM(p_corrected_source_reference), '')
                ELSE source_check_in_reference
            END,
            member_id = CASE
                WHEN p_corrected_member_number IS NOT NULL THEN v_member_id
                ELSE member_id
            END,
            visited_branch_id = CASE
                WHEN p_corrected_visited_branch_code IS NOT NULL THEN v_branch_id
                ELSE visited_branch_id
            END,
            check_in_at = CASE
                WHEN p_corrected_check_in_at IS NOT NULL THEN p_corrected_check_in_at
                ELSE check_in_at
            END
        WHERE check_in_id = v_check_in_id;

        SET @gym_allow_check_in_correction = NULL;
    END IF;

    SELECT COUNT(*)
      INTO v_stale_issue_count
    FROM vw_dq_check_in_integrity
    WHERE check_in_id = v_check_in_id
      AND check_in_quality_issue_id = p_check_in_quality_issue_id
      AND issue_code = v_issue_code
      AND integrity_result = 'STALE_OPEN_ISSUE';

    SELECT COUNT(*)
      INTO v_new_untracked_issue_count
    FROM vw_dq_check_in_integrity
    WHERE check_in_id = v_check_in_id
      AND integrity_result = 'MISSING_OPEN_ISSUE';

    IF v_stale_issue_count <> 1 OR v_new_untracked_issue_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-ENG-005: Check-In quality issue is not resolved';
    END IF;

    SET @gym_allow_check_in_issue_resolution = 1;

    UPDATE check_in_quality_issue
    SET resolved_at = p_resolved_at,
        resolution_note = TRIM(p_resolution_note)
    WHERE check_in_quality_issue_id = p_check_in_quality_issue_id;

    SET @gym_allow_check_in_issue_resolution = NULL;

    COMMIT;

    IF v_lock_acquired = 1 THEN
        DO RELEASE_LOCK(v_lock_name);
    END IF;
END$$

CREATE PROCEDURE sp_record_cancellation_adjustments(
    IN p_membership_status_event_id BIGINT UNSIGNED,
    IN p_recorded_at DATETIME(6)
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_obligation_id BIGINT UNSIGNED;
    DECLARE v_original_amount DECIMAL(12,2);
    DECLARE v_prior_adjustment DECIMAL(12,2);
    DECLARE v_applied_amount DECIMAL(12,2);
    DECLARE v_reopened_amount DECIMAL(12,2);
    DECLARE v_unpaid_remainder DECIMAL(12,2);
    DECLARE v_contract_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_cancellation_date DATE DEFAULT NULL;
    DECLARE v_valid_cancellation_count INT DEFAULT 0;

    DECLARE obligation_cursor CURSOR FOR
        SELECT
            obligation.payment_obligation_id,
            obligation.original_obligation_amount_usd
        FROM payment_obligation AS obligation
        WHERE obligation.membership_contract_id = v_contract_id
          AND obligation.due_date >= v_cancellation_date
        ORDER BY obligation.payment_obligation_id
        FOR UPDATE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    SELECT
        status_event.membership_contract_id,
        status_event.effective_start_date,
        COUNT(*)
      INTO v_contract_id, v_cancellation_date, v_valid_cancellation_count
    FROM membership_status_event AS status_event
    JOIN membership_status_decision_event AS decision
        ON decision.membership_status_event_id = status_event.membership_status_event_id
    WHERE status_event.membership_status_event_id = p_membership_status_event_id
      AND status_event.event_type_code = 'CANCELLATION'
      AND decision.decision_status_code = 'APPROVED'
      AND NOT EXISTS (
          SELECT 1
          FROM membership_status_decision_event AS later_decision
          WHERE later_decision.membership_status_event_id = status_event.membership_status_event_id
            AND (
                later_decision.decision_at > decision.decision_at
                OR (
                    later_decision.decision_at = decision.decision_at
                    AND later_decision.membership_status_decision_event_id
                        > decision.membership_status_decision_event_id
                )
            )
      )
      AND NOT EXISTS (
          SELECT 1
          FROM membership_status_event AS reversal
          JOIN membership_status_decision_event AS reversal_decision
              ON reversal_decision.membership_status_event_id
                  = reversal.membership_status_event_id
          WHERE reversal.event_type_code = 'REVERSAL'
            AND reversal.reverses_membership_status_event_id
                = status_event.membership_status_event_id
            AND reversal_decision.decision_status_code = 'APPROVED'
            AND NOT EXISTS (
                SELECT 1
                FROM membership_status_decision_event AS later_reversal_decision
                WHERE later_reversal_decision.membership_status_event_id
                        = reversal.membership_status_event_id
                  AND (
                      later_reversal_decision.decision_at > reversal_decision.decision_at
                      OR (
                          later_reversal_decision.decision_at = reversal_decision.decision_at
                          AND later_reversal_decision.membership_status_decision_event_id
                              > reversal_decision.membership_status_decision_event_id
                      )
                  )
            )
      )
    GROUP BY status_event.membership_contract_id, status_event.effective_start_date;

    IF v_valid_cancellation_count <> 1 OR v_contract_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-004: Invalid Cancellation adjustment target';
    END IF;

    OPEN obligation_cursor;

    adjustment_loop: LOOP
        FETCH obligation_cursor INTO v_obligation_id, v_original_amount;
        IF v_done THEN
            LEAVE adjustment_loop;
        END IF;

        SELECT COALESCE(SUM(adjustment_amount_usd), 0.00)
          INTO v_prior_adjustment
        FROM payment_obligation_adjustment
        WHERE payment_obligation_id = v_obligation_id;

        SELECT COALESCE(SUM(allocated_amount_usd), 0.00)
          INTO v_applied_amount
        FROM payment_allocation
        WHERE payment_obligation_id = v_obligation_id
          AND recorded_at <= p_recorded_at;

        SELECT COALESCE(SUM(refund_allocation.refund_allocated_amount_usd), 0.00)
          INTO v_reopened_amount
        FROM refund_allocation
        JOIN payment_allocation AS original_allocation
            ON original_allocation.payment_allocation_id
                = refund_allocation.payment_allocation_id
        JOIN refund_status_event AS completed_status
            ON completed_status.refund_id = refund_allocation.refund_id
           AND completed_status.refund_status_code = 'COMPLETED'
           AND completed_status.status_at <= p_recorded_at
        WHERE original_allocation.payment_obligation_id = v_obligation_id
          AND refund_allocation.reopens_obligation_flag = 1
          AND refund_allocation.recorded_at <= p_recorded_at;

        SET v_unpaid_remainder = GREATEST(
            v_original_amount
            - v_prior_adjustment
            - v_applied_amount
            + v_reopened_amount,
            0.00
        );

        IF v_unpaid_remainder > 0 THEN
            INSERT INTO payment_obligation_adjustment (
                payment_obligation_id,
                membership_status_event_id,
                adjustment_amount_usd,
                recorded_at
            )
            VALUES (
                v_obligation_id,
                p_membership_status_event_id,
                v_unpaid_remainder,
                p_recorded_at
            );
        END IF;
    END LOOP;

    CLOSE obligation_cursor;
END$$

CREATE PROCEDURE sp_submit_membership_status_event(
    IN p_membership_contract_id BIGINT UNSIGNED,
    IN p_event_type_code VARCHAR(20),
    IN p_recorded_at DATETIME(6),
    IN p_effective_start_date DATE,
    IN p_effective_end_date DATE,
    IN p_reason_code VARCHAR(50),
    IN p_reverses_membership_status_event_id BIGINT UNSIGNED,
    OUT p_membership_status_event_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_locked_contract_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_contract_created_date DATE DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_membership_status_event_id = NULL;
    SET p_event_type_code = UPPER(TRIM(p_event_type_code));

    IF p_membership_contract_id IS NULL
       OR p_event_type_code IS NULL
       OR p_event_type_code NOT IN ('CANCELLATION', 'FREEZE', 'REVERSAL')
       OR p_recorded_at IS NULL
       OR p_effective_start_date IS NULL
       OR (
           p_event_type_code = 'FREEZE'
           AND (p_effective_end_date IS NULL
                OR p_effective_end_date < p_effective_start_date)
       )
       OR (p_event_type_code IN ('CANCELLATION', 'REVERSAL')
           AND p_effective_end_date IS NOT NULL)
       OR (p_event_type_code = 'REVERSAL'
           AND p_reverses_membership_status_event_id IS NULL)
       OR (p_event_type_code <> 'REVERSAL'
           AND p_reverses_membership_status_event_id IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-WFL-001: Invalid Membership Status Event';
    END IF;

    START TRANSACTION;

    SELECT membership_contract_id, contract_created_date
      INTO v_locked_contract_id, v_contract_created_date
    FROM membership_contract
    WHERE membership_contract_id = p_membership_contract_id
    FOR UPDATE;

    IF v_locked_contract_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-WFL-001: Membership Contract does not exist';
    END IF;

    IF p_recorded_at < TIMESTAMP(v_contract_created_date) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-WFL-006: Invalid event or decision timestamp order';
    END IF;

    INSERT INTO membership_status_event (
        membership_contract_id,
        event_type_code,
        recorded_at,
        effective_start_date,
        effective_end_date,
        reason_code,
        reverses_membership_status_event_id
    )
    VALUES (
        p_membership_contract_id,
        p_event_type_code,
        p_recorded_at,
        p_effective_start_date,
        p_effective_end_date,
        NULLIF(TRIM(p_reason_code), ''),
        p_reverses_membership_status_event_id
    );

    SET p_membership_status_event_id = LAST_INSERT_ID();

    INSERT INTO membership_status_decision_event (
        membership_status_event_id,
        decision_status_code,
        decision_at
    )
    VALUES (
        p_membership_status_event_id,
        'PENDING',
        p_recorded_at
    );

    COMMIT;
END$$

CREATE PROCEDURE sp_decide_membership_status_event(
    IN p_membership_status_event_id BIGINT UNSIGNED,
    IN p_decision_status_code VARCHAR(10),
    IN p_decision_at DATETIME(6),
    OUT p_membership_status_decision_event_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_contract_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_locked_contract_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_locked_status_event_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_event_type_code VARCHAR(20) DEFAULT NULL;
    DECLARE v_recorded_at DATETIME(6) DEFAULT NULL;
    DECLARE v_latest_decision_code VARCHAR(10) DEFAULT NULL;
    DECLARE v_latest_decision_at DATETIME(6) DEFAULT NULL;
    DECLARE v_integrity_issue_count INT DEFAULT 0;
    DECLARE v_service_overlap_count INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_membership_status_decision_event_id = NULL;
    SET p_decision_status_code = UPPER(TRIM(p_decision_status_code));

    IF p_membership_status_event_id IS NULL
       OR p_decision_status_code IS NULL
       OR p_decision_status_code NOT IN ('APPROVED', 'REJECTED')
       OR p_decision_at IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-WFL-002: Invalid terminal decision';
    END IF;

    SELECT membership_contract_id
      INTO v_contract_id
    FROM membership_status_event
    WHERE membership_status_event_id = p_membership_status_event_id;

    IF v_contract_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-WFL-002: Membership Status Event does not exist';
    END IF;

    START TRANSACTION;

    SELECT membership_contract_id
      INTO v_locked_contract_id
    FROM membership_contract
    WHERE membership_contract_id = v_contract_id
    FOR UPDATE;

    SELECT membership_status_event_id, event_type_code, recorded_at
      INTO v_locked_status_event_id, v_event_type_code, v_recorded_at
    FROM membership_status_event
    WHERE membership_status_event_id = p_membership_status_event_id
      AND membership_contract_id = v_locked_contract_id
    FOR UPDATE;

    SELECT decision_status_code, decision_at
      INTO v_latest_decision_code, v_latest_decision_at
    FROM membership_status_decision_event
    WHERE membership_status_event_id = p_membership_status_event_id
    ORDER BY decision_at DESC, membership_status_decision_event_id DESC
    LIMIT 1
    FOR UPDATE;

    IF v_locked_status_event_id IS NULL
       OR v_latest_decision_code <> 'PENDING' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-WFL-002: Invalid or duplicate terminal decision';
    END IF;

    IF p_decision_at <= v_latest_decision_at
       OR p_decision_at <= v_recorded_at THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-WFL-006: Invalid event or decision timestamp order';
    END IF;

    INSERT INTO membership_status_decision_event (
        membership_status_event_id,
        decision_status_code,
        decision_at
    )
    VALUES (
        p_membership_status_event_id,
        p_decision_status_code,
        p_decision_at
    );

    SET p_membership_status_decision_event_id = LAST_INSERT_ID();

    IF p_decision_status_code = 'APPROVED' THEN
        SELECT COUNT(*)
          INTO v_integrity_issue_count
        FROM vw_dq_membership_status_integrity
        WHERE membership_status_event_id = p_membership_status_event_id
           OR related_membership_status_event_id = p_membership_status_event_id;

        IF v_integrity_issue_count > 0 THEN
            IF v_event_type_code = 'FREEZE' THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'GYM-WFL-003: Freeze is ineligible or overlaps another Freeze';
            ELSEIF v_event_type_code = 'CANCELLATION' THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'GYM-WFL-004: Contract already has an effective Cancellation';
            ELSE
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'GYM-WFL-005: Invalid or already reversed status target';
            END IF;
        END IF;

        SELECT COUNT(*)
          INTO v_service_overlap_count
        FROM vw_dq_contract_service_overlap
        WHERE left_membership_contract_id = v_contract_id
           OR right_membership_contract_id = v_contract_id;

        IF v_service_overlap_count > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-MEM-004: Membership service periods overlap';
        END IF;

        IF v_event_type_code = 'CANCELLATION' THEN
            CALL sp_record_cancellation_adjustments(
                p_membership_status_event_id,
                p_decision_at
            );
        END IF;
    END IF;

    COMMIT;
END$$

CREATE PROCEDURE sp_assign_member_home_branch(
    IN p_member_id BIGINT UNSIGNED,
    IN p_home_branch_id BIGINT UNSIGNED,
    IN p_effective_start_date DATE,
    IN p_effective_end_date DATE,
    OUT p_member_branch_assignment_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_locked_member_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_locked_branch_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_branch_opened_date DATE DEFAULT NULL;
    DECLARE v_branch_closed_date DATE DEFAULT NULL;
    DECLARE v_overlap_count INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_member_branch_assignment_id = NULL;

    IF p_member_id IS NULL
       OR p_home_branch_id IS NULL
       OR p_effective_start_date IS NULL
       OR (p_effective_end_date IS NOT NULL
           AND p_effective_end_date < p_effective_start_date) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-TMP-002: Invalid Home Branch assignment';
    END IF;

    START TRANSACTION;

    SELECT member_id
      INTO v_locked_member_id
    FROM member
    WHERE member_id = p_member_id
    FOR UPDATE;

    IF v_locked_member_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-TMP-002: Member does not exist';
    END IF;

    SELECT branch_id, opened_date, closed_date
      INTO v_locked_branch_id, v_branch_opened_date, v_branch_closed_date
    FROM branch
    WHERE branch_id = p_home_branch_id
    FOR UPDATE;

    IF v_locked_branch_id IS NULL
       OR p_effective_start_date < v_branch_opened_date
       OR (v_branch_closed_date IS NOT NULL
           AND (p_effective_end_date IS NULL
                OR p_effective_end_date > v_branch_closed_date)) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-TMP-002: Home Branch is not valid for assignment period';
    END IF;

    UPDATE member_branch_assignment
    SET effective_end_date = DATE_SUB(p_effective_start_date, INTERVAL 1 DAY)
    WHERE member_id = p_member_id
      AND effective_end_date IS NULL
      AND effective_start_date < p_effective_start_date;

    SELECT COUNT(*)
      INTO v_overlap_count
    FROM member_branch_assignment
    WHERE member_id = p_member_id
      AND effective_start_date <= COALESCE(p_effective_end_date, DATE('9999-12-31'))
      AND p_effective_start_date <= COALESCE(effective_end_date, DATE('9999-12-31'));

    IF v_overlap_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-TMP-002: Home Branch assignment periods overlap';
    END IF;

    INSERT INTO member_branch_assignment (
        member_id,
        home_branch_id,
        effective_start_date,
        effective_end_date
    )
    VALUES (
        p_member_id,
        p_home_branch_id,
        p_effective_start_date,
        p_effective_end_date
    );

    SET p_member_branch_assignment_id = LAST_INSERT_ID();
    COMMIT;
END$$

CREATE PROCEDURE sp_create_membership_contract(
    IN p_contract_number VARCHAR(30),
    IN p_member_id BIGINT UNSIGNED,
    IN p_plan_version_id BIGINT UNSIGNED,
    IN p_previous_membership_contract_id BIGINT UNSIGNED,
    IN p_contract_created_date DATE,
    IN p_service_start_date DATE,
    IN p_original_end_date DATE,
    IN p_historical_list_price_usd DECIMAL(12,2),
    IN p_discount_amount_usd DECIMAL(12,2),
    IN p_payment_schedule_type_code VARCHAR(20),
    IN p_obligation_schedule_json JSON,
    OUT p_membership_contract_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_locked_member_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_locked_plan_version_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_plan_available_from DATE DEFAULT NULL;
    DECLARE v_plan_available_to DATE DEFAULT NULL;
    DECLARE v_financial_branch_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_home_branch_count INT DEFAULT 0;
    DECLARE v_expected_previous_contract_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_locked_previous_contract_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_expected_revenue_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_schedule_count INT DEFAULT 0;
    DECLARE v_schedule_total_usd DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_schedule_problem_count INT DEFAULT 0;
    DECLARE v_overlap_count INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_membership_contract_id = NULL;
    SET p_payment_schedule_type_code = UPPER(TRIM(p_payment_schedule_type_code));

    IF p_contract_number IS NULL
       OR CHAR_LENGTH(TRIM(p_contract_number)) = 0
       OR p_member_id IS NULL
       OR p_plan_version_id IS NULL
       OR p_contract_created_date IS NULL
       OR p_service_start_date IS NULL
       OR p_original_end_date IS NULL
       OR p_original_end_date < p_service_start_date
       OR p_historical_list_price_usd IS NULL
       OR p_historical_list_price_usd < 0
       OR p_discount_amount_usd IS NULL
       OR p_discount_amount_usd < 0
       OR p_discount_amount_usd > p_historical_list_price_usd
       OR p_payment_schedule_type_code IS NULL
       OR p_payment_schedule_type_code NOT IN ('FULL', 'INSTALLMENT') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-MEM-001: Invalid Membership Contract definition';
    END IF;

    SET v_expected_revenue_usd = p_historical_list_price_usd - p_discount_amount_usd;

    IF p_obligation_schedule_json IS NOT NULL THEN
        SET v_schedule_count = JSON_LENGTH(p_obligation_schedule_json);
    END IF;

    IF v_expected_revenue_usd = 0 AND v_schedule_count <> 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-001: Invalid obligation requirement for Expected Revenue';
    END IF;

    IF v_expected_revenue_usd > 0 AND v_schedule_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-FIN-001: Invalid obligation requirement for Expected Revenue';
    END IF;

    IF v_schedule_count > 0 THEN
        SELECT
            COALESCE(SUM(schedule.obligation_amount_usd), 0.00),
            SUM(
                schedule.obligation_number IS NULL
                OR CHAR_LENGTH(TRIM(schedule.obligation_number)) = 0
                OR schedule.obligation_sequence_number IS NULL
                OR schedule.obligation_sequence_number = 0
                OR schedule.obligation_amount_usd IS NULL
                OR schedule.obligation_amount_usd <= 0
                OR schedule.due_date IS NULL
            )
          INTO v_schedule_total_usd, v_schedule_problem_count
        FROM JSON_TABLE(
            p_obligation_schedule_json,
            '$[*]' COLUMNS (
                obligation_number VARCHAR(30) PATH '$.obligation_number' NULL ON EMPTY,
                obligation_sequence_number SMALLINT UNSIGNED PATH '$.sequence_number' NULL ON EMPTY,
                obligation_amount_usd DECIMAL(12,2) PATH '$.amount_usd' NULL ON EMPTY,
                due_date DATE PATH '$.due_date' NULL ON EMPTY
            )
        ) AS schedule;

        SELECT v_schedule_problem_count + COUNT(*)
          INTO v_schedule_problem_count
        FROM (
            SELECT
                parsed.obligation_sequence_number,
                parsed.due_date,
                LAG(parsed.due_date) OVER (
                    ORDER BY parsed.obligation_sequence_number
                ) AS prior_due_date
            FROM JSON_TABLE(
                p_obligation_schedule_json,
                '$[*]' COLUMNS (
                    obligation_sequence_number SMALLINT UNSIGNED PATH '$.sequence_number' NULL ON EMPTY,
                    due_date DATE PATH '$.due_date' NULL ON EMPTY
                )
            ) AS parsed
        ) AS ordered_schedule
        WHERE ordered_schedule.prior_due_date IS NOT NULL
          AND ordered_schedule.due_date < ordered_schedule.prior_due_date;

        SELECT v_schedule_problem_count +
               (v_schedule_count - COUNT(DISTINCT parsed.obligation_sequence_number)) +
               IF(COALESCE(MIN(parsed.obligation_sequence_number), 0) <> 1, 1, 0) +
               IF(COALESCE(MAX(parsed.obligation_sequence_number), 0)
                    <> v_schedule_count, 1, 0)
          INTO v_schedule_problem_count
        FROM JSON_TABLE(
            p_obligation_schedule_json,
            '$[*]' COLUMNS (
                obligation_sequence_number SMALLINT UNSIGNED PATH '$.sequence_number' NULL ON EMPTY
            )
        ) AS parsed;

        IF v_schedule_total_usd <> v_expected_revenue_usd
           OR v_schedule_problem_count > 0
           OR (p_payment_schedule_type_code = 'FULL' AND v_schedule_count <> 1)
           OR (p_payment_schedule_type_code = 'INSTALLMENT' AND v_schedule_count < 2) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-FIN-002: Obligation schedule does not reconcile';
        END IF;

        IF p_payment_schedule_type_code = 'FULL' THEN
            SELECT COUNT(*)
              INTO v_schedule_problem_count
            FROM JSON_TABLE(
                p_obligation_schedule_json,
                '$[*]' COLUMNS (
                    obligation_sequence_number SMALLINT UNSIGNED PATH '$.sequence_number',
                    due_date DATE PATH '$.due_date'
                )
            ) AS full_schedule
            WHERE full_schedule.obligation_sequence_number <> 1
               OR full_schedule.due_date <> p_service_start_date;

            IF v_schedule_problem_count > 0 THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'GYM-FIN-002: Full obligation schedule is invalid';
            END IF;
        END IF;
    END IF;

    START TRANSACTION;

    SELECT member_id
      INTO v_locked_member_id
    FROM member
    WHERE member_id = p_member_id
    FOR UPDATE;

    IF v_locked_member_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-MEM-001: Member does not exist';
    END IF;

    SELECT plan_version_id, available_from_date, available_to_date
      INTO v_locked_plan_version_id, v_plan_available_from, v_plan_available_to
    FROM membership_plan_version
    WHERE plan_version_id = p_plan_version_id
    FOR UPDATE;

    IF v_locked_plan_version_id IS NULL
       OR p_contract_created_date < v_plan_available_from
       OR (v_plan_available_to IS NOT NULL
           AND p_contract_created_date > v_plan_available_to) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-MEM-001: Plan version is not valid on contract date';
    END IF;

    SELECT COUNT(*), MIN(home_branch_id)
      INTO v_home_branch_count, v_financial_branch_id
    FROM member_branch_assignment
    WHERE member_id = p_member_id
      AND effective_start_date <= p_service_start_date
      AND (effective_end_date IS NULL OR effective_end_date >= p_service_start_date);

    IF v_home_branch_count <> 1 OR v_financial_branch_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-MEM-002: Financial Branch does not match Home Branch';
    END IF;

    SET v_expected_previous_contract_id = NULL;
    SELECT membership_contract_id
      INTO v_expected_previous_contract_id
    FROM membership_contract
    WHERE member_id = p_member_id
      AND service_start_date < p_service_start_date
    ORDER BY service_start_date DESC, membership_contract_id DESC
    LIMIT 1;

    IF NOT (p_previous_membership_contract_id <=> v_expected_previous_contract_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-MEM-003: Invalid immediate predecessor contract';
    END IF;

    IF p_previous_membership_contract_id IS NOT NULL THEN
        SELECT membership_contract_id
          INTO v_locked_previous_contract_id
        FROM membership_contract
        WHERE membership_contract_id = p_previous_membership_contract_id
          AND member_id = p_member_id
        FOR UPDATE;

        IF v_locked_previous_contract_id IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-MEM-003: Invalid immediate predecessor contract';
        END IF;
    END IF;

    INSERT INTO membership_contract (
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
    VALUES (
        UPPER(TRIM(p_contract_number)),
        p_member_id,
        p_plan_version_id,
        v_financial_branch_id,
        p_previous_membership_contract_id,
        p_contract_created_date,
        p_service_start_date,
        p_original_end_date,
        p_historical_list_price_usd,
        p_discount_amount_usd,
        UPPER(TRIM(p_payment_schedule_type_code))
    );

    SET p_membership_contract_id = LAST_INSERT_ID();

    IF v_schedule_count > 0 THEN
        INSERT INTO payment_obligation (
            obligation_number,
            membership_contract_id,
            obligation_sequence_number,
            original_obligation_amount_usd,
            due_date
        )
        SELECT
            UPPER(TRIM(schedule.obligation_number)),
            p_membership_contract_id,
            schedule.obligation_sequence_number,
            schedule.obligation_amount_usd,
            schedule.due_date
        FROM JSON_TABLE(
            p_obligation_schedule_json,
            '$[*]' COLUMNS (
                obligation_number VARCHAR(30) PATH '$.obligation_number',
                obligation_sequence_number SMALLINT UNSIGNED PATH '$.sequence_number',
                obligation_amount_usd DECIMAL(12,2) PATH '$.amount_usd',
                due_date DATE PATH '$.due_date'
            )
        ) AS schedule
        ORDER BY schedule.obligation_sequence_number;
    END IF;

    SELECT COUNT(*)
      INTO v_overlap_count
    FROM vw_dq_contract_service_overlap
    WHERE left_membership_contract_id = p_membership_contract_id
       OR right_membership_contract_id = p_membership_contract_id;

    IF v_overlap_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-MEM-004: Membership service periods overlap';
    END IF;

    COMMIT;
END$$

DELIMITER ;
