-- NONCANONICAL RECOVERY SCRIPT — DO NOT RUN during a fresh build or normal rerun.
-- Creates only the 10 tables that were missing from one interrupted live build.
-- Retained solely as historical recovery evidence for the exact state verified
-- on 2026-09-08. The canonical 01_create_tables.sql now creates all 21 tables.

USE gym_membership_analytics;

CREATE TABLE membership_status_event (
    membership_status_event_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    membership_contract_id BIGINT UNSIGNED NOT NULL,
    event_type_code VARCHAR(20) NOT NULL,
    recorded_at DATETIME(6) NOT NULL,
    effective_start_date DATE NOT NULL,
    effective_end_date DATE NULL DEFAULT NULL,
    reason_code VARCHAR(50) NULL DEFAULT NULL,
    reverses_membership_status_event_id BIGINT UNSIGNED NULL DEFAULT NULL,
    CONSTRAINT pk_membership_status_event PRIMARY KEY (membership_status_event_id),
    CONSTRAINT ck_membership_status_event_type CHECK (
        event_type_code IN ('CANCELLATION', 'FREEZE', 'REVERSAL')
    ),
    CONSTRAINT ck_membership_status_event_period CHECK (
        (event_type_code = 'FREEZE'
            AND effective_end_date IS NOT NULL
            AND effective_end_date >= effective_start_date)
        OR (event_type_code IN ('CANCELLATION', 'REVERSAL') AND effective_end_date IS NULL)
    ),
    CONSTRAINT ck_membership_status_event_reason CHECK (
        reason_code IS NULL OR CHAR_LENGTH(TRIM(reason_code)) > 0
    ),
    CONSTRAINT ck_membership_status_event_reversal_shape CHECK (
        (event_type_code = 'REVERSAL' AND reverses_membership_status_event_id IS NOT NULL)
        OR (event_type_code <> 'REVERSAL' AND reverses_membership_status_event_id IS NULL)
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE payment_obligation (
    payment_obligation_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    obligation_number VARCHAR(30) NOT NULL,
    membership_contract_id BIGINT UNSIGNED NOT NULL,
    obligation_sequence_number SMALLINT UNSIGNED NOT NULL,
    original_obligation_amount_usd DECIMAL(12,2) NOT NULL,
    due_date DATE NOT NULL,
    CONSTRAINT pk_payment_obligation PRIMARY KEY (payment_obligation_id),
    CONSTRAINT ck_payment_obligation_number_nonblank CHECK (
        CHAR_LENGTH(TRIM(obligation_number)) > 0
    ),
    CONSTRAINT ck_payment_obligation_number_format CHECK (
        CAST(obligation_number AS BINARY) = CAST(UPPER(obligation_number) AS BINARY)
        AND obligation_number NOT LIKE '% %'
    ),
    CONSTRAINT ck_payment_obligation_sequence CHECK (obligation_sequence_number > 0),
    CONSTRAINT ck_payment_obligation_amount CHECK (original_obligation_amount_usd > 0)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE payment (
    payment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    payment_number VARCHAR(30) NOT NULL,
    membership_contract_id BIGINT UNSIGNED NOT NULL,
    requested_at DATETIME(6) NOT NULL,
    requested_amount_usd DECIMAL(12,2) NOT NULL,
    intended_payment_method_code VARCHAR(20) NOT NULL,
    CONSTRAINT pk_payment PRIMARY KEY (payment_id),
    CONSTRAINT ck_payment_number_nonblank CHECK (CHAR_LENGTH(TRIM(payment_number)) > 0),
    CONSTRAINT ck_payment_number_format CHECK (
        CAST(payment_number AS BINARY) = CAST(UPPER(payment_number) AS BINARY)
        AND payment_number NOT LIKE '% %'
    ),
    CONSTRAINT ck_payment_requested_amount CHECK (requested_amount_usd > 0),
    CONSTRAINT ck_payment_intended_method CHECK (
        intended_payment_method_code IN ('CASH', 'CARD', 'BANK_TRANSFER')
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE membership_status_decision_event (
    membership_status_decision_event_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    membership_status_event_id BIGINT UNSIGNED NOT NULL,
    decision_status_code VARCHAR(10) NOT NULL,
    decision_at DATETIME(6) NOT NULL,
    CONSTRAINT pk_membership_status_decision_event PRIMARY KEY (membership_status_decision_event_id),
    CONSTRAINT ck_membership_status_decision_status CHECK (
        decision_status_code IN ('PENDING', 'APPROVED', 'REJECTED')
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE payment_obligation_adjustment (
    payment_obligation_adjustment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    payment_obligation_id BIGINT UNSIGNED NOT NULL,
    membership_status_event_id BIGINT UNSIGNED NOT NULL,
    adjustment_amount_usd DECIMAL(12,2) NOT NULL,
    recorded_at DATETIME(6) NOT NULL,
    CONSTRAINT pk_payment_obligation_adjustment PRIMARY KEY (payment_obligation_adjustment_id),
    CONSTRAINT ck_payment_obligation_adjustment_amount CHECK (adjustment_amount_usd > 0)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE payment_attempt (
    payment_attempt_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    attempt_number VARCHAR(30) NOT NULL,
    payment_id BIGINT UNSIGNED NOT NULL,
    attempt_sequence_number SMALLINT UNSIGNED NOT NULL,
    attempted_at DATETIME(6) NOT NULL,
    attempted_amount_usd DECIMAL(12,2) NOT NULL,
    payment_method_code VARCHAR(20) NOT NULL,
    processing_branch_id BIGINT UNSIGNED NOT NULL,
    CONSTRAINT pk_payment_attempt PRIMARY KEY (payment_attempt_id),
    CONSTRAINT ck_payment_attempt_number_nonblank CHECK (CHAR_LENGTH(TRIM(attempt_number)) > 0),
    CONSTRAINT ck_payment_attempt_number_format CHECK (
        CAST(attempt_number AS BINARY) = CAST(UPPER(attempt_number) AS BINARY)
        AND attempt_number NOT LIKE '% %'
    ),
    CONSTRAINT ck_payment_attempt_sequence CHECK (attempt_sequence_number > 0),
    CONSTRAINT ck_payment_attempt_amount CHECK (attempted_amount_usd > 0),
    CONSTRAINT ck_payment_attempt_method CHECK (
        payment_method_code IN ('CASH', 'CARD', 'BANK_TRANSFER')
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE payment_allocation (
    payment_allocation_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    payment_id BIGINT UNSIGNED NOT NULL,
    payment_obligation_id BIGINT UNSIGNED NOT NULL,
    allocated_amount_usd DECIMAL(12,2) NOT NULL,
    recorded_at DATETIME(6) NOT NULL,
    CONSTRAINT pk_payment_allocation PRIMARY KEY (payment_allocation_id),
    CONSTRAINT ck_payment_allocation_amount CHECK (allocated_amount_usd > 0)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE refund (
    refund_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    refund_number VARCHAR(30) NOT NULL,
    payment_id BIGINT UNSIGNED NOT NULL,
    requested_at DATETIME(6) NOT NULL,
    refund_amount_usd DECIMAL(12,2) NOT NULL,
    refund_reason_code VARCHAR(50) NOT NULL,
    CONSTRAINT pk_refund PRIMARY KEY (refund_id),
    CONSTRAINT ck_refund_number_nonblank CHECK (CHAR_LENGTH(TRIM(refund_number)) > 0),
    CONSTRAINT ck_refund_number_format CHECK (
        CAST(refund_number AS BINARY) = CAST(UPPER(refund_number) AS BINARY)
        AND refund_number NOT LIKE '% %'
    ),
    CONSTRAINT ck_refund_amount CHECK (refund_amount_usd > 0),
    CONSTRAINT ck_refund_reason_nonblank CHECK (CHAR_LENGTH(TRIM(refund_reason_code)) > 0),
    CONSTRAINT ck_refund_reason_format CHECK (
        CAST(refund_reason_code AS BINARY) = CAST(UPPER(refund_reason_code) AS BINARY)
        AND refund_reason_code NOT LIKE '% %'
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE payment_attempt_status_event (
    payment_attempt_status_event_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    payment_attempt_id BIGINT UNSIGNED NOT NULL,
    attempt_status_code VARCHAR(20) NOT NULL,
    status_at DATETIME(6) NOT NULL,
    reason_code VARCHAR(50) NULL DEFAULT NULL,
    CONSTRAINT pk_payment_attempt_status_event PRIMARY KEY (payment_attempt_status_event_id),
    CONSTRAINT ck_payment_attempt_status CHECK (
        attempt_status_code IN ('PENDING', 'SUCCESSFUL', 'SETTLED', 'FAILED', 'CANCELLED', 'REVERSED')
    ),
    CONSTRAINT ck_payment_attempt_status_reason CHECK (
        reason_code IS NULL OR CHAR_LENGTH(TRIM(reason_code)) > 0
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE refund_status_event (
    refund_status_event_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    refund_id BIGINT UNSIGNED NOT NULL,
    refund_status_code VARCHAR(20) NOT NULL,
    status_at DATETIME(6) NOT NULL,
    status_reason_code VARCHAR(50) NULL DEFAULT NULL,
    CONSTRAINT pk_refund_status_event PRIMARY KEY (refund_status_event_id),
    CONSTRAINT ck_refund_status CHECK (
        refund_status_code IN ('PENDING', 'COMPLETED', 'FAILED', 'CANCELLED')
    ),
    CONSTRAINT ck_refund_status_reason CHECK (
        status_reason_code IS NULL OR CHAR_LENGTH(TRIM(status_reason_code)) > 0
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
