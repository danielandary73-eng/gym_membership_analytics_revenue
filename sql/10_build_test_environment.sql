-- Gym Membership & Revenue Analytics System
-- PDM-023 isolated functional-test environment
-- WARNING: drops and rebuilds only gym_membership_analytics_test.

DROP DATABASE IF EXISTS gym_membership_analytics_test;

-- Gym Membership & Revenue Analytics System
-- PDM-015 schema foundation: schema and controlled session standard
-- Target: MySQL 8.0+
-- Safety: this script never drops an existing schema or object.

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION time_zone = '+00:00';
SET SESSION sql_mode =
    'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

CREATE DATABASE IF NOT EXISTS gym_membership_analytics_test
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE gym_membership_analytics_test;
-- Gym Membership & Revenue Analytics System
-- PDM-015 schema foundation: 21 tables, 131 fields, row-local checks, and primary keys
-- Prerequisite: run 00_create_schema.sql first against a fresh or empty schema.
-- The pk_* constraint symbols preserve design traceability in source; MySQL exposes
-- each primary key under its required runtime name PRIMARY.

USE gym_membership_analytics_test;

CREATE TABLE branch (
    branch_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    branch_code VARCHAR(10) NOT NULL,
    branch_name VARCHAR(100) NOT NULL,
    city_name VARCHAR(100) NOT NULL,
    opened_date DATE NOT NULL,
    closed_date DATE NULL DEFAULT NULL,
    CONSTRAINT pk_branch PRIMARY KEY (branch_id),
    CONSTRAINT ck_branch_code_nonblank CHECK (CHAR_LENGTH(TRIM(branch_code)) > 0),
    CONSTRAINT ck_branch_code_format CHECK (
        CAST(branch_code AS BINARY) = CAST(UPPER(branch_code) AS BINARY)
        AND branch_code NOT LIKE '% %'
    ),
    CONSTRAINT ck_branch_name_nonblank CHECK (CHAR_LENGTH(TRIM(branch_name)) > 0),
    CONSTRAINT ck_branch_city_nonblank CHECK (CHAR_LENGTH(TRIM(city_name)) > 0),
    CONSTRAINT ck_branch_dates CHECK (closed_date IS NULL OR closed_date >= opened_date)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE membership_plan (
    plan_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    plan_code VARCHAR(20) NOT NULL,
    CONSTRAINT pk_membership_plan PRIMARY KEY (plan_id),
    CONSTRAINT ck_membership_plan_code_nonblank CHECK (CHAR_LENGTH(TRIM(plan_code)) > 0),
    CONSTRAINT ck_membership_plan_code_format CHECK (
        CAST(plan_code AS BINARY) = CAST(UPPER(plan_code) AS BINARY)
        AND plan_code NOT LIKE '% %'
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE member (
    member_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    member_number VARCHAR(20) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    registration_date DATE NOT NULL,
    email_address VARCHAR(254) NULL DEFAULT NULL,
    mobile_phone VARCHAR(20) NULL DEFAULT NULL,
    CONSTRAINT pk_member PRIMARY KEY (member_id),
    CONSTRAINT ck_member_number_nonblank CHECK (CHAR_LENGTH(TRIM(member_number)) > 0),
    CONSTRAINT ck_member_number_format CHECK (
        CAST(member_number AS BINARY) = CAST(UPPER(member_number) AS BINARY)
        AND member_number NOT LIKE '% %'
    ),
    CONSTRAINT ck_member_first_name_nonblank CHECK (CHAR_LENGTH(TRIM(first_name)) > 0),
    CONSTRAINT ck_member_last_name_nonblank CHECK (CHAR_LENGTH(TRIM(last_name)) > 0),
    CONSTRAINT ck_member_email_nonblank CHECK (
        email_address IS NULL OR CHAR_LENGTH(TRIM(email_address)) > 0
    ),
    CONSTRAINT ck_member_phone_nonblank CHECK (
        mobile_phone IS NULL OR CHAR_LENGTH(TRIM(mobile_phone)) > 0
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE financial_exception (
    financial_exception_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    exception_number VARCHAR(30) NOT NULL,
    affected_source_domain_code VARCHAR(30) NOT NULL,
    affected_source_record_reference VARCHAR(100) NOT NULL,
    exception_type_code VARCHAR(50) NOT NULL,
    severity_code VARCHAR(10) NOT NULL,
    affected_amount_usd DECIMAL(12,2) NOT NULL,
    detected_at DATETIME(6) NOT NULL,
    CONSTRAINT pk_financial_exception PRIMARY KEY (financial_exception_id),
    CONSTRAINT ck_financial_exception_number_nonblank CHECK (
        CHAR_LENGTH(TRIM(exception_number)) > 0
    ),
    CONSTRAINT ck_financial_exception_number_format CHECK (
        CAST(exception_number AS BINARY) = CAST(UPPER(exception_number) AS BINARY)
        AND exception_number NOT LIKE '% %'
    ),
    CONSTRAINT ck_financial_exception_domain CHECK (
        affected_source_domain_code IN (
            'CONTRACT', 'OBLIGATION', 'OBLIGATION_ADJUSTMENT', 'PAYMENT',
            'PAYMENT_ATTEMPT', 'PAYMENT_ALLOCATION', 'REFUND', 'REFUND_ALLOCATION'
        )
    ),
    CONSTRAINT ck_financial_exception_source_nonblank CHECK (
        CHAR_LENGTH(TRIM(affected_source_record_reference)) > 0
    ),
    CONSTRAINT ck_financial_exception_type CHECK (
        exception_type_code IN (
            'DUPLICATE_IDENTIFIER', 'ORPHAN_REFERENCE', 'INVALID_AMOUNT',
            'EXCESSIVE_ALLOCATION', 'EXCESSIVE_REFUND', 'RECONCILIATION_DIFFERENCE',
            'INVALID_BRANCH', 'INVALID_STATUS', 'INVALID_PAYMENT_METHOD'
        )
    ),
    CONSTRAINT ck_financial_exception_severity CHECK (severity_code IN ('CRITICAL', 'WARNING')),
    CONSTRAINT ck_financial_exception_amount CHECK (affected_amount_usd >= 0)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE membership_plan_version (
    plan_version_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    plan_id BIGINT UNSIGNED NOT NULL,
    plan_name VARCHAR(100) NOT NULL,
    standard_duration_months SMALLINT UNSIGNED NOT NULL,
    standard_price_usd DECIMAL(12,2) NOT NULL,
    available_from_date DATE NOT NULL,
    available_to_date DATE NULL DEFAULT NULL,
    CONSTRAINT pk_membership_plan_version PRIMARY KEY (plan_version_id),
    CONSTRAINT ck_membership_plan_version_name CHECK (CHAR_LENGTH(TRIM(plan_name)) > 0),
    CONSTRAINT ck_membership_plan_version_duration CHECK (standard_duration_months > 0),
    CONSTRAINT ck_membership_plan_version_price CHECK (standard_price_usd >= 0),
    CONSTRAINT ck_membership_plan_version_dates CHECK (
        available_to_date IS NULL OR available_to_date >= available_from_date
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE member_branch_assignment (
    member_branch_assignment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    member_id BIGINT UNSIGNED NOT NULL,
    home_branch_id BIGINT UNSIGNED NOT NULL,
    effective_start_date DATE NOT NULL,
    effective_end_date DATE NULL DEFAULT NULL,
    CONSTRAINT pk_member_branch_assignment PRIMARY KEY (member_branch_assignment_id),
    CONSTRAINT ck_member_branch_assignment_dates CHECK (
        effective_end_date IS NULL OR effective_end_date >= effective_start_date
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE check_in (
    check_in_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    source_check_in_reference VARCHAR(100) NULL DEFAULT NULL,
    member_id BIGINT UNSIGNED NULL DEFAULT NULL,
    visited_branch_id BIGINT UNSIGNED NULL DEFAULT NULL,
    check_in_at DATETIME(6) NULL DEFAULT NULL,
    recorded_at DATETIME(6) NOT NULL,
    CONSTRAINT pk_check_in PRIMARY KEY (check_in_id),
    CONSTRAINT ck_check_in_source_reference_nonblank CHECK (
        source_check_in_reference IS NULL
        OR CHAR_LENGTH(TRIM(source_check_in_reference)) > 0
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE financial_exception_status_event (
    financial_exception_status_event_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    financial_exception_id BIGINT UNSIGNED NOT NULL,
    exception_status_code VARCHAR(20) NOT NULL,
    status_at DATETIME(6) NOT NULL,
    assigned_owner_code VARCHAR(50) NOT NULL,
    reporting_disposition_code VARCHAR(30) NOT NULL,
    review_note VARCHAR(1000) NULL DEFAULT NULL,
    resolution_note VARCHAR(1000) NULL DEFAULT NULL,
    CONSTRAINT pk_financial_exception_status_event PRIMARY KEY (financial_exception_status_event_id),
    CONSTRAINT ck_financial_exception_status CHECK (
        exception_status_code IN ('OPEN', 'UNDER_REVIEW', 'RESOLVED')
    ),
    CONSTRAINT ck_financial_exception_owner_nonblank CHECK (
        CHAR_LENGTH(TRIM(assigned_owner_code)) > 0
    ),
    CONSTRAINT ck_financial_exception_owner_format CHECK (
        CAST(assigned_owner_code AS BINARY) = CAST(UPPER(assigned_owner_code) AS BINARY)
        AND assigned_owner_code NOT LIKE '% %'
    ),
    CONSTRAINT ck_financial_exception_disposition CHECK (
        reporting_disposition_code IN ('EXCLUDED', 'INCLUDED_WITH_WARNING', 'ELIGIBLE')
    ),
    CONSTRAINT ck_financial_exception_review_note CHECK (
        review_note IS NULL OR CHAR_LENGTH(TRIM(review_note)) > 0
    ),
    CONSTRAINT ck_financial_exception_resolution_note CHECK (
        resolution_note IS NULL OR CHAR_LENGTH(TRIM(resolution_note)) > 0
    ),
    CONSTRAINT ck_financial_exception_resolved_evidence CHECK (
        exception_status_code <> 'RESOLVED'
        OR (
            resolution_note IS NOT NULL
            AND CHAR_LENGTH(TRIM(resolution_note)) > 0
        )
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE membership_contract (
    membership_contract_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    contract_number VARCHAR(30) NOT NULL,
    member_id BIGINT UNSIGNED NOT NULL,
    plan_version_id BIGINT UNSIGNED NOT NULL,
    financial_ownership_branch_id BIGINT UNSIGNED NOT NULL,
    previous_membership_contract_id BIGINT UNSIGNED NULL DEFAULT NULL,
    contract_created_date DATE NOT NULL,
    service_start_date DATE NOT NULL,
    original_end_date DATE NOT NULL,
    historical_list_price_usd DECIMAL(12,2) NOT NULL,
    discount_amount_usd DECIMAL(12,2) NOT NULL,
    payment_schedule_type_code VARCHAR(20) NOT NULL,
    CONSTRAINT pk_membership_contract PRIMARY KEY (membership_contract_id),
    CONSTRAINT ck_membership_contract_number_nonblank CHECK (
        CHAR_LENGTH(TRIM(contract_number)) > 0
    ),
    CONSTRAINT ck_membership_contract_number_format CHECK (
        CAST(contract_number AS BINARY) = CAST(UPPER(contract_number) AS BINARY)
        AND contract_number NOT LIKE '% %'
    ),
    CONSTRAINT ck_membership_contract_dates CHECK (original_end_date >= service_start_date),
    CONSTRAINT ck_membership_contract_price CHECK (historical_list_price_usd >= 0),
    CONSTRAINT ck_membership_contract_discount CHECK (
        discount_amount_usd >= 0
        AND discount_amount_usd <= historical_list_price_usd
    ),
    CONSTRAINT ck_membership_contract_schedule CHECK (
        payment_schedule_type_code IN ('FULL', 'INSTALLMENT')
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE check_in_quality_issue (
    check_in_quality_issue_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    check_in_id BIGINT UNSIGNED NOT NULL,
    issue_code VARCHAR(50) NOT NULL,
    detected_at DATETIME(6) NOT NULL,
    resolved_at DATETIME(6) NULL DEFAULT NULL,
    resolution_note VARCHAR(500) NULL DEFAULT NULL,
    CONSTRAINT pk_check_in_quality_issue PRIMARY KEY (check_in_quality_issue_id),
    CONSTRAINT ck_check_in_quality_issue_code CHECK (
        issue_code IN (
            'MISSING_SOURCE_REFERENCE', 'UNMATCHED_MEMBER_REFERENCE',
            'UNMATCHED_VISITED_BRANCH_REFERENCE', 'MISSING_CHECK_IN_TIMESTAMP',
            'DUPLICATE_SOURCE_REFERENCE', 'INACTIVE_MEMBERSHIP'
        )
    ),
    CONSTRAINT ck_check_in_quality_issue_dates CHECK (
        resolved_at IS NULL OR resolved_at >= detected_at
    ),
    CONSTRAINT ck_check_in_quality_issue_resolution_note CHECK (
        resolution_note IS NULL OR CHAR_LENGTH(TRIM(resolution_note)) > 0
    ),
    CONSTRAINT ck_check_in_quality_issue_resolution_evidence CHECK (
        resolved_at IS NULL
        OR (
            resolution_note IS NOT NULL
            AND CHAR_LENGTH(TRIM(resolution_note)) > 0
        )
    )
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

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

CREATE TABLE refund_allocation (
    refund_allocation_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    refund_id BIGINT UNSIGNED NOT NULL,
    payment_allocation_id BIGINT UNSIGNED NOT NULL,
    refund_allocated_amount_usd DECIMAL(12,2) NOT NULL,
    reopens_obligation_flag BOOLEAN NOT NULL,
    recorded_at DATETIME(6) NOT NULL,
    CONSTRAINT pk_refund_allocation PRIMARY KEY (refund_allocation_id),
    CONSTRAINT ck_refund_allocation_amount CHECK (refund_allocated_amount_usd > 0),
    CONSTRAINT ck_refund_allocation_reopens CHECK (reopens_obligation_flag IN (0, 1))
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
-- Gym Membership & Revenue Analytics System
-- PDM-015 schema foundation: 24 unique constraints, 14 indexes, and 27 restrictive foreign keys
-- Prerequisite: run 00_create_schema.sql and 01_create_tables.sql first.

USE gym_membership_analytics_test;

-- Approved unique constraints
ALTER TABLE branch
    ADD CONSTRAINT uk_branch_code UNIQUE (branch_code);

ALTER TABLE membership_plan
    ADD CONSTRAINT uk_membership_plan_code UNIQUE (plan_code);

ALTER TABLE membership_plan_version
    ADD CONSTRAINT uk_membership_plan_version_start UNIQUE (plan_id, available_from_date);

ALTER TABLE member
    ADD CONSTRAINT uk_member_number UNIQUE (member_number);

ALTER TABLE member_branch_assignment
    ADD CONSTRAINT uk_member_branch_assignment_start UNIQUE (member_id, effective_start_date);

ALTER TABLE membership_contract
    ADD CONSTRAINT uk_membership_contract_number UNIQUE (contract_number),
    ADD CONSTRAINT uk_membership_contract_member_start UNIQUE (member_id, service_start_date),
    ADD CONSTRAINT uk_membership_contract_previous UNIQUE (previous_membership_contract_id);

ALTER TABLE membership_status_event
    ADD CONSTRAINT uk_membership_status_event_reversal_target
        UNIQUE (reverses_membership_status_event_id);

ALTER TABLE membership_status_decision_event
    ADD CONSTRAINT uk_membership_status_decision_event_time
        UNIQUE (membership_status_event_id, decision_at);

ALTER TABLE check_in_quality_issue
    ADD CONSTRAINT uk_check_in_quality_issue_occurrence
        UNIQUE (check_in_id, issue_code, detected_at);

ALTER TABLE payment_obligation
    ADD CONSTRAINT uk_payment_obligation_number UNIQUE (obligation_number),
    ADD CONSTRAINT uk_payment_obligation_contract_sequence
        UNIQUE (membership_contract_id, obligation_sequence_number);

ALTER TABLE payment_obligation_adjustment
    ADD CONSTRAINT uk_payment_obligation_adjustment_event
        UNIQUE (payment_obligation_id, membership_status_event_id);

ALTER TABLE payment
    ADD CONSTRAINT uk_payment_number UNIQUE (payment_number);

ALTER TABLE payment_allocation
    ADD CONSTRAINT uk_payment_allocation_payment_obligation
        UNIQUE (payment_id, payment_obligation_id);

ALTER TABLE payment_attempt
    ADD CONSTRAINT uk_payment_attempt_number UNIQUE (attempt_number),
    ADD CONSTRAINT uk_payment_attempt_payment_sequence
        UNIQUE (payment_id, attempt_sequence_number);

ALTER TABLE payment_attempt_status_event
    ADD CONSTRAINT uk_payment_attempt_status_event_time
        UNIQUE (payment_attempt_id, status_at);

ALTER TABLE refund
    ADD CONSTRAINT uk_refund_number UNIQUE (refund_number);

ALTER TABLE refund_status_event
    ADD CONSTRAINT uk_refund_status_event_time UNIQUE (refund_id, status_at);

ALTER TABLE refund_allocation
    ADD CONSTRAINT uk_refund_allocation_refund_payment_allocation
        UNIQUE (refund_id, payment_allocation_id);

ALTER TABLE financial_exception
    ADD CONSTRAINT uk_financial_exception_number UNIQUE (exception_number);

ALTER TABLE financial_exception_status_event
    ADD CONSTRAINT uk_financial_exception_status_event_time
        UNIQUE (financial_exception_id, status_at);

-- Twelve minimum foreign-key indexes
CREATE INDEX ix_member_branch_assignment_home_branch
    ON member_branch_assignment (home_branch_id);

CREATE INDEX ix_membership_contract_plan_version
    ON membership_contract (plan_version_id);

CREATE INDEX ix_membership_contract_financial_ownership_branch
    ON membership_contract (financial_ownership_branch_id);

CREATE INDEX ix_membership_status_event_contract
    ON membership_status_event (membership_contract_id);

CREATE INDEX ix_check_in_member
    ON check_in (member_id);

CREATE INDEX ix_check_in_visited_branch
    ON check_in (visited_branch_id);

CREATE INDEX ix_payment_obligation_adjustment_status_event
    ON payment_obligation_adjustment (membership_status_event_id);

CREATE INDEX ix_payment_contract
    ON payment (membership_contract_id);

CREATE INDEX ix_payment_allocation_obligation
    ON payment_allocation (payment_obligation_id);

CREATE INDEX ix_payment_attempt_processing_branch
    ON payment_attempt (processing_branch_id);

CREATE INDEX ix_refund_payment
    ON refund (payment_id);

CREATE INDEX ix_refund_allocation_payment_allocation
    ON refund_allocation (payment_allocation_id);

-- Two approved workload indexes; both intentionally non-unique
CREATE INDEX ix_check_in_source_reference
    ON check_in (source_check_in_reference);

CREATE INDEX ix_financial_exception_source_type_detected
    ON financial_exception (
        affected_source_domain_code,
        affected_source_record_reference,
        exception_type_code,
        detected_at
    );

-- All relationships use restrictive update and delete behavior.
ALTER TABLE membership_plan_version
    ADD CONSTRAINT fk_membership_plan_version_plan
        FOREIGN KEY (plan_id) REFERENCES membership_plan (plan_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE member_branch_assignment
    ADD CONSTRAINT fk_member_branch_assignment_member
        FOREIGN KEY (member_id) REFERENCES member (member_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD CONSTRAINT fk_member_branch_assignment_home_branch
        FOREIGN KEY (home_branch_id) REFERENCES branch (branch_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE membership_contract
    ADD CONSTRAINT fk_membership_contract_member
        FOREIGN KEY (member_id) REFERENCES member (member_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD CONSTRAINT fk_membership_contract_plan_version
        FOREIGN KEY (plan_version_id) REFERENCES membership_plan_version (plan_version_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD CONSTRAINT fk_membership_contract_financial_ownership_branch
        FOREIGN KEY (financial_ownership_branch_id) REFERENCES branch (branch_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD CONSTRAINT fk_membership_contract_previous
        FOREIGN KEY (previous_membership_contract_id)
        REFERENCES membership_contract (membership_contract_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE membership_status_event
    ADD CONSTRAINT fk_membership_status_event_contract
        FOREIGN KEY (membership_contract_id)
        REFERENCES membership_contract (membership_contract_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD CONSTRAINT fk_membership_status_event_reversal_target
        FOREIGN KEY (reverses_membership_status_event_id)
        REFERENCES membership_status_event (membership_status_event_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE membership_status_decision_event
    ADD CONSTRAINT fk_membership_status_decision_event_status_event
        FOREIGN KEY (membership_status_event_id)
        REFERENCES membership_status_event (membership_status_event_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE check_in
    ADD CONSTRAINT fk_check_in_member
        FOREIGN KEY (member_id) REFERENCES member (member_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD CONSTRAINT fk_check_in_visited_branch
        FOREIGN KEY (visited_branch_id) REFERENCES branch (branch_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE check_in_quality_issue
    ADD CONSTRAINT fk_check_in_quality_issue_check_in
        FOREIGN KEY (check_in_id) REFERENCES check_in (check_in_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE payment_obligation
    ADD CONSTRAINT fk_payment_obligation_contract
        FOREIGN KEY (membership_contract_id)
        REFERENCES membership_contract (membership_contract_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE payment_obligation_adjustment
    ADD CONSTRAINT fk_payment_obligation_adjustment_obligation
        FOREIGN KEY (payment_obligation_id)
        REFERENCES payment_obligation (payment_obligation_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD CONSTRAINT fk_payment_obligation_adjustment_status_event
        FOREIGN KEY (membership_status_event_id)
        REFERENCES membership_status_event (membership_status_event_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE payment
    ADD CONSTRAINT fk_payment_contract
        FOREIGN KEY (membership_contract_id)
        REFERENCES membership_contract (membership_contract_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE payment_allocation
    ADD CONSTRAINT fk_payment_allocation_payment
        FOREIGN KEY (payment_id) REFERENCES payment (payment_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD CONSTRAINT fk_payment_allocation_obligation
        FOREIGN KEY (payment_obligation_id)
        REFERENCES payment_obligation (payment_obligation_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE payment_attempt
    ADD CONSTRAINT fk_payment_attempt_payment
        FOREIGN KEY (payment_id) REFERENCES payment (payment_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD CONSTRAINT fk_payment_attempt_processing_branch
        FOREIGN KEY (processing_branch_id) REFERENCES branch (branch_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE payment_attempt_status_event
    ADD CONSTRAINT fk_payment_attempt_status_event_attempt
        FOREIGN KEY (payment_attempt_id)
        REFERENCES payment_attempt (payment_attempt_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE refund
    ADD CONSTRAINT fk_refund_payment
        FOREIGN KEY (payment_id) REFERENCES payment (payment_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE refund_status_event
    ADD CONSTRAINT fk_refund_status_event_refund
        FOREIGN KEY (refund_id) REFERENCES refund (refund_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE refund_allocation
    ADD CONSTRAINT fk_refund_allocation_refund
        FOREIGN KEY (refund_id) REFERENCES refund (refund_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD CONSTRAINT fk_refund_allocation_payment_allocation
        FOREIGN KEY (payment_allocation_id)
        REFERENCES payment_allocation (payment_allocation_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE financial_exception_status_event
    ADD CONSTRAINT fk_financial_exception_status_event_exception
        FOREIGN KEY (financial_exception_id)
        REFERENCES financial_exception (financial_exception_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT;
-- Gym Membership & Revenue Analytics System
-- PDM-016: 32 approved history-protection triggers across 16 tables
-- Prerequisite: run 00_create_schema.sql through 02_create_keys_indexes.sql first.

USE gym_membership_analytics_test;

DELIMITER $$

CREATE TRIGGER trg_membership_contract_bu_immutable
BEFORE UPDATE ON membership_contract
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-HIS-001: Membership Contract is immutable'$$

CREATE TRIGGER trg_membership_contract_bd_immutable
BEFORE DELETE ON membership_contract
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-HIS-001: Membership Contract is immutable'$$

CREATE TRIGGER trg_membership_status_event_bu_immutable
BEFORE UPDATE ON membership_status_event
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-HIS-002: Membership Status Event is immutable'$$

CREATE TRIGGER trg_membership_status_event_bd_immutable
BEFORE DELETE ON membership_status_event
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-HIS-002: Membership Status Event is immutable'$$

CREATE TRIGGER trg_membership_status_decision_event_bu_immutable
BEFORE UPDATE ON membership_status_decision_event
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-HIS-003: Membership Decision Event is immutable'$$

CREATE TRIGGER trg_membership_status_decision_event_bd_immutable
BEFORE DELETE ON membership_status_decision_event
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-HIS-003: Membership Decision Event is immutable'$$

CREATE TRIGGER trg_check_in_bu_controlled_correction
BEFORE UPDATE ON check_in
FOR EACH ROW
BEGIN
    IF COALESCE(@gym_allow_check_in_correction, 0) <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-HIS-004: Check-In correction is not authorized';
    END IF;

    IF NOT (NEW.check_in_id <=> OLD.check_in_id)
       OR NOT (NEW.recorded_at <=> OLD.recorded_at) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-HIS-004: Check-In identity or receipt time is immutable';
    END IF;
END$$

CREATE TRIGGER trg_check_in_bd_no_delete
BEFORE DELETE ON check_in
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-HIS-004: Check-In correction is not authorized'$$

CREATE TRIGGER trg_check_in_quality_issue_bu_resolution
BEFORE UPDATE ON check_in_quality_issue
FOR EACH ROW
BEGIN
    IF COALESCE(@gym_allow_check_in_issue_resolution, 0) <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-HIS-005: Invalid Check-In issue history change';
    END IF;

    IF NOT (NEW.check_in_quality_issue_id <=> OLD.check_in_quality_issue_id)
       OR NOT (NEW.check_in_id <=> OLD.check_in_id)
       OR NOT (NEW.issue_code <=> OLD.issue_code)
       OR NOT (NEW.detected_at <=> OLD.detected_at)
       OR OLD.resolved_at IS NOT NULL
       OR OLD.resolution_note IS NOT NULL
       OR NEW.resolved_at IS NULL
       OR NEW.resolution_note IS NULL
       OR CHAR_LENGTH(TRIM(NEW.resolution_note)) = 0
       OR NEW.resolved_at < OLD.detected_at THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GYM-HIS-005: Invalid Check-In issue history change';
    END IF;
END$$

CREATE TRIGGER trg_check_in_quality_issue_bd_no_delete
BEFORE DELETE ON check_in_quality_issue
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-HIS-005: Invalid Check-In issue history change'$$

CREATE TRIGGER trg_payment_obligation_bu_immutable
BEFORE UPDATE ON payment_obligation
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-FIN-003: Payment Obligation is immutable'$$

CREATE TRIGGER trg_payment_obligation_bd_immutable
BEFORE DELETE ON payment_obligation
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-FIN-003: Payment Obligation is immutable'$$

CREATE TRIGGER trg_payment_obligation_adjustment_bu_immutable
BEFORE UPDATE ON payment_obligation_adjustment
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-FIN-005: Payment Obligation Adjustment is immutable'$$

CREATE TRIGGER trg_payment_obligation_adjustment_bd_immutable
BEFORE DELETE ON payment_obligation_adjustment
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-FIN-005: Payment Obligation Adjustment is immutable'$$

CREATE TRIGGER trg_payment_bu_immutable
BEFORE UPDATE ON payment
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-FIN-006: Payment is immutable'$$

CREATE TRIGGER trg_payment_bd_immutable
BEFORE DELETE ON payment
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-FIN-006: Payment is immutable'$$

CREATE TRIGGER trg_payment_attempt_bu_immutable
BEFORE UPDATE ON payment_attempt
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-FIN-008: Payment Attempt history is immutable'$$

CREATE TRIGGER trg_payment_attempt_bd_immutable
BEFORE DELETE ON payment_attempt
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-FIN-008: Payment Attempt history is immutable'$$

CREATE TRIGGER trg_payment_attempt_status_event_bu_immutable
BEFORE UPDATE ON payment_attempt_status_event
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-FIN-008: Payment Attempt history is immutable'$$

CREATE TRIGGER trg_payment_attempt_status_event_bd_immutable
BEFORE DELETE ON payment_attempt_status_event
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-FIN-008: Payment Attempt history is immutable'$$

CREATE TRIGGER trg_payment_allocation_bu_immutable
BEFORE UPDATE ON payment_allocation
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-FIN-011: Payment Allocation is immutable'$$

CREATE TRIGGER trg_payment_allocation_bd_immutable
BEFORE DELETE ON payment_allocation
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-FIN-011: Payment Allocation is immutable'$$

CREATE TRIGGER trg_refund_bu_immutable
BEFORE UPDATE ON refund
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-REF-007: Refund history is immutable'$$

CREATE TRIGGER trg_refund_bd_immutable
BEFORE DELETE ON refund
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-REF-007: Refund history is immutable'$$

CREATE TRIGGER trg_refund_status_event_bu_immutable
BEFORE UPDATE ON refund_status_event
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-REF-007: Refund history is immutable'$$

CREATE TRIGGER trg_refund_status_event_bd_immutable
BEFORE DELETE ON refund_status_event
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-REF-007: Refund history is immutable'$$

CREATE TRIGGER trg_refund_allocation_bu_immutable
BEFORE UPDATE ON refund_allocation
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-REF-007: Refund history is immutable'$$

CREATE TRIGGER trg_refund_allocation_bd_immutable
BEFORE DELETE ON refund_allocation
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-REF-007: Refund history is immutable'$$

CREATE TRIGGER trg_financial_exception_bu_immutable
BEFORE UPDATE ON financial_exception
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-DQ-008: Financial Exception history is immutable'$$

CREATE TRIGGER trg_financial_exception_bd_immutable
BEFORE DELETE ON financial_exception
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-DQ-008: Financial Exception history is immutable'$$

CREATE TRIGGER trg_financial_exception_status_event_bu_immutable
BEFORE UPDATE ON financial_exception_status_event
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-DQ-008: Financial Exception history is immutable'$$

CREATE TRIGGER trg_financial_exception_status_event_bd_immutable
BEFORE DELETE ON financial_exception_status_event
FOR EACH ROW
SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GYM-DQ-008: Financial Exception history is immutable'$$

DELIMITER ;
-- Gym Membership & Revenue Analytics System
-- PDM-017: 25 approved validation and curated reporting views
-- Prerequisite: run 00_create_schema.sql through 03_create_triggers.sql first.

USE gym_membership_analytics_test;

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
-- Gym Membership & Revenue Analytics System
-- PDM-018: temporal, membership, cancellation-adjustment, and Check-In procedures
-- Prerequisite: run 00_create_schema.sql through 04_create_views.sql first.

USE gym_membership_analytics_test;

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
-- Gym Membership & Revenue Analytics System
-- PDM-019: Payment request, Attempt workflow, and successful allocation procedures
-- Prerequisite: run 00_create_schema.sql through
-- 05_create_membership_check_in_procedures.sql first.

USE gym_membership_analytics_test;

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
-- Gym Membership & Revenue Analytics System
-- PDM-020: Refund request, terminal transition, and atomic completion procedures
-- Prerequisite: run 00_create_schema.sql through 06_create_payment_procedures.sql first.

USE gym_membership_analytics_test;

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
-- Gym Membership & Revenue Analytics System
-- PDM-021: Financial Exception detection, workflow, resolution, and release procedures
-- Prerequisite: run 00_create_schema.sql through 07_create_refund_procedures.sql first.

USE gym_membership_analytics_test;

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
