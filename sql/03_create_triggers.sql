-- Gym Membership & Revenue Analytics System
-- PDM-016: 32 approved history-protection triggers across 16 tables
-- Prerequisite: run 00_create_schema.sql through 02_create_keys_indexes.sql first.

USE gym_membership_analytics;

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
