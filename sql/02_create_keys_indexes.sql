-- Gym Membership & Revenue Analytics System
-- PDM-015 schema foundation: 24 unique constraints, 14 indexes, and 27 restrictive foreign keys
-- Prerequisite: run 00_create_schema.sql and 01_create_tables.sql first.

USE gym_membership_analytics;

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
