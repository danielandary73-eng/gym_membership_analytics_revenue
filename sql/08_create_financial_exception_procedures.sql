-- Gym Membership & Revenue Analytics System
-- PDM-021: Financial Exception detection, workflow, resolution, and release procedures
-- Prerequisite: run 00_create_schema.sql through 07_create_refund_procedures.sql first.

USE gym_membership_analytics;

DELIMITER $$

CREATE PROCEDURE sp_open_financial_exception(
    IN p_exception_number VARCHAR(30),
    IN p_affected_source_domain_code VARCHAR(30),
    IN p_affected_source_record_reference VARCHAR(100),
    IN p_exception_type_code VARCHAR(50),
    IN p_severity_code VARCHAR(10),
    IN p_affected_amount_usd DECIMAL(12,2),
    IN p_detected_at DATETIME(6),
    IN p_assigned_owner_code VARCHAR(50),
    OUT p_financial_exception_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_lock_name VARCHAR(64) DEFAULT NULL;
    DECLARE v_lock_acquired INT DEFAULT 0;
    DECLARE v_unresolved_match_count INT DEFAULT 0;
    DECLARE v_integrity_issue_count INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        IF v_lock_acquired = 1 THEN
            DO RELEASE_LOCK(v_lock_name);
        END IF;
        RESIGNAL;
    END;

    SET p_financial_exception_id = NULL;
    SET p_exception_number = UPPER(TRIM(p_exception_number));
    SET p_affected_source_domain_code = UPPER(TRIM(p_affected_source_domain_code));
    SET p_affected_source_record_reference = TRIM(p_affected_source_record_reference);
    SET p_exception_type_code = UPPER(TRIM(p_exception_type_code));
    SET p_severity_code = UPPER(TRIM(p_severity_code));
    SET p_assigned_owner_code = UPPER(TRIM(p_assigned_owner_code));

    IF p_exception_number IS NULL
       OR CHAR_LENGTH(p_exception_number) = 0
       OR p_exception_number LIKE '% %'
       OR p_affected_source_domain_code IS NULL
       OR p_affected_source_domain_code NOT IN (
           'CONTRACT', 'OBLIGATION', 'OBLIGATION_ADJUSTMENT', 'PAYMENT',
           'PAYMENT_ATTEMPT', 'PAYMENT_ALLOCATION', 'REFUND', 'REFUND_ALLOCATION'
       )
       OR p_affected_source_record_reference IS NULL
       OR CHAR_LENGTH(p_affected_source_record_reference) = 0
       OR p_exception_type_code IS NULL
       OR p_exception_type_code NOT IN (
           'DUPLICATE_IDENTIFIER', 'ORPHAN_REFERENCE', 'INVALID_AMOUNT',
           'EXCESSIVE_ALLOCATION', 'EXCESSIVE_REFUND', 'RECONCILIATION_DIFFERENCE',
           'INVALID_BRANCH', 'INVALID_STATUS', 'INVALID_PAYMENT_METHOD'
       )
       OR p_severity_code IS NULL
       OR p_severity_code NOT IN ('CRITICAL', 'WARNING')
       OR p_affected_amount_usd IS NULL
       OR p_affected_amount_usd < 0
       OR p_detected_at IS NULL
       OR p_detected_at > UTC_TIMESTAMP(6)
       OR p_assigned_owner_code IS NULL
       OR CHAR_LENGTH(p_assigned_owner_code) = 0
       OR p_assigned_owner_code LIKE '% %' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-002: Invalid Financial Exception opening event';
    END IF;

    SET v_lock_name = CONCAT(
        'gym:dq:',
        LEFT(SHA2(CONCAT_WS(
            '|',
            p_affected_source_domain_code,
            p_affected_source_record_reference,
            p_exception_type_code
        ), 256), 56)
    );
    SELECT GET_LOCK(v_lock_name, 10) INTO v_lock_acquired;

    IF COALESCE(v_lock_acquired, 0) <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-003: Financial Exception identity lock unavailable';
    END IF;

    START TRANSACTION;

    SELECT COUNT(*)
      INTO v_unresolved_match_count
    FROM financial_exception AS exception_record
    WHERE exception_record.affected_source_domain_code
            = p_affected_source_domain_code
      AND exception_record.affected_source_record_reference
            = p_affected_source_record_reference
      AND exception_record.exception_type_code = p_exception_type_code
      AND (
          SELECT status_event.exception_status_code
          FROM financial_exception_status_event AS status_event
          WHERE status_event.financial_exception_id
                    = exception_record.financial_exception_id
          ORDER BY status_event.status_at DESC,
                   status_event.financial_exception_status_event_id DESC
          LIMIT 1
      ) IN ('OPEN', 'UNDER_REVIEW');

    IF v_unresolved_match_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-003: Matching unresolved Financial Exception exists';
    END IF;

    INSERT INTO financial_exception (
        exception_number,
        affected_source_domain_code,
        affected_source_record_reference,
        exception_type_code,
        severity_code,
        affected_amount_usd,
        detected_at
    )
    VALUES (
        p_exception_number,
        p_affected_source_domain_code,
        p_affected_source_record_reference,
        p_exception_type_code,
        p_severity_code,
        p_affected_amount_usd,
        p_detected_at
    );

    SET p_financial_exception_id = LAST_INSERT_ID();

    INSERT INTO financial_exception_status_event (
        financial_exception_id,
        exception_status_code,
        status_at,
        assigned_owner_code,
        reporting_disposition_code,
        review_note,
        resolution_note
    )
    VALUES (
        p_financial_exception_id,
        'OPEN',
        p_detected_at,
        p_assigned_owner_code,
        'EXCLUDED',
        NULL,
        NULL
    );

    SELECT COUNT(*)
      INTO v_integrity_issue_count
    FROM vw_dq_financial_exception_integrity
    WHERE financial_exception_id = p_financial_exception_id;

    IF v_integrity_issue_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-002: Invalid Financial Exception opening event';
    END IF;

    COMMIT;
    DO RELEASE_LOCK(v_lock_name);
    SET v_lock_acquired = 0;
END$$

CREATE PROCEDURE sp_scan_financial_exceptions(
    IN p_assigned_owner_code VARCHAR(50),
    OUT p_opened_exception_count INT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_run_at DATETIME(6) DEFAULT UTC_TIMESTAMP(6);
    DECLARE v_sequence_number INT UNSIGNED DEFAULT 1;
    DECLARE v_issue_count INT UNSIGNED DEFAULT 0;
    DECLARE v_source_domain_code VARCHAR(30);
    DECLARE v_source_reference VARCHAR(100);
    DECLARE v_exception_type_code VARCHAR(50);
    DECLARE v_severity_code VARCHAR(10);
    DECLARE v_affected_amount_usd DECIMAL(12,2);
    DECLARE v_exception_number VARCHAR(30);
    DECLARE v_financial_exception_id BIGINT UNSIGNED;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        DROP TEMPORARY TABLE IF EXISTS tmp_financial_exception_scan;
        RESIGNAL;
    END;

    SET p_opened_exception_count = 0;
    SET p_assigned_owner_code = UPPER(TRIM(p_assigned_owner_code));

    IF p_assigned_owner_code IS NULL
       OR CHAR_LENGTH(p_assigned_owner_code) = 0
       OR p_assigned_owner_code LIKE '% %' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-002: Invalid Financial Exception scan owner';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_financial_exception_scan;
    CREATE TEMPORARY TABLE tmp_financial_exception_scan (
        scan_sequence INT UNSIGNED NOT NULL AUTO_INCREMENT,
        affected_source_domain_code VARCHAR(30) NOT NULL,
        affected_source_record_reference VARCHAR(100) NOT NULL,
        exception_type_code VARCHAR(50) NOT NULL,
        severity_code VARCHAR(10) NOT NULL,
        affected_amount_usd DECIMAL(12,2) NOT NULL,
        CONSTRAINT pk_tmp_financial_exception_scan PRIMARY KEY (scan_sequence)
    ) ENGINE = InnoDB;

    INSERT INTO tmp_financial_exception_scan (
        affected_source_domain_code,
        affected_source_record_reference,
        exception_type_code,
        severity_code,
        affected_amount_usd
    )
    SELECT
        source_issue.affected_source_domain_code,
        source_issue.affected_source_record_reference,
        source_issue.exception_type_code,
        CASE
            WHEN MAX(source_issue.severity_code = 'CRITICAL') = 1 THEN 'CRITICAL'
            ELSE 'WARNING'
        END,
        MAX(source_issue.affected_amount_usd)
    FROM vw_dq_financial_source_issue AS source_issue
    WHERE NOT EXISTS (
        SELECT 1
        FROM financial_exception AS exception_record
        WHERE exception_record.affected_source_domain_code
                = source_issue.affected_source_domain_code
          AND exception_record.affected_source_record_reference
                = source_issue.affected_source_record_reference
          AND exception_record.exception_type_code = source_issue.exception_type_code
          AND (
              SELECT status_event.exception_status_code
              FROM financial_exception_status_event AS status_event
              WHERE status_event.financial_exception_id
                        = exception_record.financial_exception_id
              ORDER BY status_event.status_at DESC,
                       status_event.financial_exception_status_event_id DESC
              LIMIT 1
          ) IN ('OPEN', 'UNDER_REVIEW')
    )
    GROUP BY
        source_issue.affected_source_domain_code,
        source_issue.affected_source_record_reference,
        source_issue.exception_type_code;

    SELECT COUNT(*) INTO v_issue_count
    FROM tmp_financial_exception_scan;

    WHILE v_sequence_number <= v_issue_count DO
        SELECT
            affected_source_domain_code,
            affected_source_record_reference,
            exception_type_code,
            severity_code,
            affected_amount_usd
          INTO
            v_source_domain_code,
            v_source_reference,
            v_exception_type_code,
            v_severity_code,
            v_affected_amount_usd
        FROM tmp_financial_exception_scan
        WHERE scan_sequence = v_sequence_number;

        SET v_exception_number = CONCAT(
            'FEX-', LEFT(UPPER(REPLACE(UUID(), '-', '')), 26)
        );

        CALL sp_open_financial_exception(
            v_exception_number,
            v_source_domain_code,
            v_source_reference,
            v_exception_type_code,
            v_severity_code,
            v_affected_amount_usd,
            v_run_at,
            p_assigned_owner_code,
            v_financial_exception_id
        );

        SET p_opened_exception_count = p_opened_exception_count + 1;
        SET v_sequence_number = v_sequence_number + 1;
    END WHILE;

    DROP TEMPORARY TABLE tmp_financial_exception_scan;
END$$

CREATE PROCEDURE sp_update_financial_exception_workflow(
    IN p_financial_exception_id BIGINT UNSIGNED,
    IN p_exception_status_code VARCHAR(20),
    IN p_status_at DATETIME(6),
    IN p_assigned_owner_code VARCHAR(50),
    IN p_reporting_disposition_code VARCHAR(30),
    IN p_review_note VARCHAR(1000),
    OUT p_financial_exception_status_event_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_locked_exception_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_severity_code VARCHAR(10) DEFAULT NULL;
    DECLARE v_source_domain_code VARCHAR(30) DEFAULT NULL;
    DECLARE v_source_reference VARCHAR(100) DEFAULT NULL;
    DECLARE v_exception_type_code VARCHAR(50) DEFAULT NULL;
    DECLARE v_latest_status_code VARCHAR(20) DEFAULT NULL;
    DECLARE v_latest_status_at DATETIME(6) DEFAULT NULL;
    DECLARE v_latest_owner_code VARCHAR(50) DEFAULT NULL;
    DECLARE v_latest_disposition_code VARCHAR(30) DEFAULT NULL;
    DECLARE v_latest_review_note VARCHAR(1000) DEFAULT NULL;
    DECLARE v_current_source_issue_count INT DEFAULT 0;
    DECLARE v_attributed_source_count INT DEFAULT 0;
    DECLARE v_integrity_issue_count INT DEFAULT 0;
    DECLARE v_not_found BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_financial_exception_status_event_id = NULL;
    SET p_exception_status_code = UPPER(TRIM(p_exception_status_code));
    SET p_assigned_owner_code = UPPER(TRIM(p_assigned_owner_code));
    SET p_reporting_disposition_code = UPPER(TRIM(p_reporting_disposition_code));
    SET p_review_note = NULLIF(TRIM(p_review_note), '');

    IF p_financial_exception_id IS NULL
       OR p_exception_status_code IS NULL
       OR p_exception_status_code NOT IN ('OPEN', 'UNDER_REVIEW')
       OR p_status_at IS NULL
       OR p_assigned_owner_code IS NULL
       OR CHAR_LENGTH(p_assigned_owner_code) = 0
       OR p_assigned_owner_code LIKE '% %'
       OR p_reporting_disposition_code IS NULL
       OR p_reporting_disposition_code NOT IN ('EXCLUDED', 'INCLUDED_WITH_WARNING') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-004: Invalid Financial Exception status transition';
    END IF;

    START TRANSACTION;

    SET v_not_found = FALSE;
    SELECT
        financial_exception_id,
        severity_code,
        affected_source_domain_code,
        affected_source_record_reference,
        exception_type_code
      INTO
        v_locked_exception_id,
        v_severity_code,
        v_source_domain_code,
        v_source_reference,
        v_exception_type_code
    FROM financial_exception
    WHERE financial_exception_id = p_financial_exception_id
    FOR UPDATE;

    IF v_not_found OR v_locked_exception_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-004: Financial Exception does not exist';
    END IF;

    SET v_not_found = FALSE;
    SELECT
        exception_status_code,
        status_at,
        assigned_owner_code,
        reporting_disposition_code,
        review_note
      INTO
        v_latest_status_code,
        v_latest_status_at,
        v_latest_owner_code,
        v_latest_disposition_code,
        v_latest_review_note
    FROM financial_exception_status_event
    WHERE financial_exception_id = p_financial_exception_id
    ORDER BY status_at DESC, financial_exception_status_event_id DESC
    LIMIT 1
    FOR UPDATE;

    IF v_not_found
       OR p_status_at <= v_latest_status_at
       OR (v_latest_status_code = 'OPEN'
           AND p_exception_status_code NOT IN ('OPEN', 'UNDER_REVIEW'))
       OR (v_latest_status_code = 'UNDER_REVIEW'
           AND p_exception_status_code <> 'UNDER_REVIEW')
       OR v_latest_status_code = 'RESOLVED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-004: Invalid Financial Exception status transition';
    END IF;

    IF v_severity_code = 'CRITICAL'
       AND p_reporting_disposition_code <> 'EXCLUDED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-005: Invalid reporting disposition for severity or status';
    END IF;

    IF p_reporting_disposition_code = 'INCLUDED_WITH_WARNING' THEN
        SELECT COUNT(*)
          INTO v_current_source_issue_count
        FROM vw_dq_financial_source_issue
        WHERE affected_source_domain_code = v_source_domain_code
          AND affected_source_record_reference = v_source_reference
          AND exception_type_code = v_exception_type_code;

        SELECT COUNT(*)
          INTO v_attributed_source_count
        FROM vw_reporting_financial_source_disposition
        WHERE financial_exception_id = p_financial_exception_id
          AND branch_attribution_status = 'ATTRIBUTED';

        IF v_severity_code <> 'WARNING'
           OR p_review_note IS NULL
           OR v_current_source_issue_count > 0
           OR v_attributed_source_count = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-DQ-005: Warning source has not passed trust verification';
        END IF;
    END IF;

    IF p_exception_status_code = v_latest_status_code
       AND p_assigned_owner_code = v_latest_owner_code
       AND p_reporting_disposition_code = v_latest_disposition_code
       AND p_review_note <=> v_latest_review_note THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-004: Workflow event contains no new evidence or assignment';
    END IF;

    INSERT INTO financial_exception_status_event (
        financial_exception_id,
        exception_status_code,
        status_at,
        assigned_owner_code,
        reporting_disposition_code,
        review_note,
        resolution_note
    )
    VALUES (
        p_financial_exception_id,
        p_exception_status_code,
        p_status_at,
        p_assigned_owner_code,
        p_reporting_disposition_code,
        p_review_note,
        NULL
    );

    SET p_financial_exception_status_event_id = LAST_INSERT_ID();

    SELECT COUNT(*)
      INTO v_integrity_issue_count
    FROM vw_dq_financial_exception_integrity
    WHERE financial_exception_id = p_financial_exception_id;

    IF v_integrity_issue_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-004: Financial Exception workflow failed validation';
    END IF;

    COMMIT;
END$$

CREATE PROCEDURE sp_resolve_financial_exception(
    IN p_financial_exception_id BIGINT UNSIGNED,
    IN p_status_at DATETIME(6),
    IN p_assigned_owner_code VARCHAR(50),
    IN p_reporting_disposition_code VARCHAR(30),
    IN p_resolution_note VARCHAR(1000),
    OUT p_financial_exception_status_event_id BIGINT UNSIGNED
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_locked_exception_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_source_domain_code VARCHAR(30) DEFAULT NULL;
    DECLARE v_source_reference VARCHAR(100) DEFAULT NULL;
    DECLARE v_exception_type_code VARCHAR(50) DEFAULT NULL;
    DECLARE v_latest_status_code VARCHAR(20) DEFAULT NULL;
    DECLARE v_latest_status_at DATETIME(6) DEFAULT NULL;
    DECLARE v_latest_review_note VARCHAR(1000) DEFAULT NULL;
    DECLARE v_current_source_issue_count INT DEFAULT 0;
    DECLARE v_attributed_source_count INT DEFAULT 0;
    DECLARE v_integrity_issue_count INT DEFAULT 0;
    DECLARE v_not_found BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_financial_exception_status_event_id = NULL;
    SET p_assigned_owner_code = UPPER(TRIM(p_assigned_owner_code));
    SET p_reporting_disposition_code = UPPER(TRIM(p_reporting_disposition_code));
    SET p_resolution_note = NULLIF(TRIM(p_resolution_note), '');

    IF p_financial_exception_id IS NULL
       OR p_status_at IS NULL
       OR p_assigned_owner_code IS NULL
       OR CHAR_LENGTH(p_assigned_owner_code) = 0
       OR p_assigned_owner_code LIKE '% %'
       OR p_reporting_disposition_code IS NULL
       OR p_reporting_disposition_code NOT IN ('EXCLUDED', 'ELIGIBLE')
       OR p_resolution_note IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-006: Resolution evidence or source revalidation failed';
    END IF;

    START TRANSACTION;

    SET v_not_found = FALSE;
    SELECT
        financial_exception_id,
        affected_source_domain_code,
        affected_source_record_reference,
        exception_type_code
      INTO
        v_locked_exception_id,
        v_source_domain_code,
        v_source_reference,
        v_exception_type_code
    FROM financial_exception
    WHERE financial_exception_id = p_financial_exception_id
    FOR UPDATE;

    IF v_not_found OR v_locked_exception_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-006: Financial Exception does not exist';
    END IF;

    SET v_not_found = FALSE;
    SELECT exception_status_code, status_at, review_note
      INTO v_latest_status_code, v_latest_status_at, v_latest_review_note
    FROM financial_exception_status_event
    WHERE financial_exception_id = p_financial_exception_id
    ORDER BY status_at DESC, financial_exception_status_event_id DESC
    LIMIT 1
    FOR UPDATE;

    IF v_not_found
       OR v_latest_status_code NOT IN ('OPEN', 'UNDER_REVIEW')
       OR p_status_at <= v_latest_status_at THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-004: Invalid Financial Exception status transition';
    END IF;

    IF p_reporting_disposition_code = 'ELIGIBLE' THEN
        SELECT COUNT(*)
          INTO v_current_source_issue_count
        FROM vw_dq_financial_source_issue
        WHERE affected_source_domain_code = v_source_domain_code
          AND affected_source_record_reference = v_source_reference
          AND exception_type_code = v_exception_type_code;

        SELECT COUNT(*)
          INTO v_attributed_source_count
        FROM vw_reporting_financial_source_disposition
        WHERE financial_exception_id = p_financial_exception_id
          AND branch_attribution_status = 'ATTRIBUTED';

        IF v_current_source_issue_count > 0 OR v_attributed_source_count = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'GYM-DQ-006: Resolution evidence or source revalidation failed';
        END IF;
    END IF;

    INSERT INTO financial_exception_status_event (
        financial_exception_id,
        exception_status_code,
        status_at,
        assigned_owner_code,
        reporting_disposition_code,
        review_note,
        resolution_note
    )
    VALUES (
        p_financial_exception_id,
        'RESOLVED',
        p_status_at,
        p_assigned_owner_code,
        p_reporting_disposition_code,
        v_latest_review_note,
        p_resolution_note
    );

    SET p_financial_exception_status_event_id = LAST_INSERT_ID();

    SELECT COUNT(*)
      INTO v_integrity_issue_count
    FROM vw_dq_financial_exception_integrity
    WHERE financial_exception_id = p_financial_exception_id;

    IF v_integrity_issue_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-006: Resolution evidence or source revalidation failed';
    END IF;

    COMMIT;
END$$

CREATE PROCEDURE sp_assert_financial_release_ready(
    OUT p_unresolved_critical_source_count BIGINT UNSIGNED,
    OUT p_unresolved_warning_source_count BIGINT UNSIGNED,
    OUT p_unresolved_critical_amount_usd DECIMAL(12,2),
    OUT p_unresolved_warning_amount_usd DECIMAL(12,2)
)
SQL SECURITY DEFINER
READS SQL DATA
BEGIN
    DECLARE v_evaluated_at DATETIME(6);
    DECLARE v_release_readiness_code VARCHAR(10);

    SELECT
        evaluated_at,
        unresolved_critical_source_count,
        unresolved_warning_source_count,
        unresolved_critical_amount_usd,
        unresolved_warning_amount_usd,
        release_readiness_code
      INTO
        v_evaluated_at,
        p_unresolved_critical_source_count,
        p_unresolved_warning_source_count,
        p_unresolved_critical_amount_usd,
        p_unresolved_warning_amount_usd,
        v_release_readiness_code
    FROM vw_dq_financial_release_readiness;

    SELECT
        v_evaluated_at AS evaluated_at,
        p_unresolved_critical_source_count AS unresolved_critical_source_count,
        p_unresolved_warning_source_count AS unresolved_warning_source_count,
        p_unresolved_critical_amount_usd AS unresolved_critical_amount_usd,
        p_unresolved_warning_amount_usd AS unresolved_warning_amount_usd,
        v_release_readiness_code AS release_readiness_code;

    IF p_unresolved_critical_source_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-DQ-010: Unresolved Critical Exceptions block release';
    END IF;
END$$

DELIMITER ;
