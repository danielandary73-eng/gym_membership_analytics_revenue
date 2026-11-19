-- Gym Membership & Revenue Analytics System
-- PDM-022: least-privilege roles and schema-scoped grants
-- Prerequisite: run 00_create_schema.sql through 08_create_financial_exception_procedures.sql first.
-- This script creates roles only. It contains no user account, password, or default-role assignment.

CREATE ROLE IF NOT EXISTS
    'gym_database_owner'@'%',
    'gym_application_writer'@'%',
    'gym_analyst_powerbi'@'%',
    'gym_audit_reviewer'@'%';

-- Reset these project-owned roles so rerunning the script restores the approved baseline.
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'gym_database_owner'@'%';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'gym_application_writer'@'%';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'gym_analyst_powerbi'@'%';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'gym_audit_reviewer'@'%';

-- Database owner / migration role: schema deployment and controlled administration.
-- GRANT OPTION is intentionally withheld; role assignment remains an external DBA action.
GRANT ALL PRIVILEGES ON gym_membership_analytics.*
    TO 'gym_database_owner'@'%';

-- Application writer: reference reads only, plus public controlled business procedures.
GRANT SELECT ON gym_membership_analytics.branch
    TO 'gym_application_writer'@'%';
GRANT SELECT ON gym_membership_analytics.membership_plan
    TO 'gym_application_writer'@'%';
GRANT SELECT ON gym_membership_analytics.membership_plan_version
    TO 'gym_application_writer'@'%';
GRANT SELECT ON gym_membership_analytics.member
    TO 'gym_application_writer'@'%';
GRANT SELECT ON gym_membership_analytics.member_branch_assignment
    TO 'gym_application_writer'@'%';

GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_create_membership_plan_version
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_assign_member_home_branch
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_create_membership_contract
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_submit_membership_status_event
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_decide_membership_status_event
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_ingest_check_in
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_resolve_check_in_quality_issue
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_create_payment
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_record_payment_attempt
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_transition_payment_attempt
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_allocate_successful_payment
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_request_refund
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_transition_refund
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_complete_refund
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_scan_financial_exceptions
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_open_financial_exception
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_update_financial_exception_workflow
    TO 'gym_application_writer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_resolve_financial_exception
    TO 'gym_application_writer'@'%';

-- The internal cancellation helper is deliberately not granted directly.
-- sp_decide_membership_status_event invokes it inside the approved transaction.

-- Analyst / Power BI role: curated analytical views and the read-only release gate only.
GRANT SELECT ON gym_membership_analytics.vw_reporting_check_in
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_financial_source_disposition
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_financial_exception
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_financial_exception_summary
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_gross_collected_revenue
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_refund
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_obligation_balance
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_net_collected_revenue
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_financial_release_readiness
    TO 'gym_analyst_powerbi'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_assert_financial_release_ready
    TO 'gym_analyst_powerbi'@'%';

-- Audit reviewer: read every approved table and view, but never modify operational data.
GRANT SELECT ON gym_membership_analytics.branch TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.membership_plan TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.member TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.financial_exception TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.membership_plan_version TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.member_branch_assignment TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.check_in TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.financial_exception_status_event TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.membership_contract TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.check_in_quality_issue TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.membership_status_event TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.payment_obligation TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.payment TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.membership_status_decision_event TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.payment_obligation_adjustment TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.payment_attempt TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.payment_allocation TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.refund TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.payment_attempt_status_event TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.refund_status_event TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.refund_allocation TO 'gym_audit_reviewer'@'%';

GRANT SELECT ON gym_membership_analytics.vw_dq_plan_version_overlap TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_home_branch_assignment_overlap TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_membership_decision_integrity TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_membership_status_integrity TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_contract_integrity TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_contract_service_overlap TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_check_in_duplicate_reference TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_check_in_integrity TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_check_in TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_obligation_schedule TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_cancellation_adjustment TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_payment_attempt_integrity TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_payment_reconciliation TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_refund_status_integrity TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_refund_reconciliation TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_financial_source_issue TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_financial_exception_integrity TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_financial_source_disposition TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_financial_exception TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_financial_exception_summary TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_gross_collected_revenue TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_refund TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_obligation_balance TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_reporting_net_collected_revenue TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_dq_financial_release_readiness TO 'gym_audit_reviewer'@'%';
GRANT EXECUTE ON PROCEDURE gym_membership_analytics.sp_assert_financial_release_ready
    TO 'gym_audit_reviewer'@'%';
