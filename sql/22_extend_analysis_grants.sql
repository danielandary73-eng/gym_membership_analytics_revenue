-- Gym Membership & Revenue Analytics System
-- SQLA-003: least-privilege extension for the controlled analytical layer
-- Prerequisite: run 09_create_roles_grants.sql, 21_create_analysis_views.sql,
-- 23_build_analysis_mart.sql, and 24_build_obligation_activity_mart.sql first.

-- Analyst / Power BI: the ten approved analytical views only.
GRANT SELECT ON gym_membership_analytics.vw_analysis_date
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_branch
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_membership_plan_version
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_home_branch_assignment
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_membership_status_event
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_membership_contract
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_membership_daily_snapshot
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_payment_attempt_final
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_obligation_activity
    TO 'gym_analyst_powerbi'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_refund
    TO 'gym_analyst_powerbi'@'%';

-- Audit reviewer: preserve complete read-only coverage of every approved object.
GRANT SELECT ON gym_membership_analytics.vw_analysis_date
    TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_branch
    TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_membership_plan_version
    TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_home_branch_assignment
    TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_membership_status_event
    TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_membership_contract
    TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_membership_daily_snapshot
    TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_payment_attempt_final
    TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_obligation_activity
    TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.vw_analysis_refund
    TO 'gym_audit_reviewer'@'%';

-- Audit reviewer also sees the three physical mart tables. The analyst remains
-- restricted to the stable public views and receives no base-table privilege.
GRANT SELECT ON gym_membership_analytics.mart_analysis_membership_contract
    TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.mart_analysis_membership_daily_snapshot
    TO 'gym_audit_reviewer'@'%';
GRANT SELECT ON gym_membership_analytics.mart_analysis_obligation_activity
    TO 'gym_audit_reviewer'@'%';
