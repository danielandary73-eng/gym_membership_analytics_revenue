-- Gym Membership & Revenue Analytics System
-- PDM-015 schema foundation: 21 tables, 131 fields, row-local checks, and primary keys
-- Prerequisite: run 00_create_schema.sql first against a fresh or empty schema.
-- The pk_* constraint symbols preserve design traceability in source; MySQL exposes
-- each primary key under its required runtime name PRIMARY.

USE gym_membership_analytics;

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
